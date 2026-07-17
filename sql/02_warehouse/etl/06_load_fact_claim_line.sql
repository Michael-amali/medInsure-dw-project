SET search_path TO dw, source_oltp, public;

-- ETL step: 6 of 6
-- Depends on: 05_load_fact_claim.sql (fact_claim must exist for claim_key lookup)
-- Layer: warehouse ETL

DO $$
DECLARE
    v_hwm DATE;
    v_rows_loaded INT;
BEGIN
    SELECT COALESCE(MAX(etl_loaded_at::DATE), '1970-01-01') INTO v_hwm 
    FROM dw.fact_claim_line;

    -- Stage claim lines with lookups
    CREATE TEMP TABLE stg_fact_claim_line AS
    SELECT 
        fc.claim_key,
        cl.claim_id,
        cl.line_number AS claim_line_number,
        TO_CHAR(cl.service_date, 'YYYYMMDD')::INT AS date_key,
        dpr.procedure_key,
        dd.diagnosis_key,
        cl.service_date,
        cl.place_of_service,
        cl.units,
        cl.billed_amount,
        cl.allowed_amount,
        cl.paid_amount,
        cl.member_amount,
        CASE 
            WHEN fc.claim_key IS NULL THEN 'MISSING_CLAIM'
            ELSE NULL
        END AS error_type
    FROM source_oltp.claim_lines cl
    -- Need claim header to get processed_date for HWM and claim_key
    JOIN source_oltp.claims c ON cl.claim_id = c.claim_id
    LEFT JOIN dw.fact_claim fc ON cl.claim_id = fc.claim_id
    LEFT JOIN dw.dim_procedure dpr ON cl.procedure_code = dpr.procedure_code
    LEFT JOIN dw.dim_diagnosis dd ON cl.diagnosis_code = dd.diagnosis_code
    WHERE c.processed_date > v_hwm
    AND NOT EXISTS (
        SELECT 1 FROM dw.fact_claim_line fcl 
        WHERE fcl.claim_id = cl.claim_id 
        AND fcl.claim_line_number = cl.line_number
    );

    -- Write errors to DLQ, don't fail pipeline
    INSERT INTO dw.dlq_claim_load (claim_id, error_type, error_detail, source_payload)
    SELECT 
        claim_id,
        error_type,
        'Claim line missing fact_claim parent key - claim header not loaded yet',
        to_jsonb(stg_fact_claim_line.*)
    FROM stg_fact_claim_line
    WHERE error_type IS NOT NULL;

    -- Insert good rows
    INSERT INTO dw.fact_claim_line (
        claim_key, claim_id, claim_line_number, date_key, procedure_key, diagnosis_key,
        service_date, place_of_service, units, billed_amount, allowed_amount,
        paid_amount, member_amount
    )
    SELECT 
        claim_key,
        claim_id,
        claim_line_number,
        date_key,
        COALESCE(procedure_key, -1),  -- FK to 'Not Applicable'
        COALESCE(diagnosis_key, -1),
        service_date,
        place_of_service,
        units,
        billed_amount,
        allowed_amount,
        paid_amount,
        member_amount
    FROM stg_fact_claim_line
    WHERE error_type IS NULL;

    GET DIAGNOSTICS v_rows_loaded = ROW_COUNT;
    RAISE NOTICE 'fact_claim_line: loaded % rows, HWM was %', v_rows_loaded, v_hwm;
    
    DROP TABLE stg_fact_claim_line;
END $$;

-- Testing purposes
-- SET search_path TO dw, source_oltp, public;
-- SELECT * FROM source_oltp.claim_lines
-- SELECT * FROM dw.fact_claim_line
-- SELECT * FROM dw.dlq_claim_load WHERE error_type = 'MISSING_CLAIM'