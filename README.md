# Exposoma-Adolescentes: data-capture platform

Web platform used by the research team to capture questionnaire data from adolescents in León de los Aldama, Guanajuato (Mexico), for the project *Análisis del Exposoma Externo y su Asociación con Indicadores de Riesgo para Enfermedad Hepática Esteatósica Asociada a Disfunción Metabólica en Adolescentes con Sobrepeso y/o Obesidad*.

*Plataforma de captura de datos para el equipo de investigación: formularios en R Shiny, base de datos PostgreSQL, despliegue con Docker y Heroku. Interfaz en español.*

> **This repository contains no participant data.** Screenshots and sample files use simulated or fictitious data only.

## Screenshots

| | |
|---|---|
| ![Team login](docs/screenshots/Team login) <br> **Team login** | ![Registration and search](docs/screenshots/02-registro-buscar.png) <br> **Registration and search by name** |
| ![Personal link and QR](docs/screenshots/03-enlace-qr.png) <br> **Personal link and QR code** | ![Participant on a phone](docs/screenshots/04-participante-movil.png) <br> **Participant answering on a phone** |
| ![CFCA form](docs/screenshots/05-cfca.png) <br> **Food frequency questionnaire (CFCA)** | ![Saved records](docs/screenshots/06-registros.png) <br> **Saved records (password-protected)** |

## What it does

- **Seven questionnaires:** IPAQ, POSIT, PSQI, AMAI 2022, PSS, PNC and CFCA (161 foods with cooking methods).
- **Team access:** individual logins; every saved row records who collected it (`collected_by`).
- **Participant registration:** names are stored in a separate table (`participant_identity`) from the answers, which are keyed by a random `subject_id`.
- **Personal links / QR codes:** a participant answers on their own phone, without a login, using a link tied to one participant, a chosen subset of questionnaires and an expiry time. The team can search a participant by name and issue a new link later for the questionnaires still missing.
- **Records and downloads:** a table of who has answered what, and CSV downloads (including a combined one-row-per-participant file). Both require the user's password again, and downloads never include names.

## Stack
PostgreSQL · SQLAlchemy 2 (schema) · R Shiny (modules, `pool`, `shinymanager`, `shinyjs`) · Docker / docker-compose · Heroku (container stack).
## Run locally
## Deploy to Heroku
The release phase in `heroku.yml` creates the tables and seeds the food catalogue. The app reads `DATABASE_URL` on Heroku and falls back to the local compose database otherwise.
