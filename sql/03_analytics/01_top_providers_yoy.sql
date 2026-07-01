SET search_path TO dw, source_oltp, public;

-- Business Q: Which providers are driving spend, and are they growing YoY?
-- Why DW works: Pre-joined provider_key + integer date_key. No 6-hr runtime.
WITH yearly_provider AS (
    SELECT
        dp.provider_name,
        dp.specialty,
        dd.year_number,
        SUM(fc.total_paid) AS paid_amount,
        COUNT(*) AS claim_count
    FROM fact_claim fc
    JOIN dim_provider dp ON fc.provider_key = dp.provider_key
    JOIN dim_date dd ON fc.date_key = dd.date_key
    WHERE fc.claim_status = 'Paid'
      AND dd.year_number IN (EXTRACT(YEAR FROM CURRENT_DATE)::INT, 
                             EXTRACT(YEAR FROM CURRENT_DATE)::INT - 1)
    GROUP BY dp.provider_name, dp.specialty, dd.year_number
)
SELECT
    cy.provider_name,
    cy.specialty,
    cy.paid_amount AS cy_paid,
    py.paid_amount AS py_paid,
    cy.paid_amount - COALESCE(py.paid_amount, 0) AS yoy_diff,
    ROUND((cy.paid_amount - COALESCE(py.paid_amount, 0)) 
          / NULLIF(py.paid_amount, 0) * 100, 1) AS yoy_pct,
    RANK() OVER (ORDER BY cy.paid_amount DESC) AS rank_cy
FROM yearly_provider cy
LEFT JOIN yearly_provider py 
    ON cy.provider_name = py.provider_name 
    AND py.year_number = cy.year_number - 1
WHERE cy.year_number = EXTRACT(YEAR FROM CURRENT_DATE)::INT
ORDER BY cy.paid_amount DESC
LIMIT 20;
