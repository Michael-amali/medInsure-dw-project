SET search_path TO dw, source_oltp, public;

-- ETL step: 3 of 6
-- Depends on: oltp_seed_data.sql, 02_load_dim_reference_type1.sql (recommended)
-- Layer: warehouse ETL

-- 1. Stage current state from OLTP + history
CREATE TEMP TABLE stg_member AS
WITH latest_plan AS (
    SELECT DISTINCT ON (member_id)
        member_id,
        plan_id,
        effective_date AS plan_effective_date
    FROM source_oltp.member_plan_history
    ORDER BY member_id, effective_date DESC
)
SELECT 
    m.member_id,
    m.first_name,
    m.last_name,
    m.date_of_birth,
    m.gender,
    m.state,
    m.zip_code,
    lp.plan_id,
    pt.plan_name,
    pt.plan_type,
    m.enrollment_date,
    GREATEST(m.updated_at, lp.plan_effective_date) AS source_updated_at,
    lp.plan_effective_date AS business_effective_date
FROM source_oltp.members m
LEFT JOIN latest_plan lp ON m.member_id = lp.member_id
LEFT JOIN source_oltp.plan_types pt ON lp.plan_id = pt.plan_id;

-- 2. Close changed rows: set effective_end to day before new effective_start
UPDATE dw.dim_member dm
SET 
    effective_end = stg.business_effective_date - INTERVAL '1 day',
    is_current = FALSE
FROM stg_member stg
WHERE dm.member_id = stg.member_id
  AND dm.is_current = TRUE
  AND (
      dm.plan_id IS DISTINCT FROM stg.plan_id
      OR dm.state IS DISTINCT FROM stg.state
      OR dm.zip_code IS DISTINCT FROM stg.zip_code
  );

-- 3. Insert new versions for changed + new members
INSERT INTO dw.dim_member (
    member_id, first_name, last_name, date_of_birth, gender, state, zip_code,
    plan_id, plan_name, plan_type, enrollment_date,
    effective_start, effective_end, is_current, source_updated_at
)
SELECT 
    stg.member_id,
    stg.first_name,
    stg.last_name,
    stg.date_of_birth,
    stg.gender,
    stg.state,
    stg.zip_code,
    stg.plan_id,
    stg.plan_name,
    stg.plan_type,
    stg.enrollment_date,
    COALESCE(stg.business_effective_date, stg.enrollment_date, CURRENT_DATE) AS effective_start,
    '9999-12-31'::DATE AS effective_end,
    TRUE AS is_current,
    stg.source_updated_at
FROM stg_member stg
LEFT JOIN dw.dim_member dm 
    ON stg.member_id = dm.member_id AND dm.is_current = TRUE
WHERE dm.member_key IS NULL  -- New member
   OR dm.plan_id IS DISTINCT FROM stg.plan_id
   OR dm.state IS DISTINCT FROM stg.state
   OR dm.zip_code IS DISTINCT FROM stg.zip_code;

DROP TABLE stg_member;

-- Verification: no member has >1 current row
DO $$
BEGIN
    IF EXISTS (
        SELECT member_id FROM dw.dim_member 
        WHERE is_current = TRUE 
        GROUP BY member_id HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION 'SCD2 violation: member has multiple current rows';
    END IF;
END $$;
