SET search_path TO dw, source_oltp, public;

-- Business Q: Flag providers when they cross $1M YTD for contract renegotiation.
-- Why DW works: SUM() OVER cumulative on pre-aggregated fact. OLTP would full scan.
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
WHERE ytd_cumulative_paid > 500000  -- Filter after window calc
ORDER BY provider_name, full_date;
