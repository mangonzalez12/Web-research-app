# Exposoma-Adolescentes: data-capture platform

Web platform used by the research team to capture questionnaire data from adolescents in León de los Aldama, Guanajuato (Mexico), for the project *Análisis del Exposoma Externo y su Asociación con Indicadores de Riesgo para Enfermedad Hepática Esteatósica Asociada a Disfunción Metabólica en Adolescentes con Sobrepeso y/o Obesidad*.

*Plataforma de captura de datos para el equipo de investigación: formularios en R Shiny, base de datos PostgreSQL, despliegue con Docker y Heroku. Interfaz en español.*

> **This repository contains no participant data.** Screenshots and sample files use simulated or fictitious data only.

## Screenshots
<img width="659" height="703" alt="Team login" src="https://github.com/user-attachments/assets/585e7e64-b1e5-4f56-97e6-1cb1d8996684" />
<img width="930" height="579" alt="Registration and search" src="https://github.com/user-attachments/assets/073b79c9-91eb-4147-bf4c-22fd540b9542" />
<img width="1404" height="641" alt="CFCA form" src="https://github.com/user-attachments/assets/04a6d70b-d3cb-48bb-bb6a-697b3fce5b77" />


## What it does

- **Seven questionnaires:** IPAQ, POSIT, PSQI, AMAI 2022, PSS, PNC and CFCA (161 foods with cooking methods).
- **Team access:** individual logins; every saved row records who collected it (`collected_by`).
- **Participant registration:** names are stored in a separate table (`participant_identity`) from the answers, which are keyed by a random `subject_id`.
- **Personal links / QR codes:** a participant answers on their own phone, without a login, using a link tied to one participant, a chosen subset of questionnaires and an expiry time. The team can search a participant by name and issue a new link later for the questionnaires still missing.
- **Records and downloads:** a table of who has answered what, and CSV downloads (including a combined one-row-per-participant file). Both require the user's password again, and downloads never include names.

## Stack
PostgreSQL · SQLAlchemy 2 (schema) · R Shiny (modules, `pool`, `shinymanager`, `shinyjs`) · Docker / docker-compose · Heroku (container stack).
