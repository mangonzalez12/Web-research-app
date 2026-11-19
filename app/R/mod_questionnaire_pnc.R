library(shiny)
library(pool)
library(DBI)

# PNC QUESTIONNAIRE
pnc_items <- c(
  question1  = "¿Conoce a las personas de su vecindario?",
  question2  = "En los últimos 12 meses, ¿se ha detenido a hablar con personas de su vecindario?",
  question3  = "¿Las personas de su vecindario se apoyan entre sí?",
  question4  = "¿Se siente seguro(a) en su vecindario?",
  question5  = "¿Está satisfecho(a) viviendo en su vecindario?"
)

pnc_si_no <- c("Sí" = "true", "No" = "false")

# ---- UI ----------------------------------------------------------------

mod_questionnaire_pnc_ui <- function(id) {
  ns <- NS(id)

  tagList(
    questionnaire_header(
      "Cuestionario de satisfacción percibida del vecindario (PNC)",
      "Escala de satisfacción percibida del vecindario (PNC)",
      "A continuación encontrará una serie de preguntas relacionadas con su experiencia en su vecindario.",
      tagList("Por favor, responda marcando la opción ", strong("“SÍ” o “NO”"),
              " que mejor refleje su situación."),
      "Responda todas las preguntas."
    ),
    lapply(names(pnc_items), function(q) {
      radioButtons(ns(q), pnc_items[[q]], choices = pnc_si_no,
                   selected = character(0), inline = TRUE)
    }),
    actionButton(ns("submit"), "Guardar respuestas", class = "btn-primary")
  )
}

# ---- Server --------------------------------------------------------------

mod_questionnaire_pnc_server <- function(id, pool, subject_id, collected_by) {
  moduleServer(id, function(input, output, session) {

    observeEvent(input$submit, {
      if (is.null(subject_id())) {
        showNotification("Primero registra un participante (pestaña Registro).", type = "error")
        return()
      }

      q_names <- names(pnc_items)
      to_bool <- function(x) if (is.null(x)) NA else as.logical(x)
      vals <- c(list(subject_id()), lapply(q_names, function(q) to_bool(input[[q]])))

      vals <- c(vals, list(collected_by()))
      col_list <- paste(c("subject_id", q_names, "collected_by"), collapse = ", ")
      placeholders <- paste0("$", seq_along(vals), collapse = ", ")

      tryCatch({
        dbExecute(
          pool,
          sprintf("INSERT INTO questionnaire_pnc (%s) VALUES (%s)", col_list, placeholders),
          params = unname(vals)
        )
        showNotification("Respuestas guardadas correctamente.", type = "message")
      }, error = function(e) {
        showNotification(paste("Error al guardar:", e$message), type = "error")
      })
    })
  })
}
