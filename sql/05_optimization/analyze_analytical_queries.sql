SET search_path TO dw, source_oltp, public;

-- EXPLAIN ANALYZE for Analytics Query #1:
EXPLAIN (ANALYZE, BUFFERS, TIMING)
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


-- EXPLAIN ANALYZE for Analytics Query #2:
SET search_path TO dw, source_oltp, public;
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT
    ddg.diagnosis_category,
    ddg.icd_chapter,
    COUNT(DISTINCT fcl.claim_id) AS claim_count,
    SUM(fcl.paid_amount) AS total_paid,
    ROUND(AVG(fcl.paid_amount), 2) AS avg_paid_per_line,
    RANK() OVER (ORDER BY SUM(fcl.paid_amount) DESC) AS spend_rank
FROM fact_claim_line fcl
JOIN dim_diagnosis ddg ON fcl.diagnosis_key = ddg.diagnosis_key
JOIN dim_date d ON fcl.date_key = d.date_key
WHERE d.year_number = EXTRACT(YEAR FROM CURRENT_DATE)::INT
GROUP BY ddg.diagnosis_category, ddg.icd_chapter
ORDER BY total_paid DESC;


-- EXPLAIN ANALYZE for Analytics Query #3:
SET search_path TO dw, source_oltp, public;
EXPLAIN (ANALYZE, BUFFERS, TIMING)
WITH monthly_claims AS (
    SELECT
        dm.plan_type,
        d.year_month,
        COUNT(*) AS claim_count
    FROM fact_claim fc
    JOIN dim_member dm ON fc.member_key = dm.member_key
    JOIN dim_date d ON fc.date_key = d.date_key
    WHERE d.full_date >= DATE_TRUNC('year', CURRENT_DATE)
    GROUP BY dm.plan_type, d.year_month
),
monthly_members AS (
    SELECT
        plan_type,
        TO_CHAR(effective_start, 'YYYY-MM') AS year_month,
        COUNT(DISTINCT member_id) AS member_count
    FROM dim_member
    WHERE is_current = TRUE
    GROUP BY plan_type, TO_CHAR(effective_start, 'YYYY-MM')
)
SELECT
    mc.plan_type,
    mc.year_month,
    mc.claim_count,
    mm.member_count,
    ROUND(mc.claim_count * 1000.0 / NULLIF(mm.member_count, 0), 1) AS claims_per_1000_members
FROM monthly_claims mc
LEFT JOIN monthly_members mm ON mc.plan_type = mm.plan_type AND mc.year_month = mm.year_month
ORDER BY mc.year_month, mc.plan_type;


-- EXPLAIN ANALYZE for Analytics Query #4:
SET search_path TO dw, source_oltp, public;
EXPLAIN (ANALYZE, BUFFERS, TIMING)
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


-- EXPLAIN ANALYZE for Analytics Query #5:
SET search_path TO dw, source_oltp, public;
EXPLAIN (ANALYZE, BUFFERS, TIMING)
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


-- EXPLAIN ANALYZE for Analytics Query #6:
SET search_path TO dw, source_oltp, public;
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
    ROUND(AVG(claim_count) OVER (
        ORDER BY year_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 0) AS rolling_3mo_claims,
    ROUND(AVG(paid_amount) OVER (
        ORDER BY year_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS rolling_3mo_paid
FROM monthly_vol
ORDER BY year_month;


-- EXPLAIN ANALYZE for Analytics Query #7:
SET search_path TO dw, source_oltp, public;
EXPLAIN (ANALYZE, BUFFERS, TIMING)
WITH member_cohorts AS (
    SELECT
        member_id,
        DATE_TRUNC('year', enrollment_date)::DATE AS cohort_year,
        enrollment_date
    FROM dim_member
    WHERE is_current = TRUE
      AND EXTRACT(YEAR FROM enrollment_date) >= 2022
),
first_year_claims AS (
    SELECT
        mc.cohort_year,
        mc.member_id,
        COUNT(*) AS claim_count_12mo
    FROM member_cohorts mc
    JOIN fact_claim fc ON mc.member_id = (
        SELECT member_id FROM dim_member WHERE member_key = fc.member_key LIMIT 1
    )
    WHERE fc.service_date BETWEEN mc.enrollment_date 
                              AND mc.enrollment_date + INTERVAL '12 months'
    GROUP BY mc.cohort_year, mc.member_id
)
SELECT
    cohort_year,
    COUNT(*) AS cohort_size,
    ROUND(AVG(claim_count_12mo), 2) AS avg_claims_first_year,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY claim_count_12mo) AS median_claims
FROM first_year_claims
GROUP BY cohort_year
ORDER BY cohort_year;


-- EXPLAIN ANALYZE for Analytics Query #8:
SET search_path TO dw, source_oltp, public;
EXPLAIN (ANALYZE, BUFFERS, TIMING)
WITH daily_provider_paid AS (
    SELECT
        dp.provider_key,
        dp.provider_name,
        dp.specialty,
        d.full_date,
        d.year_number,
        SUM(fc.total_paid) AS daily_paid
    FROM fact_claim fc
    JOIN dim_provider dp ON fc.provider_key = dp.provider_key
    JOIN dim_date d ON fc.date_key = d.date_key
    WHERE d.year_number = EXTRACT(YEAR FROM CURRENT_DATE)::INT
      AND fc.claim_status = 'Paid'
    GROUP BY dp.provider_key, dp.provider_name, dp.specialty, d.full_date, d.year_number
),
with_running_total AS (
    SELECT
        provider_key,
        provider_name,
        specialty,
        full_date,
        daily_paid,
        SUM(daily_paid) OVER (
            PARTITION BY provider_key, year_number
            ORDER BY full_date
            ROWS UNBOUNDED PRECEDING
        ) AS ytd_cumulative_paid
    FROM daily_provider_paid
)
SELECT
    provider_name,
    specialty,
    full_date,
    daily_paid,
    ytd_cumulative_paid,
    CASE 
        WHEN ytd_cumulative_paid >= 1000000 THEN 'ALERT: >$1M YTD'
        ELSE NULL 
    END AS threshold_flag
FROM with_running_total
WHERE ytd_cumulative_paid > 150000  -- Filter after window calc
ORDER BY provider_name, full_date;
