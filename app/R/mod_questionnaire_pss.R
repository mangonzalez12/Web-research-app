library(shiny)
library(pool)
library(DBI)

pss_scale_choices <- c(
  "Nunca"           = "0",
  "Casi nunca"      = "1",
  "Algunas veces"   = "2",
  "Poco frecuente"  = "3",
  "Muy frecuente"   = "4"
)

# Item labels - matched to model columns q1..q14.
pss_items <- c(
  q1  = "En el último mes, ¿con qué frecuencia se ha sentido preocupado por algo que ha sucedido inesperadamente?",
  q2  = "En el último mes, ¿con qué frecuencia se sintió incapaz de controlar las cosas importantes de su vida?",
  q3  = "En el último mes, ¿con qué frecuencia se sintió nervioso y estresado?",
  q4  = "En el último mes, ¿con qué frecuencia se enfrentó a sucesos molestos o irritantes?",
  q5  = "En el último mes, ¿con qué frecuencia sintió que estaba enfrentándose satisfactoriamente con los cambios importantes que estaban ocurriendo en su vida?",
  q6  = "En el último mes, ¿con qué frecuencia se sintió confiado en su capacidad para manejar sus problemas personales?",
  q7  = "En el último mes, ¿con qué frecuencia sintió que las cosas le estaban saliendo bien?",
  q8  = "En el último mes, ¿con qué frecuencia sintió que no podía enfrentarse a todas las cosas que tenía por hacer?",
  q9  = "En el último mes, ¿con qué frecuencia ha sido capaz de controlar su enojo?",
  q10 = "En el último mes, ¿con qué frecuencia ha sentido que está hasta el límite de sus capacidades en los asuntos de su vida diaria?",
  q11 = "En el último mes, ¿con qué frecuencia se ha molestado por sucesos que están fuera de su control?",
  q12 = "En el último mes, ¿con qué frecuencia se ha encontrado pensando acerca de las cosas que tiene que realizar?",
  q13 = "En el último mes, ¿con qué frecuencia se ha sentido capaz de controlar la manera en que dispone de su tiempo?",
  q14 = "En el último mes, ¿con qué frecuencia sintió que las dificultades estaban acumulándose tanto que no podría superarlas?"
)

# ---- UI ----------------------------------------------------------------

mod_questionnaire_pss_ui <- function(id) {
  ns <- NS(id)

  tagList(
    questionnaire_header(
      "Escala de Estrés Percibido (PSS)",
      NULL,
      tagList("Las preguntas en esta escala le cuestionan acerca de sus sentimientos e ideas experimentados durante el ",
              strong("último mes"), "."),
      "En cada caso usted será cuestionado para indicar qué tan frecuentemente siente o piensa en relación a determinado aspecto.",
      "No trate de contar el número de veces que usted experimentó un aspecto en particular, sólo realice una estimación razonable.",
      tagList("Para cada pregunta escoja alguna de las siguientes alternativas: ",
              strong("Nunca"), ", ", strong("Casi nunca"), ", ", strong("Algunas veces"), ", ",
              strong("Poco frecuente"), " o ", strong("Muy frecuente"), ".")
    ),
    lapply(names(pss_items), function(q) {
      radioButtons(ns(q), paste0(toupper(q), ". ", pss_items[[q]]),
                   choices = pss_scale_choices, selected = character(0))
    }),
    actionButton(ns("submit"), "Guardar respuestas", class = "btn-primary")
  )
}

# ---- Server --------------------------------------------------------------

mod_questionnaire_pss_server <- function(id, pool, subject_id, collected_by) {
  moduleServer(id, function(input, output, session) {

    observeEvent(input$submit, {
      if (is.null(subject_id())) {
        showNotification("Primero registra un participante (pestaña Registro).", type = "error")
        return()
      }

      q_names <- names(pss_items)
      to_int <- function(x) if (is.null(x)) NA_integer_ else as.integer(x)

      vals <- c(
        list(subject_id = subject_id()),
        setNames(lapply(q_names, function(q) to_int(input[[q]])), q_names)
      )

      vals$collected_by <- collected_by()
      col_list <- paste(names(vals), collapse = ", ")
      placeholders <- paste0("$", seq_along(vals), collapse = ", ")

      tryCatch({
        dbExecute(
          pool,
          sprintf("INSERT INTO questionnaire_pss (%s) VALUES (%s)", col_list, placeholders),
          params = unname(vals)
        )
        showNotification("Respuestas guardadas correctamente.", type = "message")
      }, error = function(e) {
        showNotification(paste("Error al guardar:", e$message), type = "error")
      })
    })
  })
}
