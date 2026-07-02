SET search_path TO dw, source_oltp, public;

-- EXPLAIN ANALYZE for Analytics Query #1: Top providers by paid amount with YoY comparison
EXPLAIN (ANALYZE, BUFFERS, TIMING)
WITH yearly_provider AS (
    SELECT
        dp.provider_name,
        dp.specialty,
        dd.year_number,
        SUM(fc.total_paid) AS paid_amount
    FROM fact_claim fc
    JOIN dim_provider dp ON fc.provider_key = dp.provider_key
    JOIN dim_date dd ON fc.date_key = dd.date_key
    WHERE fc.claim_status = 'Paid'
      AND dd.year_number IN (2025, 2024)
    GROUP BY dp.provider_name, dp.specialty, dd.year_number
)
SELECT * FROM yearly_provider cy
WHERE cy.year_number = 2025
ORDER BY cy.paid_amount DESC LIMIT 20;
