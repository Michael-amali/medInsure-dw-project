SET search_path TO dw, source_oltp, public;

-- Business Q: Which specialties get denied most? For provider education.
-- Why DW works: claim_status on fact + specialty on dim_provider. OLTP would lock.
SELECT
    dp.specialty,
    fc.claim_type,
    COUNT(*) AS total_claims,
    SUM(CASE WHEN fc.claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,
    ROUND(SUM(CASE WHEN fc.claim_status = 'Denied' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS denial_rate_pct,
    SUM(CASE WHEN fc.claim_status = 'Denied' THEN fc.total_billed ELSE 0 END) AS denied_billed_amount
FROM fact_claim fc
JOIN dim_provider dp ON fc.provider_key = dp.provider_key
JOIN dim_date d ON fc.date_key = d.date_key
WHERE d.year_number = EXTRACT(YEAR FROM CURRENT_DATE)::INT
GROUP BY dp.specialty, fc.claim_type
HAVING COUNT(*) > 100  -- Materiality threshold
ORDER BY denial_rate_pct DESC;
