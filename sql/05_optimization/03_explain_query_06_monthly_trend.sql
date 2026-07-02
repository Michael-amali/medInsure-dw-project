SET search_path TO dw, source_oltp, public;

-- EXPLAIN ANALYZE for Analytics Query #6: Monthly claims volume with 3-month moving average
-- Run BEFORE materialized view exists (base tables)
EXPLAIN (ANALYZE, BUFFERS, TIMING)
WITH monthly_vol AS (
    SELECT
        d.year_month,
        COUNT(*) AS claim_count,
        SUM(fc.total_paid) AS paid_amount
    FROM fact_claim fc
    JOIN dim_date d ON fc.date_key = d.date_key
    WHERE d.full_date >= CURRENT_DATE - INTERVAL '24 months'
    GROUP BY d.year_month
)
SELECT
    year_month,
    claim_count,
    paid_amount,
    AVG(claim_count) OVER (ORDER BY year_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS rolling_3mo_claims
FROM monthly_vol
ORDER BY year_month;


