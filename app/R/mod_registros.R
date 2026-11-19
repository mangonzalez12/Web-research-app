library(shiny)
library(pool)
library(DBI)

# Questionnaire tables shown as columns, in tab order
registros_tables <- c(
  IPAQ  = "questionnaire_ipaq",
  POSIT = "questionnaire_posit",
  PSQI  = "questionnaire_psqi",
  AMAI  = "questionnaire_amai",
  PSS   = "questionnaire_pss",
  PNC   = "questionnaire_pnc"
)

# Times are shown in Mexico City time (the server runs in UTC)
registros_tz <- "America/Mexico_City"

# Same password check as Descargas: unlocks this tab for a while, then locks again
REGISTROS_MINUTES <- 15
REGISTROS_MAX_ATTEMPTS <- 5

# ---- UI ----------------------------------------------------------------

mod_registros_ui <- function(id) {
  ns <- NS(id)

  tagList(
    h3("Registros guardados"),
    p(class = "text-muted",
      "Una fila por participante, del más reciente al más antiguo. Cada cuestionario muestra ",
      "la fecha y hora en que se guardó; — significa que todavía no se ha guardado."),
    uiOutput(ns("contenido"))
  )
}

# ---- Server --------------------------------------------------------------

# check_password(user, password) -> TRUE/FALSE
mod_registros_server <- function(id, pool, user, check_password) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    unlocked_until <- reactiveVal(NULL)
    failed <- reactiveVal(0)
    blocked_until <- reactiveVal(NULL)

    is_unlocked <- function() {
      u <- unlocked_until()
      !is.null(u) && Sys.time() < u
    }

    # Lock again automatically when the time is up
    observe({
      u <- unlocked_until()
      req(u)
      if (Sys.time() >= u) unlocked_until(NULL)
      else invalidateLater(as.numeric(difftime(u, Sys.time(), units = "secs")) * 1000 + 500)
    })

    observeEvent(input$confirmar, {
      b <- blocked_until()
      if (!is.null(b) && Sys.time() < b) {
        showNotification(sprintf("Demasiados intentos. Intenta de nuevo a las %s.",
                                 format(b, "%H:%M", tz = registros_tz)), type = "error")
        return()
      }
      ok <- isTRUE(check_password(user(), input$password))
      updateTextInput(session, "password", value = "")
      if (ok) {
        failed(0)
        unlocked_until(Sys.time() + REGISTROS_MINUTES * 60)
        message(sprintf("[registros] %s desbloqueó registros", user()))
      } else {
        failed(failed() + 1)
        message(sprintf("[registros] %s: contraseña incorrecta (%d)", user(), failed()))
        if (failed() >= REGISTROS_MAX_ATTEMPTS) {
          failed(0)
          blocked_until(Sys.time() + 5 * 60)
          showNotification("Demasiados intentos. Espera 5 minutos.", type = "error")
        } else {
          showNotification("Contraseña incorrecta.", type = "error")
        }
      }
    })

    observeEvent(input$bloquear, unlocked_until(NULL))

    output$contenido <- renderUI({
      if (!is_unlocked()) {
        return(wellPanel(
          style = "max-width: 400px;",
          p("Por seguridad, confirma tu contraseña para ver los registros."),
          passwordInput(ns("password"), sprintf("Contraseña de %s", user())),
          actionButton(ns("confirmar"), "Confirmar", class = "btn-primary", icon = icon("lock-open"))
        ))
      }
      tagList(
        div(class = "alert alert-success",
            sprintf("Registros habilitados hasta las %s. ",
                    format(unlocked_until(), "%H:%M", tz = registros_tz)),
            actionLink(ns("bloquear"), "Bloquear ahora")),
        fluidRow(
          column(3, numericInput(ns("limit"), "Participantes a mostrar", value = 50, min = 1, max = 1000)),
          column(3, br(), actionButton(ns("refresh"), "Actualizar", icon = icon("rotate")))
        ),
        textOutput(ns("updated_at")),
        div(style = "overflow-x: auto;", tableOutput(ns("table")))
      )
    })

    data <- eventReactive(list(input$refresh, input$limit, unlocked_until()), {
      req(is_unlocked())
      fmt <- function(expr) sprintf(
        "to_char((%s) AT TIME ZONE '%s', 'DD/MM/YYYY HH24:MI')", expr, registros_tz)

      q_cols <- vapply(names(registros_tables), function(lbl) {
        sprintf("%s AS \"%s\"",
                fmt(sprintf("(SELECT max(submitted_at) FROM %s q WHERE q.subject_id = p.subject_id)",
                            registros_tables[[lbl]])),
                lbl)
      }, character(1))

      # CFCA is saved either all at once (team) or one category at a time (participant link)
      cfca_col <- sprintf("
        CASE
          WHEN cp.n > 0 THEN cp.n || '/' || (SELECT count(DISTINCT category) FROM food_items) || ' categorías'
          ELSE %s
        END AS \"CFCA\"",
        fmt("(SELECT max(submitted_at) FROM cfca_responses r WHERE r.subject_id = p.subject_id)"))

      sql <- sprintf("
        SELECT %s AS \"Registro\",
               i.name AS \"Nombre\",
               p.collected_by AS \"Registró\",
               left(p.subject_id::text, 8) AS \"ID\",
               %s,
               %s
        FROM participants p
        LEFT JOIN participant_identity i ON i.subject_id = p.subject_id
        LEFT JOIN LATERAL (
          SELECT count(*) AS n FROM cfca_category_progress c WHERE c.subject_id = p.subject_id
        ) cp ON TRUE
        ORDER BY p.created_at DESC NULLS LAST
        LIMIT $1",
        fmt("p.created_at"),
        paste(q_cols[1:5], collapse = ",\n               "),
        paste(c(cfca_col, q_cols[6]), collapse = ",\n               "))

      limit <- if (is.null(input$limit) || is.na(input$limit)) 50L else as.integer(input$limit)
      tryCatch(
        dbGetQuery(pool, sql, params = list(limit)),
        error = function(e) {
          showNotification(paste("Error al leer los registros:", e$message), type = "error")
          NULL
        }
      )
    })

    output$updated_at <- renderText({
      req(is_unlocked())
      data()
      paste("Actualizado:", format(Sys.time(), "%d/%m/%Y %H:%M", tz = registros_tz))
    })

    output$table <- renderTable({
      req(is_unlocked())
      df <- data()
      req(df)
      if (nrow(df) == 0) return(data.frame(Mensaje = "Todavía no hay participantes registrados."))
      df[is.na(df)] <- "—"
      df
    }, striped = TRUE, hover = TRUE, bordered = TRUE, spacing = "s", na = "—")
  })
}
