library(shiny)
library(pool)
library(DBI)

# POSIT item labels
posit_items <- c(
  question1  = "¿Has tenido problemas porque consumes drogas o bebidas alcohólicas en la escuela o en el trabajo?",
  question2  = "¿Te has hecho daño o has hecho daño a otra persona accidentalmente estando bajo el efecto de las drogas o el alcohol?",
  question3  = "¿Sueles perderte actividades o acontecimientos porque has gastado demasiado dinero en drogas o bebidas alcohólicas?",
  question4  = "¿Has sentido que eres adicto (a) al alcohol o a las drogas?",
  question5  = "¿Has comenzado a consumir mayores cantidades de drogas o alcohol para obtener el efecto que deseas?",
  question6  = "¿Te vas de las fiestas porque no hay bebidas alcohólicas o drogas?",
  question7  = "¿Sientes un deseo constante de consumir bebidas alcohólicas o drogas?",
  question8  = "¿Has tenido un accidente automovilístico estando bajo el efecto del alcohol o de drogas?",
  question9  = "¿Olvidas lo que haces cuando bebes o te drogas?",
  question10 = "El mes pasado ¿manejaste un automóvil estando borracho(a) o drogado(a)?",
  question11 = "¿El uso del alcohol o de las drogas te produce cambios repentinos de humor, como pasar de estar contento(a) a estar triste, o de estar triste a estar contento(a)?",
  question12 = "¿Pierdes días de clase o llegas tarde a la escuela o al trabajo por haber consumido bebidas alcohólicas o drogas?",
  question13 = "¿Te han dicho alguna vez tus familiares o amigos que debes bajarle al consumo de bebidas alcohólicas o drogas?",
  question14 = "¿Discutes seriamente con tus amigos o familiares por el consumo que haces de las bebidas alcohólicas o drogas?",
  question15 = "¿Las bebidas alcohólicas o las drogas te han llevado hacer algo que normalmente no harías, como desobedecer alguna regla o ley, o la hora de llegar a casa, o a tener relaciones sexuales con alguien?",
  question16 = "¿Tienes dificultades con alguno de tus amigos debido a las bebidas alcohólicas o drogas que consumes?",
  question17 = "¿Has sentido que no puedes controlar el deseo de consumir bebidas alcohólicas o drogas?"
)

posit_si_no <- c("Sí" = "true", "No" = "false")

# ---- UI ----------------------------------------------------------------

mod_questionnaire_posit_ui <- function(id) {
  ns <- NS(id)

  tagList(
    questionnaire_header(
      "POSIT",
      "Cuestionario para evaluación de conductas en el adolescente (POSIT)",
      tagList("Contesta todas las preguntas. Escoge la respuesta ", strong("“SÍ” o “NO”"),
              " que más se acerque a la verdad en tu caso."),
      "Al responder piensa en lo que te ha ocurrido durante los últimos seis meses."
    ),
    lapply(names(posit_items), function(q) {
      radioButtons(ns(q), posit_items[[q]], choices = posit_si_no,
                   selected = character(0), inline = TRUE)
    }),
    actionButton(ns("submit"), "Guardar respuestas", class = "btn-primary")
  )
}

# ---- Server --------------------------------------------------------------

mod_questionnaire_posit_server <- function(id, pool, subject_id, collected_by) {
  moduleServer(id, function(input, output, session) {

    observeEvent(input$submit, {
      if (is.null(subject_id())) {
        showNotification("Primero registra un participante (pestaña Registro).", type = "error")
        return()
      }

      q_names <- names(posit_items)
      to_bool <- function(x) if (is.null(x)) NA else as.logical(x)
      vals <- c(list(subject_id()), lapply(q_names, function(q) to_bool(input[[q]])))

      vals <- c(vals, list(collected_by()))
      col_list <- paste(c("subject_id", q_names, "collected_by"), collapse = ", ")
      placeholders <- paste0("$", seq_along(vals), collapse = ", ")

      tryCatch({
        dbExecute(
          pool,
          sprintf("INSERT INTO questionnaire_posit (%s) VALUES (%s)", col_list, placeholders),
          params = unname(vals)
        )
        showNotification("Respuestas guardadas correctamente.", type = "message")
      }, error = function(e) {
        showNotification(paste("Error al guardar:", e$message), type = "error")
      })
    })
  })
}