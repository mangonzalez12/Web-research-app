library(shiny)
library(pool)
library(DBI)

amai_education_choices <- c(
  "No estudios"              = "0",
  "Primaria incompleta"      = "1",
  "Primaria completa"        = "2",
  "Secundaria incompleta"    = "3",
  "Secundaria completa"      = "4",
  "Carrera comercial"        = "5",
  "Carrera técnica"          = "6",
  "Preparatoria incompleta"  = "7",
  "Preparatoria completa"    = "8",
  "Licenciatura incompleta"  = "9",
  "Licenciatura completa"    = "10",
  "Diplomado o maestría"     = "11",
  "Doctorado"                = "12"
)

amai_0_1_2plus <- c("0" = "0", "1" = "1", "2 ó más" = "2")
amai_0_to_4plus <- c("0" = "0", "1" = "1", "2" = "2", "3" = "3", "4 ó más" = "4")

# ---- UI ----------------------------------------------------------------

mod_questionnaire_amai_ui <- function(id) {
  ns <- NS(id)

  tagList(
    questionnaire_header(
      "Regla AMAI 2022",
      "Cuestionario para la aplicación de la Regla AMAI 2022",
      "Instrucciones: Contesta las preguntas de acuerdo con las características actuales de tu hogar y de las personas que viven contigo.",
      "Si no conoces algún dato, puedes pedir ayuda a tu madre, padre o tutor."
    ),

    radioButtons(ns("household_head_education"),
                 "1. Último año de estudios que aprobó el jefe o jefa de hogar",
                 choices = amai_education_choices, selected = character(0)),

    radioButtons(ns("bathrooms"),
                 "2. Baños completos con regadera y W.C. en la vivienda",
                 choices = amai_0_1_2plus, selected = character(0)),

    radioButtons(ns("cars"),
                 "3. Automóviles o camionetas en el hogar",
                 choices = amai_0_1_2plus, selected = character(0)),

    radioButtons(ns("has_internet"),
                 "4. ¿Este hogar cuenta con internet? (sin contar conexión móvil)",
                 choices = c("No tiene" = "false", "Sí tiene" = "true"), selected = character(0)),

    radioButtons(ns("workers_14plus"),
                 "5. Personas de 14 años o más que trabajaron en el último mes",
                 choices = amai_0_to_4plus, selected = character(0)),

    radioButtons(ns("bedrooms"),
                 "6. Cuartos usados para dormir, sin contar pasillos ni baños",
                 choices = amai_0_to_4plus, selected = character(0)),

    actionButton(ns("submit"), "Guardar respuestas", class = "btn-primary")
  )
}

# ---- Server --------------------------------------------------------------

mod_questionnaire_amai_server <- function(id, pool, subject_id, collected_by) {
  moduleServer(id, function(input, output, session) {

    observeEvent(input$submit, {
      if (is.null(subject_id())) {
        showNotification("Primero registra un participante (pestaña Registro).", type = "error")
        return()
      }

      to_int <- function(x) if (is.null(x)) NA_integer_ else as.integer(x)
      to_bool <- function(x) if (is.null(x)) NA else as.logical(x)

      vals <- list(
        subject_id                = subject_id(),
        household_head_education  = to_int(input$household_head_education),
        bathrooms                  = to_int(input$bathrooms),
        cars                       = to_int(input$cars),
        has_internet               = to_bool(input$has_internet),
        workers_14plus             = to_int(input$workers_14plus),
        bedrooms                   = to_int(input$bedrooms)
      )

      vals$collected_by <- collected_by()
      col_list <- paste(names(vals), collapse = ", ")
      placeholders <- paste0("$", seq_along(vals), collapse = ", ")

      tryCatch({
        dbExecute(
          pool,
          sprintf("INSERT INTO questionnaire_amai (%s) VALUES (%s)", col_list, placeholders),
          params = unname(vals)
        )
        showNotification("Respuestas guardadas correctamente.", type = "message")
      }, error = function(e) {
        showNotification(paste("Error al guardar:", e$message), type = "error")
      })
    })
  })
}
