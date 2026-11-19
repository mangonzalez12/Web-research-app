library(shiny)
library(pool)
library(DBI)

# Cooking methods of each food (empty table, plus a visible error, if they cannot be loaded)
load_cooking_methods <- function(pool) {
  tryCatch(
    dbGetQuery(pool, "
      SELECT cooking_method_id, food_item_id, name
      FROM food_cooking_methods
      ORDER BY food_item_id, cooking_method_id"),
    error = function(e) {
      if (!is.null(getDefaultReactiveDomain())) {
        showNotification(paste("No se pudieron cargar los métodos de preparación:", e$message),
                         type = "error", duration = NULL)
      }
      data.frame(cooking_method_id = integer(), food_item_id = integer(), name = character())
    }
  )
}

# The inputs of one food (plus one box per cooking method when the food has methods)
cfca_food_row <- function(ns, foods, i, cmethods) {
  fid <- foods$food_item_id[i]

  portion_txt <- foods$portion_description[i]
  has_portion <- !is.null(portion_txt) && !is.na(portion_txt) && nzchar(portion_txt)

  m <- cmethods[cmethods$food_item_id == fid, , drop = FALSE]
  has_methods <- nrow(m) > 0

  tagList(
    fluidRow(
      column(5,
        strong(foods$name[i]),
        if (has_portion) tagList(br(), em(portion_txt))
      ),
      column(2, numericInput(ns(paste0("days_", fid)), "Días (0-7)", value = NA, min = 0, max = 7)),
      column(2, numericInput(ns(paste0("times_", fid)), "Veces/día (1-6)", value = NA, min = 1, max = 6)),
      column(3,
        if (has_methods) {
          div(style = "padding-top: 28px;", em("Total = suma de los métodos"))
        } else {
          numericInput(ns(paste0("numport_", fid)), "Núm. porciones", value = NA, min = 0, step = 0.5)
        }
      )
    ),
    if (has_methods) {
      w <- if (nrow(m) <= 3) 4 else 2
      fluidRow(
        column(12, strong("Porciones por método de preparación:")),
        lapply(seq_len(nrow(m)), function(j) {
          column(w, numericInput(ns(paste0("cm_", m$cooking_method_id[j])),
                                 m$name[j], value = NA, min = 0, step = 0.5))
        })
      )
    }
  )
}

# ---- UI ----------------------------------------------------------------
# per_category = FALSE: team form, every food on screen, one save button.
# per_category = TRUE : participant form, each category has its own save button
#                       and locks once it has been saved.

mod_questionnaire_cfca_ui <- function(id, per_category = FALSE) {
  ns <- NS(id)

  # NOTE: this queries the DB when the form is drawn.
  # Requires `pool` to already be connected and food_items seeded.
  foods <- dbGetQuery(pool, "SELECT * FROM food_items ORDER BY category, food_item_id")
  categories <- unique(foods$category)

  intro <- tagList(
    questionnaire_header(
      "Cuestionario de Frecuencia de Consumo de Alimentos (CFCA)",
      "Frecuencia de consumo de alimentos de adolescentes y adultos (≥ 12 años de edad) (ENSANUT Continua 2024)",
      "A continuación, se le harán preguntas sobre los alimentos y bebidas que ha consumido.",
      "Por favor, responda con la mayor precisión posible.",
      "Si no recuerda exactamente, responda la mejor aproximación.",
      tagList("Indique su consumo en los ", strong("últimos 7 días"), ".")
    ),
    p("Para cada alimento: días que lo consumió (0-7), veces al día (1-6), ",
      "y número de porciones. ",
      "En los alimentos con métodos de preparación, anota las porciones de cada método.")
  )

  if (!per_category) {
    cmethods <- load_cooking_methods(pool)
    tabs <- lapply(categories, function(category) {
      items <- foods[foods$category == category, ]
      tabPanel(category, lapply(seq_len(nrow(items)), function(i) cfca_food_row(ns, items, i, cmethods)))
    })
    return(tagList(
      intro,
      do.call(tabsetPanel, tabs),
      br(),
      actionButton(ns("submit"), "Guardar respuestas", class = "btn-primary")
    ))
  }

  tabs <- lapply(seq_along(categories), function(k) {
    tabPanel(categories[k], uiOutput(ns(paste0("cat_ui_", k))))
  })
  tagList(
    intro,
    p(em("Guarda cada categoría cuando termines con ella. Si no comiste nada de esa categoría, ",
         "guárdala vacía. Después de guardar ya no se puede cambiar.")),
    do.call(tabsetPanel, tabs)
  )
}

# ---- Server --------------------------------------------------------------

mod_questionnaire_cfca_server <- function(id, pool, subject_id, collected_by, per_category = FALSE) {
  moduleServer(id, function(input, output, session) {

    ns <- session$ns
    num_or_na <- function(x) if (is.null(x) || length(x) == 0) NA_real_ else as.numeric(x)

    # Reads the inputs of the given foods and returns the rows to save (foods left blank are skipped)
    collect_rows <- function(food_ids, cmethods) {
      Filter(Negate(is.null), lapply(food_ids, function(fid) {
        days    <- num_or_na(input[[paste0("days_", fid)]])
        times   <- num_or_na(input[[paste0("times_", fid)]])

        m_ids <- cmethods$cooking_method_id[cmethods$food_item_id == fid]

        if (length(m_ids) > 0) {
          # foods with cooking methods: Num. porciones = sum of the method boxes
          m_vals <- vapply(m_ids, function(mid) num_or_na(input[[paste0("cm_", mid)]]), numeric(1))
          numport <- if (all(is.na(m_vals))) NA_real_ else sum(m_vals, na.rm = TRUE)
        } else {
          m_vals <- numeric(0)
          numport <- num_or_na(input[[paste0("numport_", fid)]])
        }

        answered <- !is.na(days) || !is.na(times) || !is.na(numport)
        if (!answered) return(NULL)

        list(
          main = list(
            subject_id     = subject_id(),
            food_item_id   = fid,
            days_per_week  = if (is.na(days)) NA_integer_ else as.integer(days),
            times_per_day  = if (is.na(times)) NA_integer_ else as.integer(times),
            num_portions   = numport
          ),
          m_ids  = m_ids[!is.na(m_vals)],
          m_vals = m_vals[!is.na(m_vals)]
        )
      }))
    }

    # Saves the rows, and marks the given categories as saved, in ONE transaction
    save_rows <- function(rows, categories_to_mark) {
      conn <- poolCheckout(pool)
      on.exit(poolReturn(conn))
      tryCatch({
        dbBegin(conn)
        for (r in rows) {
          res <- dbGetQuery(conn, "
            INSERT INTO cfca_responses
              (subject_id, food_item_id, days_per_week, times_per_day, num_portions, collected_by)
            VALUES ($1, $2, $3, $4, $5, $6)
            RETURNING response_id",
            params = unname(c(r$main, list(collected_by = collected_by())))
          )
          for (k in seq_along(r$m_ids)) {
            dbExecute(conn, "
              INSERT INTO cfca_cooking_responses (cfca_response_id, cooking_method_id, portions)
              VALUES ($1, $2, $3)",
              params = list(res$response_id[1], r$m_ids[k], r$m_vals[k])
            )
          }
        }
        for (category in categories_to_mark) {
          dbExecute(conn, "
            INSERT INTO cfca_category_progress (subject_id, category, collected_by)
            VALUES ($1, $2, $3)
            ON CONFLICT DO NOTHING",
            params = list(subject_id(), category, collected_by())
          )
        }
        dbCommit(conn)
        TRUE
      }, error = function(e) {
        try(dbRollback(conn), silent = TRUE)
        showNotification(paste("Error al guardar:", e$message), type = "error")
        FALSE
      })
    }

    # ---- team form: one button saves everything ----------------------------
    observeEvent(input$submit, {
      if (is.null(subject_id())) {
        showNotification("Primero registra un participante (pestaña Registro).", type = "error")
        return()
      }

      foods <- dbGetQuery(pool, "SELECT food_item_id, category FROM food_items")
      cmethods <- load_cooking_methods(pool)
      rows <- collect_rows(foods$food_item_id, cmethods)

      if (length(rows) == 0) {
        showNotification("No se registró ningún alimento.", type = "warning")
        return()
      }

      # saving the whole form also marks every category as done
      if (save_rows(rows, unique(foods$category))) {
        showNotification(sprintf("Se guardaron %d alimentos.", length(rows)), type = "message")
      }
    })

    # ---- participant form: one button per category --------------------------
    if (per_category) {
      categories <- unique(dbGetQuery(
        pool, "SELECT category FROM food_items ORDER BY category, food_item_id")$category)

      saved <- reactiveValues(ready = FALSE)

      refresh_saved <- function() {
        done <- dbGetQuery(pool, "SELECT category FROM cfca_category_progress WHERE subject_id = $1",
                           params = list(subject_id()))$category
        for (k in seq_along(categories)) saved[[paste0("k", k)]] <- categories[k] %in% done
        saved$ready <- TRUE
      }
      observeEvent(subject_id(), refresh_saved())

      lapply(seq_along(categories), function(k) {
        category <- categories[k]
        key <- paste0("k", k)

        output[[paste0("cat_ui_", k)]] <- renderUI({
          req(saved$ready)
          if (isTRUE(saved[[key]])) {
            div(class = "alert alert-success", "Categoría guardada. Gracias.")
          } else {
            foods <- dbGetQuery(pool, "SELECT * FROM food_items WHERE category = $1 ORDER BY food_item_id",
                                params = list(category))
            cmethods <- load_cooking_methods(pool)
            tagList(
              lapply(seq_len(nrow(foods)), function(i) cfca_food_row(ns, foods, i, cmethods)),
              br(),
              actionButton(ns(paste0("save_cat_", k)),
                           "Guardar esta categoría (ya no se podrá cambiar)", class = "btn-primary")
            )
          }
        })

        observeEvent(input[[paste0("save_cat_", k)]], {
          if (is.null(subject_id()) || isTRUE(saved[[key]])) return()

          foods <- dbGetQuery(pool, "SELECT food_item_id FROM food_items WHERE category = $1",
                              params = list(category))
          cmethods <- load_cooking_methods(pool)
          rows <- collect_rows(foods$food_item_id, cmethods)

          if (save_rows(rows, category)) {
            saved[[key]] <- TRUE
            showNotification("Categoría guardada.", type = "message")
          }
        })
      })
    }
  })
}
