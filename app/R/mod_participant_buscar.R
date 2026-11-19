library(shiny)
library(pool)
library(DBI)

# Search a participant by name and show which questionnaires they finished.
# Uses questionnaire_status() and LINK_QUESTIONNAIRES from participant_links.R.

# Lowercase without accents, so "maria" finds "María"
buscar_fold_sql <- function(expr) {
  sprintf("lower(translate(%s, 'ÁÉÍÓÚÜÑáéíóúüñ', 'AEIOUUNaeiouun'))", expr)
}

# ---- UI ----------------------------------------------------------------

mod_participant_buscar_ui <- function(id) {
  ns <- NS(id)

  tagList(
    h4("Buscar participante"),
    p(class = "text-muted",
      "Escribe el nombre (o parte de él) para revisar qué cuestionarios ya terminó."),
    fluidRow(
      column(6, textInput(ns("nombre"), NULL, placeholder = "Nombre del participante")),
      column(3, actionButton(ns("buscar"), "Buscar", icon = icon("magnifying-glass")))
    ),
    uiOutput(ns("resultados")),
    tableOutput(ns("estado")),
    uiOutput(ns("usar_ui"))
  )
}

# ---- Server --------------------------------------------------------------

mod_participant_buscar_server <- function(id, pool) {
  moduleServer(id, function(input, output, session) {

    matches <- eventReactive(input$buscar, {
      nombre <- trimws(input$nombre)
      if (!nzchar(nombre)) {
        showNotification("Escribe un nombre para buscar.", type = "warning")
        return(NULL)
      }
      tryCatch(
        dbGetQuery(pool, sprintf("
          SELECT p.subject_id::text AS subject_id, i.name,
                 to_char(p.created_at AT TIME ZONE 'America/Mexico_City', 'DD/MM/YYYY HH24:MI') AS registro,
                 p.collected_by
          FROM participant_identity i
          JOIN participants p ON p.subject_id = i.subject_id
          WHERE %s LIKE '%%' || %s || '%%'
          ORDER BY p.created_at DESC
          LIMIT 20",
          buscar_fold_sql("i.name"), buscar_fold_sql("$1")),
          params = list(nombre)),
        error = function(e) {
          showNotification(paste("Error al buscar:", e$message), type = "error")
          NULL
        })
    })

    output$resultados <- renderUI({
      m <- matches()
      req(m)
      if (nrow(m) == 0) return(p(em("No se encontró ningún participante con ese nombre.")))
      labels <- sprintf("%s (registrado %s por %s)", m$name, m$registro, m$collected_by)
      radioButtons(session$ns("subject"),
                   if (nrow(m) == 1) "Participante encontrado:" else
                     sprintf("Se encontraron %d participantes, elige uno:", nrow(m)),
                   choices = stats::setNames(m$subject_id, labels),
                   selected = m$subject_id[1])
    })

    output$estado <- renderTable({
      m <- matches()
      req(m, nrow(m) > 0, input$subject %in% m$subject_id)
      invalidateLater(5000)
      st <- questionnaire_status(pool, input$subject)
      data.frame(Cuestionario = names(LINK_QUESTIONNAIRES),
                 Estado = ifelse(st[unname(LINK_QUESTIONNAIRES)], "Completado", "Pendiente"))
    }, striped = TRUE)

    # Hand the chosen participant to the link panel (so a new QR can be made for them)
    selected <- reactiveVal(NULL)

    output$usar_ui <- renderUI({
      m <- matches()
      req(m, nrow(m) > 0)
      actionButton(session$ns("usar"), "Generar enlace para este participante",
                   class = "btn-primary", icon = icon("qrcode"))
    })

    observeEvent(input$usar, {
      m <- matches()
      req(m, input$subject %in% m$subject_id)
      # a fresh list each time, so choosing the same person again still counts as a change
      selected(list(id = input$subject, at = Sys.time()))
      showNotification(
        sprintf("Seleccionado: %s. Baja a \"Enlace para que el participante responda\" para generar el QR.",
                m$name[m$subject_id == input$subject][1]),
        type = "message", duration = 8)
    })

    list(selected = selected)
  })
}
