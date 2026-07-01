SET search_path TO dw, source_oltp, public;

-- Business Q: What diagnosis categories cost us the most? For contract reviews.
-- Why DW works: dim_diagnosis denormalizes ICD-10 hierarchy. No OLTP join to reference table.
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
