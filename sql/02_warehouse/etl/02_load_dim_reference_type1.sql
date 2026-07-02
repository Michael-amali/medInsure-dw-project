SET search_path TO dw, source_oltp, public;

-- ETL step: 2 of 6
-- Depends on: 01_load_dim_date.sql, oltp_seed_data.sql
-- Layer: warehouse ETL

INSERT INTO dw.dim_plan (plan_id, plan_name, plan_type, annual_deductible, oop_max, is_active)
SELECT 
    pt.plan_id,
    pt.plan_name,
    pt.plan_type,
    pt.annual_deductible,
    pt.oop_max,
    TRUE
FROM source_oltp.plan_types pt
ON CONFLICT (plan_id) DO UPDATE SET
    plan_name = EXCLUDED.plan_name,
    plan_type = EXCLUDED.plan_type,
    annual_deductible = EXCLUDED.annual_deductible,
    oop_max = EXCLUDED.oop_max;


INSERT INTO dw.dim_diagnosis (diagnosis_code, diagnosis_desc, diagnosis_category, icd_chapter)
SELECT 
    dc.diagnosis_code,
    dc.description,
    LEFT(dc.diagnosis_code, 3) AS diagnosis_category,
    dc.chapter
FROM source_oltp.diagnosis_codes dc
ON CONFLICT (diagnosis_code) DO UPDATE SET
    diagnosis_desc = EXCLUDED.diagnosis_desc,
    diagnosis_category = EXCLUDED.diagnosis_category,
    icd_chapter = EXCLUDED.icd_chapter;


INSERT INTO dw.dim_procedure (procedure_code, procedure_desc, procedure_category)
SELECT 
    pc.procedure_code,
    pc.description,
    pc.category
FROM source_oltp.procedure_codes pc
ON CONFLICT (procedure_code) DO UPDATE SET
    procedure_desc = EXCLUDED.procedure_desc,
    procedure_category = EXCLUDED.procedure_category;




-- Testing purposes
-- SET search_path TO dw;

-- SELECT * FROM dw.dim_plan 
-- SELECT * FROM dw.dim_diagnosis 
-- SELECT * FROM dw.dim_procedure 



-- Testing SCD Type 1
-- UPDATE source_oltp.procedure_codes
-- SET description = 'Radiology updated'
-- WHERE procedure_code = '71098';

-- Execute the UPDATE command above
-- Then run the INSERT command to the dw
-- Then check the result using SELECT
