SET search_path TO dw, source_oltp, public;

-- ETL step: 6 of 6
-- Depends on: 05_load_fact_claim.sql (fact_claim must exist for claim_key lookup)
-- Layer: warehouse ETL

INSERT INTO dw.fact_claim_line (
    claim_key, claim_id, claim_line_number, date_key, procedure_key, diagnosis_key,
    service_date, place_of_service, units, billed_amount, allowed_amount,
    paid_amount, member_amount
)
SELECT
    fc.claim_key,
    cl.claim_id,
    cl.line_number,
    TO_CHAR(cl.service_date, 'YYYYMMDD')::INT AS date_key,
    COALESCE(dpr.procedure_key, -1),
    COALESCE(dd.diagnosis_key, -1),
    cl.service_date,
    cl.place_of_service,
    cl.units,
    cl.billed_amount,
    cl.allowed_amount,
    cl.paid_amount,
    cl.member_amount
FROM source_oltp.claim_lines cl
JOIN dw.fact_claim fc ON cl.claim_id = fc.claim_id
LEFT JOIN dw.dim_procedure dpr ON cl.procedure_code = dpr.procedure_code
LEFT JOIN dw.dim_diagnosis dd ON cl.diagnosis_code = dd.diagnosis_code
WHERE NOT EXISTS (
    SELECT 1 FROM dw.fact_claim_line fcl 
    WHERE fcl.claim_id = cl.claim_id AND fcl.claim_line_number = cl.line_number
);


-- Testing purposes
-- SET search_path TO dw, source_oltp, public;

-- SELECT * FROM source_oltp.claim_lines
-- SELECT * FROM dw.fact_claim_line