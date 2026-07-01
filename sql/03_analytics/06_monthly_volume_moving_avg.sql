SET search_path TO dw, source_oltp, public;

-- Business Q: What's our claims volume trend? Is it seasonal?
-- Why DW works: date_key enables fast monthly grouping. Window funcs run on aggregated data.
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
    ROUND(AVG(claim_count) OVER (
        ORDER BY year_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 0) AS rolling_3mo_claims,
    ROUND(AVG(paid_amount) OVER (
        ORDER BY year_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS rolling_3mo_paid
FROM monthly_vol
ORDER BY year_month;
