SET search_path TO dw, source_oltp, public;

-- Business Q: How much more do we pay when members go out-of-network?
-- Why DW works: dim_provider SCD2 has network_status at service_date. OLTP only has current.
SELECT
    d.year_number,
    dp.network_status,
    COUNT(DISTINCT dm.member_id) AS unique_members,
    COUNT(*) AS claim_count,
    SUM(fc.total_paid) AS total_paid,
    ROUND(SUM(fc.total_paid) / NULLIF(COUNT(DISTINCT dm.member_id), 0), 2) AS paid_per_member_per_year
FROM fact_claim fc
JOIN dim_member dm ON fc.member_key = dm.member_key
JOIN dim_provider dp ON fc.provider_key = dp.provider_key
JOIN dim_date d ON fc.date_key = d.date_key
WHERE fc.claim_status = 'Paid'
  AND d.year_number >= EXTRACT(YEAR FROM CURRENT_DATE)::INT - 1
GROUP BY d.year_number, dp.network_status
ORDER BY d.year_number, dp.network_status;
