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

```
app/        R Shiny app (app.R, global.R, R/ modules, Dockerfile)
database/   SQLAlchemy models, food catalogue seed, role setup, Dockerfile
analysis/   export_data.py, simulate_data.py, graphs.R
docs/       screenshots
heroku.yml  build, release (seed) and run definition for Heroku
matriz.sql  analysis matrix query
```

## Run locally

Requires Docker.

```bash
cp .env.example .env        # then edit .env and set a password for every user
docker-compose up --build
```

Open http://localhost:3838 and sign in with one of the users listed in `APP_USERS`.
The compose file uses throw-away development database passwords; do not reuse them anywhere real.

## Deploy to Heroku

```bash
heroku create <app-name> --stack container
heroku addons:create heroku-postgresql:essential-0
heroku config:set APP_USERS=user1,user2 APP_PASS_USER1=... APP_PASS_USER2=...   # one password per user
heroku config:set PUBLIC_URL=https://<app-name>-<id>.herokuapp.com/
git push heroku main
```

The release phase in `heroku.yml` creates the tables and seeds the food catalogue. The app reads `DATABASE_URL` on Heroku and falls back to the local compose database otherwise.

## Privacy and security notes

- Only a SHA-256 hash of each participant link token is stored; the link itself is shown once.
- Links expire, can be revoked, and only open the questionnaires chosen for that participant. A saved questionnaire cannot be answered twice.
- Passwords come from environment variables; the app refuses to start if one is missing.
- Do not commit `.env`, exports or any real data (see `.gitignore`).

## Analysis with fictitious data

```bash
cd analysis
pip install -r requirements.txt
python simulate_data.py          # writes simulated/exposoma_combinado_simulado.csv
python export_data.py            # exports from a real database (needs DATABASE_URL), kept out of git
```

## License

No license has been chosen yet; until one is added, all rights are reserved.
