SET search_path TO dw, source_oltp, public;

-- ETL step: 4 of 6
-- Depends on: oltp_seed_data.sql
-- Layer: warehouse ETL

CREATE TEMP TABLE stg_provider AS
WITH latest_network AS (
    SELECT DISTINCT ON (provider_id)
        provider_id,
        network_status,
        effective_date
    FROM source_oltp.provider_network_history
    ORDER BY provider_id, effective_date DESC
)
SELECT 
    p.provider_id,
    p.provider_name,
    p.provider_type,
    p.specialty,
    COALESCE(ln.network_status, 'Out-of-Network') AS network_status,
    p.state,
    p.zip_code,
    GREATEST(p.updated_at, ln.effective_date) AS source_updated_at,
    ln.effective_date AS business_effective_date
FROM source_oltp.providers p
LEFT JOIN latest_network ln ON p.provider_id = ln.provider_id;

-- Close changed rows
UPDATE dw.dim_provider dp
SET 
    effective_end = stg.business_effective_date - INTERVAL '1 day',
    is_current = FALSE
FROM stg_provider stg
WHERE dp.provider_id = stg.provider_id
  AND dp.is_current = TRUE
  AND (
      dp.network_status IS DISTINCT FROM stg.network_status
      OR dp.specialty IS DISTINCT FROM stg.specialty
  );

-- Insert new versions
INSERT INTO dw.dim_provider (
    provider_id, provider_name, provider_type, specialty, network_status,
    state, zip_code, effective_start, effective_end, is_current, source_updated_at
)
SELECT 
    stg.provider_id,
    stg.provider_name,
    stg.provider_type,
    stg.specialty,
    stg.network_status,
    stg.state,
    stg.zip_code,
    COALESCE(stg.business_effective_date, CURRENT_DATE) AS effective_start,
    '9999-12-31'::DATE,
    TRUE,
    stg.source_updated_at
FROM stg_provider stg
LEFT JOIN dw.dim_provider dp 
    ON stg.provider_id = dp.provider_id AND dp.is_current = TRUE
WHERE dp.provider_key IS NULL
   OR dp.network_status IS DISTINCT FROM stg.network_status
   OR dp.specialty IS DISTINCT FROM stg.specialty;

DROP TABLE stg_provider;

-- Verification: no provider has >1 current row
DO $$
BEGIN
    IF EXISTS (
        SELECT provider_id FROM dw.dim_provider 
        WHERE is_current = TRUE 
        GROUP BY provider_id HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION 'SCD2 violation: provider has multiple current rows';
    END IF;
END $$;
