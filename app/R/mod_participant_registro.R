library(shiny)
library(shinyjs)
library(pool)
library(DBI)

# ---- UI ----------------------------------------------------------------

mod_participant_registro_ui <- function(id) {
  ns <- NS(id)

  tagList(
    useShinyjs(),
    h3("Registro de participante"),
    uiOutput(ns("fields")),
    actionButton(ns("registrar"), "Registrar participante", class = "btn-primary"),
    actionButton(ns("nuevo"), "Nuevo participante"),
    br(), br(),
    verbatimTextOutput(ns("current_subject"))
  )
}

# ---- Server --------------------------------------------------------------

# Returns list(subject_id = <reactive>, nuevo = <reactive that changes when
# "Nuevo participante" is clicked>) so app.R can redraw the questionnaire forms.
mod_participant_registro_server <- function(id, pool, collected_by) {
  moduleServer(id, function(input, output, session) {

    subject_id <- reactiveVal(NULL)

    or_na <- function(x) if (is.null(x) || length(x) == 0) NA else x

    # The form fields are redrawn every time "Nuevo participante" is clicked,
    # which brings them back to their blank starting state.
    output$fields <- renderUI({
      input$nuevo
      ns <- session$ns
      tagList(
        textInput(ns("name"), "Nombre completo"),
        numericInput(ns("age"), "Edad", value = NA, min = 0, max = 120),
        radioButtons(ns("sex"), "Sexo", choices = c("H" = "H", "M" = "M"), selected = character(0)),
        selectInput(ns("school"), "Escuela",
                    choices = c("Seleccione" = "",
                                "Preparatoria Nocturna" = "Preparatoria Nocturna",
                                "Preparatoria San Miguel" = "Preparatoria San Miguel"))
      )
    })

    observeEvent(input$registrar, {
      if (!is.null(subject_id())) {
        showNotification("Ya hay un participante activo. Presiona 'Nuevo participante' primero.",
                         type = "warning")
        return()
      }

      name <- trimws(input$name)
      if (!nzchar(name)) {
        showNotification("Escribe el nombre del participante.", type = "error")
        return()
      }

      conn <- poolCheckout(pool)
      on.exit(poolReturn(conn))

      tryCatch({
        dbBegin(conn)

        res <- dbGetQuery(conn, "
          INSERT INTO participants (age, sex, school, collected_by)
          VALUES ($1, $2, $3, $4)
          RETURNING subject_id",
          params = list(or_na(input$age), or_na(input$sex), if (is.null(input$school) || !nzchar(input$school)) NA else input$school, collected_by())
        )
        new_id <- res$subject_id[1]

        dbExecute(conn, "
          INSERT INTO participant_identity (subject_id, name)
          VALUES ($1, $2)",
          params = list(new_id, name)
        )

        dbCommit(conn)

        subject_id(new_id)
        disable("registrar")
        showNotification("Participante registrado correctamente.", type = "message")
      }, error = function(e) {
        try(dbRollback(conn), silent = TRUE)
        showNotification(paste("Error al registrar:", e$message), type = "error")
      })
    })

    observeEvent(input$nuevo, {
      subject_id(NULL)
      enable("registrar")
      showNotification("Listo para un nuevo participante.", type = "message")
    })

    output$current_subject <- renderText({
      if (is.null(subject_id())) "Ningún participante registrado"
      else paste("subject_id:", subject_id())
    })

    list(subject_id = subject_id, nuevo = reactive(input$nuevo))
  })
}
