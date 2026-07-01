SET search_path TO dw, source_oltp, public;

-- Business Q: Do members enrolled in 2023 use more services in year 1 than 2022 cohort?
-- Why DW works: enrollment_date in dim_member + CTE. OLTP would require subqueries on OLTP.
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
