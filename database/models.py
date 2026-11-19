import uuid
from datetime import datetime

from sqlalchemy import Column, Integer, SmallInteger, String, Boolean, DateTime, Time, Numeric, ForeignKey, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import declarative_base

Base = declarative_base()


class Participant(Base):
    __tablename__ = "participants"

    subject_id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    created_at = Column(DateTime(timezone=True), server_default=text("now()"))
    collected_by = Column(String)
    age = Column(Integer)
    sex = Column(String)
    school = Column(String)
    # name removed - lives in ParticipantIdentity instead


class ParticipantIdentity(Base):
    __tablename__ = "participant_identity"

    subject_id = Column(UUID(as_uuid=True), ForeignKey("participants.subject_id"), primary_key=True)
    name = Column(String)


class QuestionnaireIPAQ(Base):
    __tablename__ = "questionnaire_ipaq"

    response_id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    subject_id = Column(UUID(as_uuid=True), ForeignKey("participants.subject_id"), nullable=False)
    submitted_at = Column(DateTime(timezone=True), server_default=text("now()"))
    collected_by = Column(String)

    vigorous_days = Column(SmallInteger)
    vigorous_hours = Column(SmallInteger)
    vigorous_minutes = Column(SmallInteger)
    vigorous_dont_know = Column(Boolean, default=False)

    moderate_days = Column(SmallInteger)
    moderate_hours = Column(SmallInteger)
    moderate_minutes = Column(SmallInteger)
    moderate_dont_know = Column(Boolean, default=False)

    walking_days = Column(SmallInteger)
    walking_hours = Column(SmallInteger)
    walking_minutes = Column(SmallInteger)
    walking_dont_know = Column(Boolean, default=False)

    sitting_hours = Column(SmallInteger)
    sitting_minutes = Column(SmallInteger)
    sitting_dont_know = Column(Boolean, default=False)

class QuestionnairePOSIT(Base):
    __tablename__ = "questionnaire_posit"

    response_id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    subject_id = Column(UUID(as_uuid=True), ForeignKey("participants.subject_id"), nullable=False)
    submitted_at = Column(DateTime(timezone=True), server_default=text("now()"))
    collected_by = Column(String)

    question1 = Column(Boolean, default=False)
    question2 = Column(Boolean, default=False)
    question3 = Column(Boolean, default=False)
    question4 = Column(Boolean, default=False)
    question5 = Column(Boolean, default=False)
    question6 = Column(Boolean, default=False)
    question7 = Column(Boolean, default=False)
    question8 = Column(Boolean, default=False)
    question9 = Column(Boolean, default=False)
    question10 = Column(Boolean, default=False)
    question11 = Column(Boolean, default=False)
    question12 = Column(Boolean, default=False)
    question13 = Column(Boolean, default=False)
    question14 = Column(Boolean, default=False)
    question15 = Column(Boolean, default=False)
    question16 = Column(Boolean, default=False)
    question17 = Column(Boolean, default=False)

class QuestionnairePSQI(Base):
    __tablename__ = "questionnaire_psqi"

    response_id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    subject_id = Column(UUID(as_uuid=True), ForeignKey("participants.subject_id"), nullable=False)
    submitted_at = Column(DateTime(timezone=True), server_default=text("now()"))
    collected_by = Column(String)

    # Q1-Q4
    bedtime = Column(Time)
    sleep_latency_minutes = Column(Integer)
    wake_time = Column(Time)
    sleep_hours = Column(Numeric(4, 2))

    # Q5a-i: frequency scale 0-3 (0=ninguna vez, 1=<1/sem, 2=1-2/sem, 3=3+/sem)
    q5a_no_sleep_30min = Column(SmallInteger)
    q5b_wake_night = Column(SmallInteger)
    q5c_bathroom = Column(SmallInteger)
    q5d_breathing = Column(SmallInteger)
    q5e_cough_snore = Column(SmallInteger)
    q5f_cold = Column(SmallInteger)
    q5g_hot = Column(SmallInteger)
    q5h_nightmares = Column(SmallInteger)
    q5i_pain = Column(SmallInteger)

    # Q5j: other reason - free text + same frequency scale
    q5j_other_text = Column(String)
    q5j_other_freq = Column(SmallInteger)

    # Q6: overall sleep quality, 0=bastante buena ... 3=bastante mala
    sleep_quality = Column(SmallInteger)

    # Q7: sleep medication frequency (same 0-3 scale as Q5)
    sleep_medication_freq = Column(SmallInteger)

    # Q8: daytime dysfunction frequency (same 0-3 scale as Q5)
    daytime_dysfunction_freq = Column(SmallInteger)

    # Q9: problem with enthusiasm, 0=ningun problema ... 3=un gran problema
    enthusiasm_problem = Column(SmallInteger)


class QuestionnairePNC(Base):
    __tablename__ = "questionnaire_pnc"

    response_id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    subject_id = Column(UUID(as_uuid=True), ForeignKey("participants.subject_id"), nullable=False)
    submitted_at = Column(DateTime(timezone=True), server_default=text("now()"))
    collected_by = Column(String)

    question1 = Column(Boolean, default=False)
    question2 = Column(Boolean, default=False)
    question3 = Column(Boolean, default=False)
    question4 = Column(Boolean, default=False)
    question5 = Column(Boolean, default=False)

class QuestionnaireAMAI(Base):
    __tablename__ = "questionnaire_amai"

    response_id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    subject_id = Column(UUID(as_uuid=True), ForeignKey("participants.subject_id"), nullable=False)
    submitted_at = Column(DateTime(timezone=True), server_default=text("now()"))
    collected_by = Column(String)

    # Q1: último año de estudios del jefe/jefa de hogar (0=No estudios ... 12=Doctorado)
    household_head_education = Column(SmallInteger)

    # Q2: baños completos (0, 1, 2=2 o más)
    bathrooms = Column(SmallInteger)

    # Q3: automóviles/camionetas (0, 1, 2=2 o más)
    cars = Column(SmallInteger)

    # Q4: conexión a internet en el hogar
    has_internet = Column(Boolean)

    # Q5: personas de 14+ que trabajaron el último mes (0,1,2,3,4=4 o más)
    workers_14plus = Column(SmallInteger)

    # Q6: cuartos usados para dormir (0,1,2,3,4=4 o más)
    bedrooms = Column(SmallInteger)


class QuestionnairePSS(Base):
    __tablename__ = "questionnaire_pss"

    response_id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    subject_id = Column(UUID(as_uuid=True), ForeignKey("participants.subject_id"), nullable=False)
    submitted_at = Column(DateTime(timezone=True), server_default=text("now()"))
    collected_by = Column(String)

    # Each item stores the RAW selected option (0=Nunca ... 4=Muy frecuente),
    # in the same direction for every item. Items 5, 6, 7, 9, 13 are
    # reverse-scored in the official PSS scoring - apply that in analysis,
    # not here.
    q1 = Column(SmallInteger)
    q2 = Column(SmallInteger)
    q3 = Column(SmallInteger)
    q4 = Column(SmallInteger)
    q5 = Column(SmallInteger)
    q6 = Column(SmallInteger)
    q7 = Column(SmallInteger)
    q8 = Column(SmallInteger)
    q9 = Column(SmallInteger)
    q10 = Column(SmallInteger)
    q11 = Column(SmallInteger)
    q12 = Column(SmallInteger)
    q13 = Column(SmallInteger)
    q14 = Column(SmallInteger)

class FoodItem(Base):
    __tablename__ = "food_items"

    food_item_id = Column(Integer, primary_key=True, autoincrement=True)
    category = Column(String, nullable=False)
    name = Column(String, nullable=False)
    portion_description = Column(String)


class CFCAResponse(Base):
    __tablename__ = "cfca_responses"

    response_id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    subject_id = Column(UUID(as_uuid=True), ForeignKey("participants.subject_id"), nullable=False)
    food_item_id = Column(Integer, ForeignKey("food_items.food_item_id"), nullable=False)
    submitted_at = Column(DateTime(timezone=True), server_default=text("now()"))
    collected_by = Column(String)

    days_per_week = Column(SmallInteger)   # 0-7
    times_per_day = Column(SmallInteger)   # 1-6
    # Portion size relative to the reference portion shown on the form:
    # 1 = menor, 2 = igual, 3 = mayor  (adjust if your printed instrument differs)
    portion_size = Column(SmallInteger)
    num_portions = Column(Numeric(4, 2))


class FoodCookingMethod(Base):
    __tablename__ = "food_cooking_methods"

    cooking_method_id = Column(Integer, primary_key=True, autoincrement=True)
    food_item_id = Column(Integer, ForeignKey("food_items.food_item_id"), nullable=False)
    name = Column(String, nullable=False)


class CFCACookingResponse(Base):
    """Portions eaten for one food prepared one way (child of a cfca_responses row)."""
    __tablename__ = "cfca_cooking_responses"

    cooking_response_id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    cfca_response_id = Column(UUID(as_uuid=True), ForeignKey("cfca_responses.response_id"), nullable=False)
    cooking_method_id = Column(Integer, ForeignKey("food_cooking_methods.cooking_method_id"), nullable=False)
    portions = Column(Numeric(4, 2))


class ParticipantLink(Base):
    """Personal link that lets ONE participant answer their questionnaires without logging in."""
    __tablename__ = "participant_links"

    link_id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    subject_id = Column(UUID(as_uuid=True), ForeignKey("participants.subject_id"), nullable=False)
    token_hash = Column(String, nullable=False, unique=True)   # SHA-256 of the token; the token itself is never stored
    questionnaires = Column(String, nullable=False)            # e.g. "ipaq,posit,pss"
    created_at = Column(DateTime(timezone=True), server_default=text("now()"))
    created_by = Column(String)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    revoked_at = Column(DateTime(timezone=True))


class CFCACategoryProgress(Base):
    """CFCA food categories already saved for a participant (a saved category cannot be answered twice)."""
    __tablename__ = "cfca_category_progress"

    subject_id = Column(UUID(as_uuid=True), ForeignKey("participants.subject_id"), primary_key=True)
    category = Column(String, primary_key=True)
    saved_at = Column(DateTime(timezone=True), server_default=text("now()"))
    collected_by = Column(String)
