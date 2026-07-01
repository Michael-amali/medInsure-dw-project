SET search_path TO dw, source_oltp, public;

-- Business Q: Are HMO members using more services than PPO? PMPM metrics.
-- Why DW works: Member plan_type is in dim_member SCD2. COUNT OVER gives members per month.
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
