SET search_path TO dw, source_oltp, public;

-- ETL step: 5 of 6
-- Depends on: 01_load_dim_date.sql, 03_load_dim_member_scd2.sql, 04_load_dim_provider_scd2.sql
-- Layer: warehouse ETL

DO $$
DECLARE
    v_hwm DATE;
    v_rows_loaded INT;
BEGIN
    SELECT COALESCE(MAX(etl_loaded_at::DATE), '1970-01-01') INTO v_hwm 
    FROM dw.fact_claim;

    -- Stage claims with lookups
    CREATE TEMP TABLE stg_fact_claim AS
    SELECT 
        c.claim_id,
        TO_CHAR(c.service_date, 'YYYYMMDD')::INT AS date_key,
        dm.member_key,
        dp.provider_key,
        c.service_date,
        c.processed_date,
        c.claim_type,
        c.claim_status,
        c.denial_reason,
        c.total_billed,
        c.total_allowed,
        c.total_paid,
        c.member_liability,
        c.line_count,
        CASE 
            WHEN dm.member_key IS NULL THEN 'MISSING_MEMBER'
            WHEN dp.provider_key IS NULL THEN 'MISSING_PROVIDER'
            ELSE NULL
        END AS error_type
    FROM source_oltp.claims c
    -- SCD2 join: member version active on service_date
    LEFT JOIN dw.dim_member dm 
        ON c.member_id = dm.member_id 
        AND c.service_date BETWEEN dm.effective_start AND dm.effective_end
    -- SCD2 join: provider version active on service_date
    LEFT JOIN dw.dim_provider dp 
        ON c.provider_id = dp.provider_id 
        AND c.service_date BETWEEN dp.effective_start AND dp.effective_end
    WHERE c.processed_date > v_hwm;

    -- Write errors to DLQ, don't fail pipeline
    INSERT INTO dw.dlq_claim_load (claim_id, error_type, error_detail, source_payload)
    SELECT 
        claim_id,
        error_type,
        'Claim header missing dimension key',
        to_jsonb(stg_fact_claim.*)
    FROM stg_fact_claim
    WHERE error_type IS NOT NULL;

    -- Insert good rows
    INSERT INTO dw.fact_claim (
        claim_id, date_key, member_key, provider_key, service_date, processed_date,
        claim_type, claim_status, denial_reason, total_billed, total_allowed,
        total_paid, member_liability, line_count
    )
    SELECT 
        claim_id,
        date_key,
        COALESCE(member_key, -1),      -- FK to 'Not Applicable'
        COALESCE(provider_key, -1),
        service_date,
        processed_date,
        claim_type,
        claim_status,
        denial_reason,
        total_billed,
        total_allowed,
        total_paid,
        member_liability,
        line_count
    FROM stg_fact_claim
    WHERE error_type IS NULL;

    GET DIAGNOSTICS v_rows_loaded = ROW_COUNT;
    RAISE NOTICE 'fact_claim: loaded % rows', v_rows_loaded;
    
    DROP TABLE stg_fact_claim;
END $$;


-- Testing purposes
-- SET search_path TO dw, source_oltp, public;

-- SELECT * FROM source_oltp.claims
-- SELECT * FROM dw.fact_claim
-- SELECT * FROM dw.dlq_claim_load