library(shiny)
library(shinyjs)
library(DBI)
library(shinymanager)

source("global.R")

source("R/participant_links.R")
source("R/mod_participant_registro.R")
source("R/mod_participant_buscar.R")
source("R/mod_questionnaire_ipaq.R")
source("R/mod_questionnaire_posit.R")
source("R/mod_questionnaire_psqi.R")
source("R/mod_questionnaire_amai.R")
source("R/mod_questionnaire_pss.R")
source("R/mod_questionnaire_cfca.R")
source("R/mod_questionnaire_pnc.R")
source("R/participant_mode.R")
source("R/mod_registros.R")
source("R/mod_descargas.R")

# ---- Login credentials (team members) -----------------------------------
# Usernames come from APP_USERS (comma-separated, first one is the admin) and
# passwords from APP_PASS_<USERNAME in uppercase>, e.g. APP_USERS=ana,luis -> APP_PASS_ANA.
users <- trimws(tolower(strsplit(Sys.getenv("APP_USERS", ""), ",")[[1]]))
users <- users[nzchar(users)]
if (length(users) == 0) {
  stop("Set APP_USERS to a comma-separated list of usernames, e.g. APP_USERS=ana,luis")
}

passwords <- vapply(users, function(u) Sys.getenv(paste0("APP_PASS_", toupper(u)), ""), character(1))

# Fail closed: refuse to start if any password is missing
missing_pw <- users[!nzchar(passwords)]
if (length(missing_pw) > 0) {
  stop("Missing password env var(s) for: ", paste(missing_pw, collapse = ", "),
       ". Set APP_PASS_<USER> for each.")
}

credentials <- data.frame(
  user = users,
  password = unname(passwords),
  admin = c(TRUE, rep(FALSE, length(users) - 1)),
  stringsAsFactors = FALSE
)

# Re-check a logged-in user's password (used to unlock data downloads)
check_password <- function(user, password) {
  i <- match(user, credentials$user)
  !is.na(i) && is.character(password) && length(password) == 1 &&
    identical(password, credentials$password[i])
}

# ---- Team UI (behind the login) -------------------------------------------
staff_ui <- fluidPage(
  useShinyjs(),
  titlePanel("Captura de datos"),
  tabsetPanel(
    tabPanel("Registro", mod_participant_registro_ui("registro"), hr(), mod_participant_buscar_ui("buscar"),
             hr(), mod_participant_links_ui("links")),
    tabPanel("IPAQ", uiOutput("form_ipaq")),
    tabPanel("POSIT", uiOutput("form_posit")),
    tabPanel("PSQI", uiOutput("form_psqi")),
    tabPanel("AMAI", uiOutput("form_amai")),
    tabPanel("PSS", uiOutput("form_pss")),
    tabPanel("CFCA", uiOutput("form_cfca")),
    tabPanel("PNC", uiOutput("form_pnc")),
    tabPanel("Registros", mod_registros_ui("registros")),
    tabPanel("Descargas", mod_descargas_ui("descargas"))
  )
)
secure_staff_ui <- secure_app(
  staff_ui,
  language = "es",
  tags_top = tags$div(
    style = "text-align: center; margin-bottom: 10px;",
    # Wider login box than shinymanager's default third of the page; full width on phones
    tags$style(".panel-auth .col-sm-4 { float: none; width: 560px; max-width: 100%; margin: 0 auto; }"),
    tags$h2("Exposoma-Adolescentes",
            style = "font-size: clamp(20px, 6vw, 30px); font-weight: 700; color: #1f4e79; margin-bottom: 12px; white-space: nowrap;"),
    tags$p(
      style = "font-size: 14px; font-weight: 600; line-height: 1.4; color: #333;",
      "Análisis del Exposoma Externo y su Asociación con Indicadores de Riesgo para ",
      "Enfermedad Hepática Esteatósica Asociada a Disfunción Metabólica en ",
      "Adolescentes con Sobrepeso y/o Obesidad"
    ),
    tags$p(style = "font-size: 13px; color: #666; margin-top: 10px;",
           "Plataforma de captura de datos para el equipo de investigación")
  ),
  tags_bottom = tags$div(
    style = "font-size: 12px; color: #777; text-align: center; margin-top: 10px;",
    tags$p("Acceso exclusivo para investigadores y personal autorizado del proyecto. ",
           "La información registrada es confidencial y se utiliza únicamente con fines ",
           "de investigación, conforme al protocolo aprobado y a la normativa vigente ",
           "de protección de datos personales."),
    tags$p("Si tiene problemas para ingresar, contacte al coordinador del proyecto.")
  )
)

# A request with ?t=<token> gets the participant page (no login);
# everything else needs the team login.
ui <- function(request) {
  token <- parseQueryString(request$QUERY_STRING)[["t"]]
  if (!is.null(token) && nzchar(token)) participant_ui() else secure_staff_ui(request)
}

server <- function(input, output, session) {

  # ---- Participant link: only that participant's questionnaires ----------
  token <- parseQueryString(isolate(session$clientData$url_search))[["t"]]
  if (!is.null(token) && nzchar(token)) {
    participant_server(token, pool, input, output, session)
    return(invisible(NULL))
  }

  # ---- Team members (login) ------------------------------------------------
  res_auth <- secure_server(check_credentials = check_credentials(credentials))

  # Username of the logged-in team member, stamped on every saved row
  collected_by <- reactive({
    req(res_auth$user)
    res_auth$user
  })

  registro <- mod_participant_registro_server("registro", pool, collected_by)
  subject_id <- registro$subject_id

  buscar <- mod_participant_buscar_server("buscar", pool)

  # The participant the link panel works on: the one just registered, or one picked from the search
  link_subject <- reactiveVal(NULL)
  observeEvent(subject_id(), link_subject(subject_id()), ignoreNULL = FALSE)
  observeEvent(buscar$selected(), link_subject(buscar$selected()$id), ignoreNULL = TRUE)

  mod_participant_links_server("links", pool, link_subject, collected_by)

  # Each questionnaire form is drawn with renderUI and depends on the
  # "Nuevo participante" counter, so clicking that button redraws every
  # form from scratch, blank.
  forms <- list(
    form_ipaq  = list(ui = mod_questionnaire_ipaq_ui,  id = "ipaq"),
    form_posit = list(ui = mod_questionnaire_posit_ui, id = "posit"),
    form_psqi  = list(ui = mod_questionnaire_psqi_ui,  id = "psqi"),
    form_amai  = list(ui = mod_questionnaire_amai_ui,  id = "amai"),
    form_pss   = list(ui = mod_questionnaire_pss_ui,   id = "pss"),
    form_cfca  = list(ui = mod_questionnaire_cfca_ui,  id = "cfca"),
    form_pnc   = list(ui = mod_questionnaire_pnc_ui,   id = "pnc")
  )

  lapply(names(forms), function(out_id) {
    f <- forms[[out_id]]
    output[[out_id]] <- renderUI({
      registro$nuevo()
      f$ui(f$id)
    })
  })

  mod_questionnaire_ipaq_server("ipaq", pool, subject_id = subject_id, collected_by = collected_by)
  mod_questionnaire_posit_server("posit", pool, subject_id = subject_id, collected_by = collected_by)
  mod_questionnaire_psqi_server("psqi", pool, subject_id = subject_id, collected_by = collected_by)
  mod_questionnaire_amai_server("amai", pool, subject_id = subject_id, collected_by = collected_by)
  mod_questionnaire_pss_server("pss", pool, subject_id = subject_id, collected_by = collected_by)
  mod_questionnaire_cfca_server("cfca", pool, subject_id = subject_id, collected_by = collected_by)
  mod_questionnaire_pnc_server("pnc", pool, subject_id = subject_id, collected_by = collected_by)

  mod_registros_server("registros", pool, user = collected_by, check_password = check_password)
  mod_descargas_server("descargas", pool, user = collected_by, check_password = check_password)
}

shinyApp(ui, server)
