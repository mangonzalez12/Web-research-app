library(shiny)
library(shinyjs)
library(pool)
library(DBI)

# ---- UI ----------------------------------------------------------------

mod_questionnaire_ipaq_ui <- function(id) {
  ns <- NS(id)

  tagList(
    useShinyjs(),
    questionnaire_header(
      "IPAQ - Cuestionario Internacional de Actividad Física",
      "IPAQ: formato corto autoadministrado de los últimos 7 días, para uso con jóvenes y adultos de mediana edad (15-69 años)",
      tagList("Las preguntas se referirán al tiempo que usted destinó a estar físicamente activo en los ",
              strong("últimos 7 días"), "."),
      "Por favor responda a cada pregunta aún si no se considera una persona activa.",
      "Por favor, piense acerca de las actividades que realiza en su trabajo, como parte de sus tareas en el hogar o en el jardín, moviéndose de un lugar a otro, en su tiempo libre para la recreación, el ejercicio o el deporte.",
      tagList("Piense en todas las actividades ", strong("intensas"), " que usted realizó en los ",
              strong("últimos 7 días"), "."),
      tagList("Las actividades físicas ", strong("intensas"),
              " se refieren a aquellas que implican un esfuerzo físico intenso y que lo hacen respirar mucho más intensamente que lo normal."),
      tagList("Piense solo en aquellas actividades físicas que realizó durante por lo menos ",
              strong("10 minutos seguidos"), ".")
    ),

    # Vigorous ----
    h4("Actividad física intensa"),
    numericInput(ns("vigorous_days"), "¿Días por semana?", value = NA, min = 0, max = 7),
    checkboxInput(ns("vigorous_none"), "Ninguna actividad física intensa"),
    div(id = ns("vigorous_time_block"),
        numericInput(ns("vigorous_hours"), "Horas por día", value = NA, min = 0, max = 23),
        numericInput(ns("vigorous_minutes"), "Minutos por día", value = NA, min = 0, max = 59),
        checkboxInput(ns("vigorous_dont_know"), "No sabe/No está seguro")
    ),

    # Moderate ----
    h4("Actividad física moderada"),
    numericInput(ns("moderate_days"), "¿Días por semana?", value = NA, min = 0, max = 7),
    checkboxInput(ns("moderate_none"), "Ninguna actividad física moderada"),
    div(id = ns("moderate_time_block"),
        numericInput(ns("moderate_hours"), "Horas por día", value = NA, min = 0, max = 23),
        numericInput(ns("moderate_minutes"), "Minutos por día", value = NA, min = 0, max = 59),
        checkboxInput(ns("moderate_dont_know"), "No sabe/No está seguro")
    ),

    # Walking ----
    h4("Caminata"),
    numericInput(ns("walking_days"), "¿Días por semana?", value = NA, min = 0, max = 7),
    checkboxInput(ns("walking_none"), "Ninguna caminata"),
    div(id = ns("walking_time_block"),
        numericInput(ns("walking_hours"), "Horas por día", value = NA, min = 0, max = 23),
        numericInput(ns("walking_minutes"), "Minutos por día", value = NA, min = 0, max = 59),
        checkboxInput(ns("walking_dont_know"), "No sabe/No está seguro")
    ),

    # Sitting ----
    h4("Tiempo sentado"),
    numericInput(ns("sitting_hours"), "Horas por día", value = NA, min = 0, max = 23),
    numericInput(ns("sitting_minutes"), "Minutos por día", value = NA, min = 0, max = 59),
    checkboxInput(ns("sitting_dont_know"), "No sabe/No está seguro"),

    actionButton(ns("submit"), "Guardar respuestas", class = "btn-primary"),
    div(id = ns("submit_msg"))
  )
}

# ---- Server --------------------------------------------------------------

# subject_id: reactive holding the current participant's UUID
mod_questionnaire_ipaq_server <- function(id, pool, subject_id, collected_by) {
  moduleServer(id, function(input, output, session) {

    # Skip logic: hide time block + force days = 0 when "none" is checked
    observe({
      toggle(id = "vigorous_time_block", condition = !isTRUE(input$vigorous_none))
      toggle(id = "moderate_time_block", condition = !isTRUE(input$moderate_none))
      toggle(id = "walking_time_block", condition = !isTRUE(input$walking_none))
    })

    observeEvent(input$submit, {
      if (is.null(subject_id())) {
        showNotification("Primero registra un participante (pestaña Registro).", type = "error")
        return()
      }

      vals <- list(
        subject_id          = subject_id(),
        vigorous_days       = if (isTRUE(input$vigorous_none)) 0L else input$vigorous_days,
        vigorous_hours      = if (isTRUE(input$vigorous_none)) NA else input$vigorous_hours,
        vigorous_minutes    = if (isTRUE(input$vigorous_none)) NA else input$vigorous_minutes,
        vigorous_dont_know  = isTRUE(input$vigorous_dont_know),

        moderate_days       = if (isTRUE(input$moderate_none)) 0L else input$moderate_days,
        moderate_hours      = if (isTRUE(input$moderate_none)) NA else input$moderate_hours,
        moderate_minutes    = if (isTRUE(input$moderate_none)) NA else input$moderate_minutes,
        moderate_dont_know  = isTRUE(input$moderate_dont_know),

        walking_days        = if (isTRUE(input$walking_none)) 0L else input$walking_days,
        walking_hours       = if (isTRUE(input$walking_none)) NA else input$walking_hours,
        walking_minutes     = if (isTRUE(input$walking_none)) NA else input$walking_minutes,
        walking_dont_know   = isTRUE(input$walking_dont_know),

        sitting_hours       = input$sitting_hours,
        sitting_minutes     = input$sitting_minutes,
        sitting_dont_know   = isTRUE(input$sitting_dont_know),
        collected_by        = collected_by()
      )

      tryCatch({
        dbExecute(pool, "
          INSERT INTO questionnaire_ipaq (
            subject_id,
            vigorous_days, vigorous_hours, vigorous_minutes, vigorous_dont_know,
            moderate_days, moderate_hours, moderate_minutes, moderate_dont_know,
            walking_days, walking_hours, walking_minutes, walking_dont_know,
            sitting_hours, sitting_minutes, sitting_dont_know,
            collected_by
          ) VALUES (
            $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17
          )",
          params = unname(vals)
        )
        showNotification("Respuestas guardadas correctamente.", type = "message")
      }, error = function(e) {
        showNotification(paste("Error al guardar:", e$message), type = "error")
      })
    })
  })
}
