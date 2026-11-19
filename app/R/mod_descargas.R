library(shiny)
library(pool)
library(DBI)

# Data downloads for the team. The user must type their password again;
# that unlocks downloads in this session for DESCARGAS_MINUTES minutes.
# Participant names (participant_identity) are never included.

DESCARGAS_MINUTES <- 15
DESCARGAS_MAX_ATTEMPTS <- 5
DESCARGAS_TZ <- "America/Mexico_City"

# File code -> label shown, and the SQL that produces it (subject_id first)
DESCARGAS_TABLES <- list(
  participantes = list(label = "Participantes", sql = "
    SELECT subject_id, created_at, collected_by, age, sex, school
    FROM participants ORDER BY created_at"),
  ipaq  = list(label = "IPAQ",  sql = "SELECT * FROM questionnaire_ipaq ORDER BY subject_id, submitted_at"),
  posit = list(label = "POSIT", sql = "SELECT * FROM questionnaire_posit ORDER BY subject_id, submitted_at"),
  psqi  = list(label = "PSQI",  sql = "SELECT * FROM questionnaire_psqi ORDER BY subject_id, submitted_at"),
  amai  = list(label = "AMAI",  sql = "SELECT * FROM questionnaire_amai ORDER BY subject_id, submitted_at"),
  pss   = list(label = "PSS",   sql = "SELECT * FROM questionnaire_pss ORDER BY subject_id, submitted_at"),
  pnc   = list(label = "PNC",   sql = "SELECT * FROM questionnaire_pnc ORDER BY subject_id, submitted_at"),
  cfca  = list(label = "CFCA (un renglón por alimento)", sql = "
    SELECT r.subject_id, r.response_id, r.submitted_at, r.collected_by,
           r.food_item_id, f.category, f.name AS food_name, f.portion_description,
           r.days_per_week, r.times_per_day, r.portion_size, r.num_portions
    FROM cfca_responses r
    JOIN food_items f ON f.food_item_id = r.food_item_id
    ORDER BY r.subject_id, r.food_item_id"),
  cfca_coccion = list(label = "CFCA métodos de preparación", sql = "
    SELECT r.subject_id, c.cfca_response_id, r.food_item_id, f.name AS food_name,
           m.name AS cooking_method, c.portions
    FROM cfca_cooking_responses c
    JOIN cfca_responses r ON r.response_id = c.cfca_response_id
    JOIN food_items f ON f.food_item_id = r.food_item_id
    JOIN food_cooking_methods m ON m.cooking_method_id = c.cooking_method_id
    ORDER BY r.subject_id, r.food_item_id, m.name")
)

# Questionnaires that have one row per participant and can go in the combined file
DESCARGAS_COMBINABLE <- c("ipaq", "posit", "psqi", "amai", "pss", "pnc")

descargas_read <- function(pool, code) {
  df <- dbGetQuery(pool, DESCARGAS_TABLES[[code]]$sql)
  df <- df[c("subject_id", setdiff(names(df), "subject_id"))]
  for (col in names(df)) {
    x <- df[[col]]
    if (inherits(x, "POSIXct")) df[[col]] <- format(x, "%Y-%m-%d %H:%M:%S", tz = DESCARGAS_TZ)
    else if (inherits(x, "difftime")) df[[col]] <- as.character(x)  # time of day (hms)
  }
  df
}

# One row per participant: registration data plus the most recent answer of
# each selected questionnaire, columns prefixed with the questionnaire code.
descargas_combined <- function(pool, codes) {
  combined <- descargas_read(pool, "participantes")
  names(combined)[-1] <- paste0("registro_", names(combined)[-1])
  for (code in codes) {
    df <- descargas_read(pool, code)
    # rows are sorted by submitted_at, so the last one per participant is the newest
    df <- df[!duplicated(df$subject_id, fromLast = TRUE), setdiff(names(df), "response_id"), drop = FALSE]
    names(df)[-1] <- paste0(code, "_", names(df)[-1])
    combined <- merge(combined, df, by = "subject_id", all.x = TRUE, sort = FALSE)
  }
  combined[order(combined$registro_created_at), , drop = FALSE]
}

# UTF-8 with BOM so Excel shows accents and ñ correctly
descargas_write_csv <- function(df, file) {
  con <- file(file, open = "w", encoding = "UTF-8")
  on.exit(close(con))
  writeLines("﻿", con, sep = "")
  utils::write.csv(df, con, row.names = FALSE, na = "")
}

# ---- UI ----------------------------------------------------------------

mod_descargas_ui <- function(id) {
  ns <- NS(id)
  tagList(
    h3("Descargar datos"),
    p(class = "text-muted",
      "Por seguridad, confirma tu contraseña para descargar. Los archivos incluyen el ",
      "subject_id de cada participante para unir las tablas; nunca incluyen nombres."),
    uiOutput(ns("contenido"))
  )
}

# ---- Server --------------------------------------------------------------

# check_password(user, password) -> TRUE/FALSE
mod_descargas_server <- function(id, pool, user, check_password) {
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
                                 format(b, "%H:%M", tz = DESCARGAS_TZ)), type = "error")
        return()
      }
      ok <- isTRUE(check_password(user(), input$password))
      updateTextInput(session, "password", value = "")
      if (ok) {
        failed(0)
        unlocked_until(Sys.time() + DESCARGAS_MINUTES * 60)
        message(sprintf("[descargas] %s desbloqueó descargas", user()))
      } else {
        failed(failed() + 1)
        message(sprintf("[descargas] %s: contraseña incorrecta (%d)", user(), failed()))
        if (failed() >= DESCARGAS_MAX_ATTEMPTS) {
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
          passwordInput(ns("password"), sprintf("Contraseña de %s", user())),
          actionButton(ns("confirmar"), "Confirmar", class = "btn-primary", icon = icon("lock-open"))
        ))
      }
      tagList(
        div(class = "alert alert-success",
            sprintf("Descargas habilitadas hasta las %s. ",
                    format(unlocked_until(), "%H:%M", tz = DESCARGAS_TZ)),
            actionLink(ns("bloquear"), "Bloquear ahora")),

        h4("Un archivo por cuestionario"),
        div(lapply(names(DESCARGAS_TABLES), function(code) {
          downloadButton(ns(paste0("dl_", code)), DESCARGAS_TABLES[[code]]$label,
                         style = "margin: 0 6px 8px 0;")
        })),

        h4("Archivo combinado"),
        p(class = "text-muted",
          "Un renglón por participante con sus datos de registro y los cuestionarios elegidos. ",
          "Si un cuestionario se guardó más de una vez, se usa la respuesta más reciente. ",
          "El CFCA no se incluye porque tiene un renglón por alimento."),
        checkboxGroupInput(ns("combinar"), NULL, inline = TRUE,
                           choices = stats::setNames(DESCARGAS_COMBINABLE,
                             vapply(DESCARGAS_COMBINABLE, function(c) DESCARGAS_TABLES[[c]]$label, "")),
                           selected = DESCARGAS_COMBINABLE),
        downloadButton(ns("dl_combinado"), "Descargar combinado", class = "btn-primary")
      )
    })

    stamp <- function() format(Sys.time(), "%Y-%m-%d_%H%M", tz = DESCARGAS_TZ)

    # Every download re-checks the unlock on the server, not only in the UI
    guarded <- function(what, fun) {
      function(file) {
        if (!is_unlocked()) stop("Descargas bloqueadas. Confirma tu contraseña.")
        message(sprintf("[descargas] %s descargó %s", user(), what))
        fun(file)
      }
    }

    lapply(names(DESCARGAS_TABLES), function(code) {
      output[[paste0("dl_", code)]] <- downloadHandler(
        filename = function() sprintf("exposoma_%s_%s.csv", code, stamp()),
        content = guarded(code, function(file) descargas_write_csv(descargas_read(pool, code), file)),
        contentType = "text/csv"
      )
    })

    output$dl_combinado <- downloadHandler(
      filename = function() sprintf("exposoma_combinado_%s.csv", stamp()),
      content = guarded("combinado", function(file) {
        codes <- intersect(input$combinar, DESCARGAS_COMBINABLE)
        descargas_write_csv(descargas_combined(pool, codes), file)
      }),
      contentType = "text/csv"
    )
  })
}
