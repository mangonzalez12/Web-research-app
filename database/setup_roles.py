import os

from sqlalchemy import create_engine, text

DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "postgres")
DB_HOST = os.getenv("DB_HOST", "db")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "exposoma")

SHINY_WRITER_PASSWORD = os.getenv("SHINY_WRITER_PASSWORD", "changeme_writer")
ANALYST_READER_PASSWORD = os.getenv("ANALYST_READER_PASSWORD", "changeme_reader")

DATABASE_URL = f"postgresql+psycopg2://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

# Tables the app writes to and analysts read from (excludes participant_identity)
QUESTIONNAIRE_TABLES = [
    "participants",
    "questionnaire_ipaq",
    "questionnaire_posit",
    "questionnaire_psqi",
    "questionnaire_amai",
    "questionnaire_pss",
    "questionnaire_pnc",
    "cfca_responses",
    "food_items",
    "participant_links",
    "cfca_category_progress",
    "food_cooking_methods",
    "cfca_cooking_responses",
]

STATEMENTS = [
    f"""
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'shiny_writer') THEN
        CREATE ROLE shiny_writer LOGIN PASSWORD '{SHINY_WRITER_PASSWORD}';
      END IF;
    END $$;
    """,
    f"""
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'analyst_reader') THEN
        CREATE ROLE analyst_reader LOGIN PASSWORD '{ANALYST_READER_PASSWORD}';
      END IF;
    END $$;
    """,
]

for tbl in QUESTIONNAIRE_TABLES:
    STATEMENTS.append(f"GRANT SELECT, INSERT ON {tbl} TO shiny_writer;")
    STATEMENTS.append(f"GRANT SELECT ON {tbl} TO analyst_reader;")

# shiny_writer also needs UPDATE on the sequence-like id columns for food_items (SERIAL)
STATEMENTS.append("GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO shiny_writer;")

# participant_identity: only shiny_writer gets access - analyst_reader is deliberately excluded
STATEMENTS.append("GRANT SELECT, INSERT ON participant_identity TO shiny_writer;")
STATEMENTS.append("GRANT UPDATE (revoked_at) ON participant_links TO shiny_writer;")

if __name__ == "__main__":
    engine = create_engine(DATABASE_URL)
    with engine.begin() as conn:
        for stmt in STATEMENTS:
            conn.execute(text(stmt))
    print("Roles and grants applied.")
