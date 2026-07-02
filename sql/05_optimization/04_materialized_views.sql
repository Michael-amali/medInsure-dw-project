SET search_path TO dw, source_oltp, public;

-- Materialized view for Query #6 - monthly claims summary
CREATE MATERIALIZED VIEW dw.mv_monthly_claims_summary AS
SELECT
    d.year_number,
    d.month_number,
    d.year_month,
    COUNT(*) AS claim_count,
    COUNT(DISTINCT fc.member_key) AS unique_members,
    SUM(fc.total_paid) AS total_paid,
    SUM(fc.total_billed) AS total_billed,
    SUM(CASE WHEN fc.claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_count
FROM fact_claim fc
JOIN dim_date d ON fc.date_key = d.date_key
GROUP BY d.year_number, d.month_number, d.year_month;

CREATE UNIQUE INDEX idx_mv_monthly_claims_summary 
    ON dw.mv_monthly_claims_summary(year_month);

REFRESH MATERIALIZED VIEW CONCURRENTLY dw.mv_monthly_claims_summary;




-- EXPLAIN ANALYZE AFTER materialized view (run after sql/05_optimization/materialized_views.sql)
EXPLAIN ANALYZE
SELECT year_month, claim_count, total_paid 
FROM dw.mv_monthly_claims_summary 
WHERE year_month >= '2024-01';