library(pool)
library(RPostgres)

database_url <- Sys.getenv("DATABASE_URL", "")

if (nzchar(database_url)) {
  # Heroku: DATABASE_URL looks like postgres://user:password@host:port/dbname
  parsed <- httr::parse_url(database_url)
  pool <- dbPool(
    drv      = RPostgres::Postgres(),
    dbname   = sub("^/", "", parsed$path),
    host     = parsed$hostname,
    port     = if (is.null(parsed$port)) 5432L else as.integer(parsed$port),
    user     = utils::URLdecode(parsed$username),
    password = utils::URLdecode(parsed$password),
    sslmode  = "require"
  )
} else {
  # Local docker-compose
  pool <- dbPool(
    drv      = RPostgres::Postgres(),
    dbname   = Sys.getenv("DB_NAME", "exposoma"),
    host     = Sys.getenv("DB_HOST", "db"),
    port     = as.integer(Sys.getenv("DB_PORT", "5432")),
    user     = Sys.getenv("DB_USER", "postgres"),
    password = Sys.getenv("DB_PASSWORD", "postgres")
  )
}

onStop(function() {
  poolClose(pool)
})

# Questionnaire heading: short title, full instrument name, and the
# instructions (one string per paragraph) in a shaded box. A paragraph with
# bold words is a tagList, e.g. tagList("en los ", strong("últimos 7 días"), ".")
questionnaire_header <- function(title, subtitle = NULL, ...) {
  paragraph <- function(x) {
    # Keep strong()/em() pieces glued to the surrounding text; otherwise the
    # HTML line breaks show up as extra spaces, e.g. "días ."
    if (inherits(x, "shiny.tag.list")) {
      x[] <- lapply(x, function(ch) {
        if (inherits(ch, "shiny.tag")) ch$.noWS <- "outside"
        ch
      })
    }
    shiny::p(x)
  }
  shiny::tagList(
    shiny::h3(title),
    if (!is.null(subtitle)) shiny::p(shiny::strong(subtitle)),
    shiny::div(class = "well well-sm", lapply(list(...), paragraph))
  )
}
