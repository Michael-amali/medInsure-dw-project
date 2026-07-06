SET search_path TO dw, source_oltp, public;

-- Materialized view for Query #6 - monthly claims summary
CREATE MATERIALIZED VIEW dw.mv_monthly_claims_summary AS
WITH monthly_vol AS (
    SELECT
        d.year_month,
        COUNT(*) AS claim_count,
        SUM(fc.total_paid) AS paid_amount
    FROM dw.fact_claim fc
    JOIN dw.dim_date d ON fc.date_key = d.date_key
    WHERE d.full_date >= CURRENT_DATE - INTERVAL '24 months'
    GROUP BY d.year_month
)
SELECT
    year_month,
    claim_count,
    paid_amount,
    ROUND(AVG(claim_count) OVER (
        ORDER BY year_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 0) AS rolling_3mo_claims,
    ROUND(AVG(paid_amount) OVER (
        ORDER BY year_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS rolling_3mo_paid
FROM monthly_vol
ORDER BY year_month;

CREATE UNIQUE INDEX mv_monthly_claims_summary_year_month 
    ON dw.mv_monthly_claims_summary(year_month);

REFRESH MATERIALIZED VIEW CONCURRENTLY dw.mv_monthly_claims_summary;




-- EXPLAIN ANALYZE AFTER materialized view
EXPLAIN (ANALYZE, BUFFERS) 
SELECT * 
FROM dw.mv_monthly_claims_summary;