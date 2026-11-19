-- Builds the view v_matriz: ONE ROW PER PARTICIPANT with every questionnaire
-- side by side. The column list is generated from the database itself, so new
-- questions/foods appear automatically the next time this file is run.
-- Names are not included (participant_identity is deliberately left out).

DROP VIEW IF EXISTS v_matriz;

WITH tablas(ord, tbl, prefijo) AS (
  VALUES (1, 'questionnaire_ipaq',  'ipaq'),
         (2, 'questionnaire_posit', 'posit'),
         (3, 'questionnaire_psqi',  'psqi'),
         (4, 'questionnaire_amai',  'amai'),
         (5, 'questionnaire_pss',   'pss'),
         (6, 'questionnaire_pnc',   'pnc')
),
columnas_cuestionarios AS (
  SELECT string_agg(format(', %I.%I AS %I', t.prefijo, c.column_name, t.prefijo || '_' || c.column_name),
                    '' ORDER BY t.ord, c.ordinal_position) AS sql
  FROM tablas t
  JOIN information_schema.columns c
    ON c.table_schema = 'public' AND c.table_name = t.tbl
  WHERE c.column_name NOT IN ('response_id', 'subject_id', 'submitted_at', 'collected_by')
),
joins_cuestionarios AS (
  -- latest saved response per participant, in case one was saved twice
  SELECT string_agg(format(
    ' LEFT JOIN (SELECT DISTINCT ON (subject_id) * FROM %I ORDER BY subject_id, submitted_at DESC NULLS LAST) %I ON %I.subject_id = p.subject_id',
    t.tbl, t.prefijo, t.prefijo), '' ORDER BY t.ord) AS sql
  FROM tablas t
),
cfca_campos(ord, col, sufijo) AS (
  VALUES (1, 'days_per_week', 'dias'), (2, 'times_per_day', 'veces'),
         (3, 'portion_size', 'tamano'), (4, 'num_portions', 'n')
),
cfca AS (
  SELECT
    string_agg(format(', cfca.%I', 'cfca_' || lpad(f.food_item_id::text, 3, '0') || '_' || k.sufijo),
               '' ORDER BY f.food_item_id, k.ord) AS sql_outer,
    string_agg(format(', max(CASE WHEN food_item_id = %s THEN %I END) AS %I',
               f.food_item_id, k.col, 'cfca_' || lpad(f.food_item_id::text, 3, '0') || '_' || k.sufijo),
               '' ORDER BY f.food_item_id, k.ord) AS sql_inner
  FROM food_items f CROSS JOIN cfca_campos k
)
SELECT
  'CREATE VIEW v_matriz AS SELECT p.subject_id, p.age, p.sex, p.school, '
  || 'p.created_at AS registro_fecha, p.collected_by AS registro_por'
  || cq.sql
  || cf.sql_outer
  || ' FROM participants p'
  || jq.sql
  || ' LEFT JOIN (SELECT subject_id' || cf.sql_inner
  || ' FROM cfca_responses GROUP BY subject_id) cfca ON cfca.subject_id = p.subject_id'
FROM columnas_cuestionarios cq, joins_cuestionarios jq, cfca cf
\gexec
