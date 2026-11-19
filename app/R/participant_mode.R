library(shiny)
library(shinyjs)
library(pool)
library(DBI)

# Every questionnaire as the participant sees it: how to draw it and how to run it.
# (Built when needed, so the module functions only have to exist by then.)
questionnaire_registry <- function() {
  list(
    ipaq  = list(ui = mod_questionnaire_ipaq_ui,  server = mod_questionnaire_ipaq_server),
    posit = list(ui = mod_questionnaire_posit_ui, server = mod_questionnaire_posit_server),
    psqi  = list(ui = mod_questionnaire_psqi_ui,  server = mod_questionnaire_psqi_server),
    amai  = list(ui = mod_questionnaire_amai_ui,  server = mod_questionnaire_amai_server),
    pss   = list(ui = mod_questionnaire_pss_ui,   server = mod_questionnaire_pss_server),
    cfca  = list(
      ui = function(id) mod_questionnaire_cfca_ui(id, per_category = TRUE),
      server = function(id, pool, subject_id, collected_by) {
        mod_questionnaire_cfca_server(id, pool, subject_id, collected_by, per_category = TRUE)
      }
    ),
    pnc   = list(ui = mod_questionnaire_pnc_ui,   server = mod_questionnaire_pnc_server)
  )
}

# The page a participant gets from their personal link (no login)
participant_ui <- function() {
  fluidPage(
    useShinyjs(),
    tags$head(
      tags$meta(name = "referrer", content = "no-referrer"),
      tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
      tags$title("Cuestionarios")
    ),
    titlePanel("Cuestionarios"),
    uiOutput("p_main"),
    uiOutput("p_finished")
  )
}

# Server logic for a participant session. The subject comes ONLY from the link's token.
participant_server <- function(token, pool, input, output, session) {

  registry <- questionnaire_registry()

  link <- reactiveVal(NULL)               # NULL = unknown / expired / revoked
  link_state <- reactiveVal("checking")   # "checking" | "ok" | "invalid" | "error"

  check_link <- function() {
    res <- tryCatch(validate_link(pool, token), error = function(e) {
      message("[participant link] could not check the link: ", conditionMessage(e))
      "error"
    })
    if (identical(res, "error")) {
      if (is.null(link())) link_state("error")   # a hiccup never kicks out someone already inside
    } else if (is.null(res)) {
      link(NULL)
      link_state("invalid")
    } else {
      link(res)
      link_state("ok")
    }
  }

  # check now, and again every minute (expiry or revocation while the page is open)
  observe({
    invalidateLater(60000, session)
    check_link()
  })

  # which questionnaires are finished; polled so a saved form locks itself
  done <- reactiveValues(ready = FALSE)
  status <- reactive({
    l <- link()
    req(l)
    invalidateLater(2000, session)
    tryCatch(questionnaire_status(pool, l$subject_id), error = function(e) {
      message("[participant link] could not read progress: ", conditionMessage(e))
      NULL
    })
  })
  observe({
    st <- status()
    # (not req(st): a vector of all FALSE -- nothing finished yet -- counts as "not ready" for req())
    if (is.null(st)) return()
    for (code in names(st)) done[[code]] <- isTRUE(st[[code]])
    done$ready <- TRUE
  })

  participant_subject <- reactive({ l <- link(); req(l); l$subject_id })
  participant_by      <- reactive({ l <- link(); req(l); paste0("enlace:", l$created_by) })

  for (code in names(registry)) {
    registry[[code]]$server(paste0("p_", code), pool,
                            subject_id = participant_subject, collected_by = participant_by)
  }

  lapply(names(registry), function(code) {
    output[[paste0("p_form_", code)]] <- renderUI({
      req(done$ready)
      if (isTRUE(done[[code]])) {
        div(class = "alert alert-success", "Completado. Gracias.")
      } else {
        registry[[code]]$ui(paste0("p_", code))
      }
    })
  })

  output$p_main <- renderUI({
    state <- link_state()
    if (state == "checking") return(p("Cargando..."))
    if (state == "error") {
      return(div(class = "alert alert-warning",
                 "No pudimos verificar tu enlace. Intenta de nuevo en unos minutos."))
    }
    l <- link()
    if (is.null(l)) {
      return(div(class = "alert alert-warning",
                 h4("Este enlace no es válido o ya venció"),
                 p("Pide un enlace nuevo a la persona que te atendió.")))
    }
    tagList(
      p("Responde cada cuestionario y presiona Guardar al terminar. ",
        "Después de guardar ya no podrás cambiar esas respuestas."),
      strong(textOutput("p_progress", inline = TRUE)),
      br(), br(),
      do.call(tabsetPanel, c(
        list(id = "p_tabs"),
        lapply(l$codes, function(code) {
          tabPanel(names(LINK_QUESTIONNAIRES)[LINK_QUESTIONNAIRES == code],
                   uiOutput(paste0("p_form_", code)))
        })
      ))
    )
  })

  output$p_progress <- renderText({
    l <- link()
    req(l, done$ready)
    n <- sum(vapply(l$codes, function(code) isTRUE(done[[code]]), logical(1)))
    sprintf("Completados: %d de %d", n, length(l$codes))
  })

  output$p_finished <- renderUI({
    l <- link()
    req(l, done$ready)
    if (all(vapply(l$codes, function(code) isTRUE(done[[code]]), logical(1)))) {
      div(class = "alert alert-success",
          h4("Gracias, terminaste todos los cuestionarios."),
          p("Ya puedes cerrar esta página."))
    }
  })

  invisible(list(link = link, done = done))
}
