import os

from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

from models import Base

DATABASE_URL = os.getenv("DATABASE_URL")

if DATABASE_URL:
    # Heroku provides postgres:// - SQLAlchemy 2.x requires postgresql://
    if DATABASE_URL.startswith("postgres://"):
        DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql+psycopg2://", 1)
else:
    # Local docker-compose fallback
    DB_USER = os.getenv("DB_USER", "postgres")
    DB_PASSWORD = os.getenv("DB_PASSWORD", "postgres")
    DB_HOST = os.getenv("DB_HOST", "db")
    DB_PORT = os.getenv("DB_PORT", "5432")
    DB_NAME = os.getenv("DB_NAME", "exposoma")
    DATABASE_URL = f"postgresql+psycopg2://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine)


def init_db():
    Base.metadata.create_all(engine)
    # create_all() never adds columns to existing tables, so sync collected_by here
    with engine.begin() as conn:
        for tbl in Base.metadata.tables.values():
            if "collected_by" in tbl.c:
                conn.execute(text(f'ALTER TABLE "{tbl.name}" ADD COLUMN IF NOT EXISTS collected_by TEXT'))
        # PSS grew from 13 to 14 items
        conn.execute(text('ALTER TABLE questionnaire_pss ADD COLUMN IF NOT EXISTS q14 SMALLINT'))
        for tbl in Base.metadata.tables.values():
            for col in ("created_at", "submitted_at"):
                if col in tbl.c:
                    conn.execute(text(f'ALTER TABLE "{tbl.name}" ALTER COLUMN {col} SET DEFAULT now()'))


if __name__ == "__main__":
    init_db()
    print("Tables created (or already existed).")
