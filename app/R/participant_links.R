library(shiny)
library(pool)
library(DBI)

# ---- Shared helpers -------------------------------------------------------

# Questionnaires a participant link can include: label shown -> code
LINK_QUESTIONNAIRES <- c(IPAQ = "ipaq", POSIT = "posit", PSQI = "psqi", AMAI = "amai",
                         PSS = "pss", CFCA = "cfca", PNC = "pnc")

# One-row-per-participant tables (CFCA is tracked by food category instead)
QUESTIONNAIRE_TABLE <- c(ipaq = "questionnaire_ipaq", posit = "questionnaire_posit",
                         psqi = "questionnaire_psqi", amai = "questionnaire_amai",
                         pss = "questionnaire_pss", pnc = "questionnaire_pnc")

# A random token (192 bits). Only its SHA-256 hash is stored in the database.
new_token <- function() paste(as.character(openssl::rand_bytes(24)), collapse = "")
hash_token <- function(token) as.character(openssl::sha256(token))

# Which questionnaires are finished for one participant: named logical vector by code.
# CFCA counts as finished when every food category has been saved.
questionnaire_status <- function(pool, subject_id) {
  sql <- paste(
    sprintf("SELECT '%s' AS code, EXISTS (SELECT 1 FROM %s WHERE subject_id = $1) AS done",
            names(QUESTIONNAIRE_TABLE), QUESTIONNAIRE_TABLE),
    collapse = " UNION ALL ")
  sql <- paste(sql, "UNION ALL SELECT 'cfca',",
               "(SELECT count(*) FROM cfca_category_progress WHERE subject_id = $1) >=",
               "GREATEST((SELECT count(DISTINCT category) FROM food_items), 1)")
  res <- dbGetQuery(pool, sql, params = list(subject_id))
  stats::setNames(as.logical(res$done), res$code)
}

# Looks a token up. Returns NULL if it is unknown, expired or revoked.
validate_link <- function(pool, token) {
  res <- dbGetQuery(pool, "
    SELECT subject_id::text AS subject_id, questionnaires, created_by
    FROM participant_links
    WHERE token_hash = $1 AND revoked_at IS NULL AND expires_at > now()",
    params = list(hash_token(token)))
  if (nrow(res) == 0) return(NULL)
  codes <- strsplit(res$questionnaires[1], ",", fixed = TRUE)[[1]]
  codes <- intersect(codes, unname(LINK_QUESTIONNAIRES))
  list(subject_id = res$subject_id[1], codes = codes, created_by = res$created_by[1])
}

# ---- Team side: create / revoke the link of the current participant --------

mod_participant_links_ui <- function(id) {
  ns <- NS(id)

  tagList(
    h4("Enlace para que el participante responda en su teléfono"),
    p(class = "text-muted",
      "Registra al participante o búscalo por nombre (arriba). Puedes generar un enlace nuevo cuando quieras, ",
      "por ejemplo con los cuestionarios que le faltan. El enlace funciona solo para ese participante, ",
      "sin usuario ni contraseña, y deja de servir cuando vence o termina todo."),
    uiOutput(ns("activo")),
    checkboxGroupInput(ns("qs"), "Cuestionarios del enlace", choices = LINK_QUESTIONNAIRES,
                       selected = LINK_QUESTIONNAIRES, inline = TRUE),
    selectInput(ns("hours"), "El enlace vence en",
                choices = c("4 horas" = 4, "24 horas" = 24, "3 días" = 72, "7 días" = 168),
                selected = 24),
    actionButton(ns("generar"), "Generar enlace", class = "btn-primary"),
    actionButton(ns("revocar"), "Revocar enlaces de este participante"),
    br(), br(),
    uiOutput(ns("resultado")),
    tableOutput(ns("estado"))
  )
}

mod_participant_links_server <- function(id, pool, subject_id, collected_by) {
  moduleServer(id, function(input, output, session) {

    last_url <- reactiveVal(NULL)

    # A new participant never inherits the previous participant's link on screen
    observeEvent(subject_id(), last_url(NULL), ignoreNULL = FALSE)

    # Says who the link is for
    output$activo <- renderUI({
      sid <- subject_id()
      if (is.null(sid)) {
        return(div(class = "alert alert-warning",
                   "Ningún participante seleccionado. Regístralo o búscalo por nombre."))
      }
      nm <- tryCatch(
        dbGetQuery(pool, "SELECT name FROM participant_identity WHERE subject_id = $1",
                   params = list(sid))$name,
        error = function(e) character(0))
      div(class = "alert alert-success",
          "Enlace para: ", strong(if (length(nm) > 0) nm[1] else sid))
    })

    # Pre-select only the questionnaires this participant has not finished yet
    observeEvent(subject_id(), {
      sid <- subject_id()
      if (is.null(sid)) return()
      st <- tryCatch(questionnaire_status(pool, sid), error = function(e) NULL)
      if (is.null(st)) return()
      codes <- unname(LINK_QUESTIONNAIRES)
      updateCheckboxGroupInput(session, "qs", selected = codes[!st[codes]])
    }, ignoreNULL = FALSE)

    base_url <- function() {
      fixed <- Sys.getenv("PUBLIC_URL", "")
      if (nzchar(fixed)) return(sub("/?$", "/", fixed))
      cd <- session$clientData
      port <- isolate(cd$url_port)
      paste0(isolate(cd$url_protocol), "//", isolate(cd$url_hostname),
             if (!is.null(port) && nzchar(port)) paste0(":", port) else "",
             isolate(cd$url_pathname))
    }

    observeEvent(input$generar, {
      if (is.null(subject_id())) {
        showNotification("Primero registra al participante.", type = "error")
        return()
      }
      if (length(input$qs) == 0) {
        showNotification("Elige al menos un cuestionario.", type = "error")
        return()
      }

      token <- new_token()
      conn <- poolCheckout(pool)
      on.exit(poolReturn(conn))

      ok <- tryCatch({
        dbBegin(conn)
        # one active link per participant: a new link replaces the old one
        dbExecute(conn, "
          UPDATE participant_links SET revoked_at = now()
          WHERE subject_id = $1 AND revoked_at IS NULL",
          params = list(subject_id()))
        dbExecute(conn, "
          INSERT INTO participant_links (subject_id, token_hash, questionnaires, created_by, expires_at)
          VALUES ($1, $2, $3, $4, now() + make_interval(hours => $5::int))",
          params = list(subject_id(), hash_token(token), paste(input$qs, collapse = ","),
                        collected_by(), as.integer(input$hours)))
        dbCommit(conn)
        TRUE
      }, error = function(e) {
        try(dbRollback(conn), silent = TRUE)
        showNotification(paste("Error al generar el enlace:", e$message), type = "error")
        FALSE
      })

      if (ok) {
        last_url(paste0(base_url(), "?t=", token))
        showNotification("Enlace generado. Solo se muestra ahora.", type = "message")
      }
    })

    observeEvent(input$revocar, {
      if (is.null(subject_id())) return()
      tryCatch({
        dbExecute(pool, "
          UPDATE participant_links SET revoked_at = now()
          WHERE subject_id = $1 AND revoked_at IS NULL",
          params = list(subject_id()))
        last_url(NULL)
        showNotification("Enlaces revocados.", type = "message")
      }, error = function(e) {
        showNotification(paste("Error al revocar:", e$message), type = "error")
      })
    })

    output$resultado <- renderUI({
      url <- last_url()
      if (is.null(url)) return(NULL)
      tagList(
        div(class = "alert alert-info",
            strong("Enlace (solo se muestra ahora):"), br(),
            tags$code(style = "user-select: all; word-break: break-all;", url)),
        plotOutput(session$ns("qr"), height = "260px", width = "260px")
      )
    })

    output$qr <- renderPlot({
      req(last_url())
      graphics::par(mar = c(0, 0, 0, 0))
      plot(qrcode::qr_code(last_url()))
    })

    output$estado <- renderTable({
      req(subject_id())
      invalidateLater(5000)
      st <- questionnaire_status(pool, subject_id())
      data.frame(Cuestionario = names(LINK_QUESTIONNAIRES),
                 Estado = ifelse(st[unname(LINK_QUESTIONNAIRES)], "Completado", "Pendiente"))
    }, striped = TRUE)
  })
}
