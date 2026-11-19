library(shiny)
library(pool)
library(DBI)

# Shared 4-level frequency scale (Q5a-i, Q5j, Q7, Q8)
psqi_freq_choices <- c(
  "Ninguna vez en el último mes"     = "0",
  "Menos de una vez a la semana"     = "1",
  "Una o dos veces a la semana"      = "2",
  "Tres o más veces a la semana"     = "3"
)

# Q5a-i item labels, matched to model column names
psqi_q5_items <- c(
  q5a_no_sleep_30min = "No poder conciliar el sueño en la primera media hora",
  q5b_wake_night      = "Despertarse durante la noche o de madrugada",
  q5c_bathroom         = "Tener que levantarse para ir al sanitario",
  q5d_breathing        = "No poder respirar bien",
  q5e_cough_snore      = "Toser o roncar ruidosamente",
  q5f_cold              = "Sentir frío",
  q5g_hot               = "Sentir demasiado calor",
  q5h_nightmares       = "Tener pesadillas o \"malos sueños\"",
  q5i_pain              = "Sufrir dolores"
)

# Open answers: blank or "NA" (any case) are stored as NULL.
psqi_is_na <- function(x) is.null(x) || !nzchar(trimws(x)) || toupper(trimws(x)) == "NA"

psqi_parse_time <- function(x) {
  if (psqi_is_na(x)) return(NA_character_)
  x <- trimws(x)
  if (!grepl("^([01]?[0-9]|2[0-3]):[0-5][0-9]$", x)) stop("invalid")
  x
}

psqi_parse_number <- function(x, max = Inf) {
  if (psqi_is_na(x)) return(NA_real_)
  v <- suppressWarnings(as.numeric(sub(",", ".", trimws(x), fixed = TRUE)))
  if (is.na(v) || v < 0 || v > max) stop("invalid")
  v
}

# ---- UI ----------------------------------------------------------------

mod_questionnaire_psqi_ui <- function(id) {
  ns <- NS(id)

  tagList(
    questionnaire_header(
      "Índice de Calidad de Sueño de Pittsburgh (PSQI)",
      NULL,
      "Las siguientes preguntas hacen referencia a la manera en que ha dormido durante el último mes.",
      "Intente responder de la manera más exacta posible lo ocurrido durante la mayor parte de los días y noches del último mes.",
      tagList("Por favor conteste ", strong("TODAS"), " las preguntas."),
      "En las preguntas abiertas (1 a 4 y 5j), escriba NA si no sabe o no aplica."
    ),

    p(em("Las preguntas 1 a 4 se refieren a lo ocurrido durante la mayor parte de los días y noches del último mes.")),
    textInput(ns("bedtime"), "1. Hora usual de acostarse (formato HH:MM, o NA)", placeholder = "23:00"),
    textInput(ns("sleep_latency_minutes"), "2. Minutos que tarda en dormirse (o NA)", placeholder = "15"),
    textInput(ns("wake_time"), "3. Hora usual de levantarse (formato HH:MM, o NA)", placeholder = "07:00"),
    textInput(ns("sleep_hours"), "4. Horas que realmente durmió por noche (o NA)", placeholder = "7.5"),

    h4("5. Durante el último mes, ¿cuántas veces ha tenido problemas para dormir a causa de:"),
    lapply(names(psqi_q5_items), function(q) {
      radioButtons(ns(q), psqi_q5_items[[q]], choices = psqi_freq_choices, selected = character(0))
    }),

    textInput(ns("q5j_other_text"), "j. Otras razones (descríbalas, o NA)"),
    radioButtons(ns("q5j_other_freq"), "Frecuencia de la razón anterior",
                 choices = psqi_freq_choices, selected = character(0)),

    radioButtons(ns("sleep_quality"),
                 "6. En conjunto, ¿cómo valoraría la calidad de su dormir?",
                 choices = c("Bastante buena" = "0", "Buena" = "1",
                             "Mala" = "2", "Bastante mala" = "3"),
                 selected = character(0)),

    radioButtons(ns("sleep_medication_freq"),
                 "7. ¿Cuántas veces ha tomado medicinas para dormir?",
                 choices = psqi_freq_choices, selected = character(0)),

    radioButtons(ns("daytime_dysfunction_freq"),
                 "8. ¿Cuántas veces ha sentido somnolencia mientras conducía, comía o desarrollaba alguna otra actividad?",
                 choices = psqi_freq_choices, selected = character(0)),

    radioButtons(ns("enthusiasm_problem"),
                 "9. ¿Ha representado problema el \"tener ánimos\" para esas actividades?",
                 choices = c("Ningún problema" = "0", "Un problema muy ligero" = "1",
                             "Algo de problema" = "2", "Un gran problema" = "3"),
                 selected = character(0)),

    actionButton(ns("submit"), "Guardar respuestas", class = "btn-primary")
  )
}

# ---- Server --------------------------------------------------------------

mod_questionnaire_psqi_server <- function(id, pool, subject_id, collected_by) {
  moduleServer(id, function(input, output, session) {

    observeEvent(input$submit, {
      if (is.null(subject_id())) {
        showNotification("Primero registra un participante (pestaña Registro).", type = "error")
        return()
      }

      q5_vals <- lapply(names(psqi_q5_items), function(q) {
        v <- input[[q]]
        if (is.null(v)) NA_integer_ else as.integer(v)
      })
      names(q5_vals) <- names(psqi_q5_items)

      to_int <- function(x) if (is.null(x)) NA_integer_ else as.integer(x)

      # Validate open answers (Q1-Q4); each must be a valid value, blank or NA
      parse_or_report <- function(f, x, label) {
        tryCatch(f(x), error = function(e) {
          showNotification(paste0("Respuesta no válida en ", label, ". Corrige el valor o escribe NA."),
                           type = "error")
          NULL
        })
      }
      bedtime   <- parse_or_report(psqi_parse_time, input$bedtime, "la pregunta 1")
      latency   <- parse_or_report(psqi_parse_number, input$sleep_latency_minutes, "la pregunta 2")
      wake_time <- parse_or_report(psqi_parse_time, input$wake_time, "la pregunta 3")
      hours     <- parse_or_report(function(x) psqi_parse_number(x, max = 24), input$sleep_hours, "la pregunta 4")
      if (is.null(bedtime) || is.null(latency) || is.null(wake_time) || is.null(hours)) return()

      vals <- c(
        list(
          subject_id             = subject_id(),
          bedtime                = bedtime,
          sleep_latency_minutes  = as.integer(round(latency)),
          wake_time              = wake_time,
          sleep_hours            = hours
        ),
        q5_vals,
        list(
          q5j_other_text            = if (psqi_is_na(input$q5j_other_text)) NA else input$q5j_other_text,
          q5j_other_freq            = to_int(input$q5j_other_freq),
          sleep_quality             = to_int(input$sleep_quality),
          sleep_medication_freq     = to_int(input$sleep_medication_freq),
          daytime_dysfunction_freq  = to_int(input$daytime_dysfunction_freq),
          enthusiasm_problem        = to_int(input$enthusiasm_problem)
        )
      )

      vals$collected_by <- collected_by()
      col_list <- paste(names(vals), collapse = ", ")
      placeholders <- paste0("$", seq_along(vals), collapse = ", ")

      tryCatch({
        dbExecute(
          pool,
          sprintf("INSERT INTO questionnaire_psqi (%s) VALUES (%s)", col_list, placeholders),
          params = unname(vals)
        )
        showNotification("Respuestas guardadas correctamente.", type = "message")
      }, error = function(e) {
        showNotification(paste("Error al guardar:", e$message), type = "error")
      })
    })
  })
}
