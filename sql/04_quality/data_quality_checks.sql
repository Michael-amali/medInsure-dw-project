SET search_path TO dw, public;

-- MedInsure Data Quality Report
-- Runs 7 checks against the loaded warehouse. PASS threshold: 99% pass rate.
--
-- Checks:
--   1. fact_claim_fk_valid          - Every claim has valid date_key, member_key, provider_key
--   2. fact_claim_paid_vs_allowed   - No paid claims where total_paid > total_allowed * 1.05
--   3. dim_member_scd2_integrity    - No member has more than one is_current = TRUE row
--   4. dim_provider_scd2_integrity  - No provider has more than one is_current = TRUE row
--   5. fact_line_claim_fk           - Every claim_id in fact_claim_line exists in fact_claim
--   6. orphan_procedure_codes       - Claim lines with procedure codes not in dim_procedure
--   7. provider_anachronistic_claims  - Claims where service_date < provider.effective_start

WITH dq_checks AS (
    -- 1. fact_claim: Every claim has valid FKs
    SELECT 
        'fact_claim_fk_valid' AS check_name,
        COUNT(*) AS total_rows,
        SUM(CASE WHEN date_key > 0 AND member_key > 0 AND provider_key > 0 THEN 1 ELSE 0 END) AS passed,
        SUM(CASE WHEN date_key <= 0 OR member_key <= 0 OR provider_key <= 0 THEN 1 ELSE 0 END) AS failed
    FROM fact_claim

    UNION ALL

    -- 2. fact_claim: No claims where total_paid > total_allowed * 1.05
    SELECT 
        'fact_claim_paid_vs_allowed',
        COUNT(*),
        SUM(CASE WHEN total_paid <= total_allowed * 1.05 THEN 1 ELSE 0 END),
        SUM(CASE WHEN total_paid > total_allowed * 1.05 THEN 1 ELSE 0 END)
    FROM fact_claim
    WHERE claim_status = 'Paid'

    UNION ALL

    -- 3. dim_member: No member has >1 is_current = TRUE row
    SELECT 
        'dim_member_scd2_integrity',
        COUNT(DISTINCT member_id),
        COUNT(DISTINCT member_id) FILTER (WHERE cnt = 1),
        COUNT(DISTINCT member_id) FILTER (WHERE cnt > 1)
    FROM (
        SELECT member_id, COUNT(*) AS cnt 
        FROM dim_member 
        WHERE is_current = TRUE 
        GROUP BY member_id
    ) t

    UNION ALL

    -- 4. dim_provider: No provider has >1 is_current = TRUE row
    SELECT 
        'dim_provider_scd2_integrity',
        COUNT(DISTINCT provider_id),
        COUNT(DISTINCT provider_id) FILTER (WHERE cnt = 1),
        COUNT(DISTINCT provider_id) FILTER (WHERE cnt > 1)
    FROM (
        SELECT provider_id, COUNT(*) AS cnt 
        FROM dim_provider 
        WHERE is_current = TRUE 
        GROUP BY provider_id
    ) t

    UNION ALL

    -- 5. Referential integrity: Every claim_id in fact_claim_line exists in fact_claim
    SELECT 
        'fact_line_claim_fk',
        COUNT(*),
        SUM(CASE WHEN fc.claim_key IS NOT NULL THEN 1 ELSE 0 END),
        SUM(CASE WHEN fc.claim_key IS NULL THEN 1 ELSE 0 END)
    FROM fact_claim_line fcl
    LEFT JOIN fact_claim fc ON fcl.claim_key = fc.claim_key

    UNION ALL

    -- 6. Orphaned procedure codes: claim lines with procedure not in dim_procedure
    SELECT 
        'orphan_procedure_codes',
        COUNT(*),
        SUM(CASE WHEN dp.procedure_key != -1 THEN 1 ELSE 0 END),
        SUM(CASE WHEN dp.procedure_key = -1 THEN 1 ELSE 0 END)
    FROM fact_claim_line fcl
    JOIN dim_procedure dp ON fcl.procedure_key = dp.procedure_key

    UNION ALL

    -- 7. Providers with anachronistic claims: service_date < provider.effective_start
    SELECT 
        'provider_anachronistic_claims',
        COUNT(*),
        SUM(CASE WHEN fc.service_date >= dp.effective_start THEN 1 ELSE 0 END),
        SUM(CASE WHEN fc.service_date < dp.effective_start THEN 1 ELSE 0 END)
    FROM fact_claim fc
    JOIN dim_provider dp ON fc.provider_key = dp.provider_key
)
SELECT 
    check_name,
    total_rows AS total_rows_evaluated,
    passed,
    failed,
    ROUND(passed * 100.0 / NULLIF(total_rows, 0), 2) AS pass_rate_pct,
    CASE 
        WHEN passed * 100.0 / NULLIF(total_rows, 0) >= 99.0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM dq_checks
ORDER BY check_name;


-- Supplemental: DLQ error summary (last 7 days)
SELECT 
    error_type,
    COUNT(*) AS error_count,
    MIN(created_at) AS first_occurrence,
    MAX(created_at) AS last_occurrence
FROM dw.dlq_claim_load
WHERE created_at >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY error_type
ORDER BY error_count DESC;
