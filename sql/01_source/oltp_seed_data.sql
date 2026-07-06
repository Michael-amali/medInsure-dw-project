SET search_path TO source_oltp, public;

-- ═══════════════════════════════════════════════════════════════
-- Synthetic OLTP seed data
-- ═══════════════════════════════════════════════════════════════

-- 1. Plan types
INSERT INTO plan_types VALUES
('PLN_HMO_STD', 'HMO Standard', 'HMO', 1000, 5000, CURRENT_TIMESTAMP),
('PLN_HMO_PLUS', 'HMO Plus', 'HMO', 500, 3000, CURRENT_TIMESTAMP),
('PLN_PPO_STD', 'PPO Standard', 'PPO', 2000, 8000, CURRENT_TIMESTAMP),
('PLN_PPO_PLUS', 'PPO Plus', 'PPO', 1000, 5000, CURRENT_TIMESTAMP),
('PLN_EPO_STD', 'EPO Standard', 'EPO', 1500, 6000, CURRENT_TIMESTAMP),
('PLN_HDHP_1', 'HDHP 3000', 'HDHP', 3000, 6000, CURRENT_TIMESTAMP),
('PLN_HDHP_2', 'HDHP 5000', 'HDHP', 5000, 8000, CURRENT_TIMESTAMP),
('PLN_MCO', 'Managed Care', 'HMO', 750, 4000, CURRENT_TIMESTAMP);

-- 2. Diagnosis codes  - 12,000 ICD-10
INSERT INTO diagnosis_codes (diagnosis_code, description, chapter)
SELECT
    chapter || LPAD(gs::TEXT, 4, '0'),
    desc_prefix || ' ' || gs,
    chapter_name
FROM (
    VALUES
    ('E11.', 'Type 2 diabetes mellitus', 'Endocrine, nutritional and metabolic diseases'),
    ('I10.', 'Essential hypertension', 'Diseases of the circulatory system'),
    ('M54.', 'Dorsalgia', 'Diseases of the musculoskeletal system'),
    ('J06.', 'Acute upper respiratory infection', 'Diseases of the respiratory system'),
    ('Z00.', 'Encounter for general examination', 'Factors influencing health status'),
    ('K21.', 'Gastro-esophageal reflux', 'Diseases of the digestive system')
) AS c(chapter, desc_prefix, chapter_name)
CROSS JOIN GENERATE_SERIES(1, 2000) gs; -- 6 * 2000 = 12,000

-- 3. Procedure codes - 8,500 CPT exactly
INSERT INTO procedure_codes (procedure_code, description, category)
WITH codes AS (
    -- 5 rows: E&M 99211-99215
    SELECT '992' || LPAD(gs::TEXT, 2, '0') AS code, 'Evaluation and Management' AS cat
    FROM GENERATE_SERIES(11, 15) gs
    UNION ALL
    -- 100 rows: Lab 80000-80099
    SELECT '800' || LPAD(gs::TEXT, 2, '0'), 'Pathology and Laboratory'
    FROM GENERATE_SERIES(0, 99) gs
    UNION ALL
    -- 95 rows: Radiology 71000-71094
    SELECT '710' || LPAD(gs::TEXT, 2, '0'), 'Radiology'
    FROM GENERATE_SERIES(0, 94) gs
    UNION ALL
    -- 1,000 rows: Anesthesia 10000-10999
    SELECT '1' || LPAD(gs::TEXT, 4, '0'), 'Anesthesia'
    FROM GENERATE_SERIES(0, 999) gs
    UNION ALL
    -- 3,000 rows: Surgery 20000-22999
    SELECT '2' || LPAD(gs::TEXT, 4, '0'), 'Surgery'
    FROM GENERATE_SERIES(0, 2999) gs
    UNION ALL
    -- 4,300 rows: Medicine 30000-34299
    SELECT '3' || LPAD(gs::TEXT, 4, '0'), 'Medicine'
    FROM GENERATE_SERIES(0, 4299) gs
    -- 5 + 100 + 95 + 1000 + 3000 + 4300 = 8,500
)
SELECT code, 'CPT ' || code || ' - ' || cat, cat FROM codes;

-- 4. Members - 500k
INSERT INTO members (member_id, first_name, last_name, date_of_birth, gender, state, zip_code, enrollment_date)
SELECT 
    'M' || LPAD(gs::TEXT, 7, '0'),
    'First' || gs,
    'Last' || gs,
    '1970-01-01'::DATE + (random() * 20000)::INT, -- DOB 1970-2024
    CASE WHEN random() < 0.5 THEN 'M' ELSE 'F' END,
    (ARRAY['CA','TX','FL','NY','PA','IL','OH','GA','NC','MI'])[floor(random()*10+1)],
    LPAD((10000 + floor(random()*89999))::TEXT, 5, '0'),
    CASE 
        WHEN random() < 0.60 THEN '2026-01-01'::DATE + (random() * 180)::INT  -- 60% enrolled 2026 YTD
        WHEN random() < 0.90 THEN '2025-01-01'::DATE + (random() * 364)::INT  -- 30% enrolled 2025
        ELSE '2023-01-01'::DATE + (random() * 730)::INT                       -- 10% enrolled 2023-2024
    END
FROM GENERATE_SERIES(1, 500000) gs; 

-- 5. Member plan history  - 750,000 rows
TRUNCATE member_plan_history;
INSERT INTO member_plan_history (member_id, plan_id, effective_date, end_date)
-- Part 1: Every member gets a current plan = 500,000 rows
SELECT
    member_id,
    (ARRAY['PLN_HMO_STD','PLN_PPO_STD','PLN_HDHP_1','PLN_EPO_STD'])[1 + floor(random()*4)],
    enrollment_date,
    NULL::DATE
FROM members
UNION ALL
-- Part 2: 250,000 members get 1 prior plan = 250,000 rows
-- 500k + 250k = 750k total
SELECT
    m.member_id,
    (ARRAY['PLN_HMO_PLUS','PLN_PPO_PLUS','PLN_HDHP_2','PLN_MCO'])[1 + floor(random()*4)],
    m.enrollment_date - (30 + random()*700)::INT, -- 1mo-2yr prior
    m.enrollment_date - 1
FROM (
    SELECT member_id, enrollment_date 
    FROM members 
    ORDER BY random() 
    LIMIT 250000
) m;


-- 6. Providers - 15k
INSERT INTO providers (provider_id, provider_name, provider_type, specialty, state, zip_code)
SELECT
    'P' || LPAD(gs::TEXT, 6, '0'),
    CASE WHEN random() < 0.7 THEN 'Dr. ' || 'Last' || gs ELSE 'Hospital ' || gs END,
    CASE WHEN random() < 0.75 THEN 'Individual' ELSE 'Facility' END,
    (ARRAY['Family Medicine','Cardiology','Orthopedics','Pediatrics','Internal Medicine',
           'Radiology','Anesthesiology','General Surgery','OB/GYN','Psychiatry'])[floor(random()*10+1)],
    (ARRAY['CA','TX','FL','NY','PA','IL','OH','GA','NC','MI'])[floor(random()*10+1)],
    LPAD((10000 + floor(random()*89999))::TEXT, 5, '0')
FROM GENERATE_SERIES(1, 15000) gs;


-- 7. provider_network_history - 22,000 rows
INSERT INTO provider_network_history (provider_id, network_status, effective_date)
-- 2023: Exactly 1,100 providers = 5%
SELECT
    p.provider_id,
    'In-Network',
    '2023-01-01'::DATE + (random() * 364)::INT
FROM (
    SELECT provider_id 
    FROM providers 
    ORDER BY random() 
    LIMIT 1100
) p
UNION ALL
-- 2024: Exactly 2,200 providers = 10%
SELECT
    p.provider_id,
    CASE WHEN random() < 0.5 THEN 'Out-of-Network' ELSE 'In-Network' END,
    '2024-01-01'::DATE + (random() * 364)::INT
FROM (
    SELECT provider_id 
    FROM providers 
    ORDER BY random() 
    LIMIT 2200
) p
UNION ALL
-- 2025: Exactly 7,700 providers = 35%
SELECT
    p.provider_id,
    CASE WHEN random() < 0.5 THEN 'Out-of-Network' ELSE 'In-Network' END,
    '2025-01-01'::DATE + (random() * 364)::INT
FROM (
    SELECT provider_id 
    FROM providers 
    ORDER BY random() 
    LIMIT 7700
) p
UNION ALL
-- 2026: Exactly 11,000 providers = 50%
SELECT
    p.provider_id,
    CASE WHEN random() < 0.5 THEN 'Out-of-Network' ELSE 'In-Network' END,
    '2026-01-01'::DATE + (random() * 180)::INT  -- YTD through July 6
FROM (
    SELECT provider_id 
    FROM providers 
    ORDER BY random() 
    LIMIT 11000
) p;
-- 1,100 + 2,200 + 7,700 + 11,000 = 22,000


-- 8. Claims - 2,000,000 headers, avg 3.75 lines each = 7.5M lines
INSERT INTO claims (
    claim_id, member_id, provider_id, service_date, processed_date, claim_type,
    claim_status, total_billed, total_allowed, total_paid, member_liability, line_count
)
SELECT
    'CLM' || LPAD(gs::TEXT, 8, '0'),
    'M' || LPAD((1 + floor(random()*499999))::TEXT, 7, '0'),
    'P' || LPAD((1 + floor(random()*14999))::TEXT, 6, '0'),
    CASE
        WHEN random() < 0.50 THEN '2026-01-01'::DATE + (random() * 180)::INT
        WHEN random() < 0.80 THEN '2025-01-01'::DATE + (random() * 364)::INT
        WHEN random() < 0.95 THEN '2024-01-01'::DATE + (random() * 364)::INT
        ELSE '2023-01-01'::DATE + (random() * 364)::INT
    END AS service_date,
    LEAST(
        CASE
            WHEN random() < 0.50 THEN '2026-01-01'::DATE + (random() * 180)::INT + 7
            WHEN random() < 0.80 THEN '2025-01-01'::DATE + (random() * 364)::INT + 7
            ELSE '2024-01-01'::DATE + (random() * 364)::INT + 7
        END,
        CURRENT_DATE
    ) AS processed_date,
    CASE WHEN random() < 0.88 THEN 'Professional' ELSE 'Institutional' END,
    CASE WHEN random() < 0.91 THEN 'Paid' WHEN random() < 0.97 THEN 'Denied' ELSE 'Pending' END,
    (random() * 8000 + 100)::DECIMAL(12,2),
    (random() * 6000 + 80)::DECIMAL(12,2),
    (random() * 5000 + 50)::DECIMAL(12,2),
    (random() * 800)::DECIMAL(12,2),
    -- Force 3.75 avg: 75% get 4 lines, 25% get 3 lines
    CASE WHEN random() < 0.75 THEN 4 ELSE 3 END::SMALLINT
FROM GENERATE_SERIES(1, 2000000) gs;


-- 9. Claim lines - now this will give 7.5M rows exactly
TRUNCATE claim_lines;
INSERT INTO claim_lines (
    claim_id, line_number, service_date, procedure_code, diagnosis_code,
    place_of_service, units, billed_amount, allowed_amount, paid_amount, member_amount
)
WITH pc AS (SELECT array_agg(procedure_code) AS arr FROM procedure_codes),
     dc AS (SELECT array_agg(diagnosis_code) AS arr FROM diagnosis_codes)
SELECT
    c.claim_id,
    gs AS line_number,
    c.service_date,
    pc.arr[1 + floor(random() * array_length(pc.arr,1))],
    dc.arr[1 + floor(random() * array_length(dc.arr,1))],
    (ARRAY['11','21','22','23','24'])[1 + floor(random()*5)],
    1,
    (c.total_billed / c.line_count)::DECIMAL(12,2),
    (c.total_allowed / c.line_count)::DECIMAL(12,2),
    (c.total_paid / c.line_count)::DECIMAL(12,2),
    (c.member_liability / c.line_count)::DECIMAL(12,2)
FROM claims c
CROSS JOIN LATERAL GENERATE_SERIES(1, c.line_count) gs, pc, dc;

ANALYZE source_oltp.members;
ANALYZE source_oltp.claims;
ANALYZE source_oltp.claim_lines;

-- Row count verification
SELECT 'plan_types' AS table_name, COUNT(*) AS row_count FROM source_oltp.plan_types
UNION ALL
SELECT 'diagnosis_codes', COUNT(*) FROM source_oltp.diagnosis_codes
UNION ALL
SELECT 'procedure_codes', COUNT(*) FROM source_oltp.procedure_codes
UNION ALL
SELECT 'members', COUNT(*) FROM source_oltp.members
UNION ALL
SELECT 'member_plan_history', COUNT(*) FROM source_oltp.member_plan_history
UNION ALL
SELECT 'providers', COUNT(*) FROM source_oltp.providers
UNION ALL
SELECT 'provider_network_history', COUNT(*) FROM source_oltp.provider_network_history
UNION ALL
SELECT 'claims', COUNT(*) FROM source_oltp.claims
UNION ALL
SELECT 'claim_lines', COUNT(*) FROM source_oltp.claim_lines
ORDER BY table_name;



-- ---------------------------------------------------
--  Testing purposes: SOURCE tables display
-- ---------------------------------------------------
-- SELECT * FROM source_oltp.plan_types

-- SELECT * FROM source_oltp.diagnosis_codes

-- SELECT * FROM source_oltp.procedure_codes

-- SELECT * FROM source_oltp.providers

-- SELECT * FROM source_oltp.provider_network_history

-- SELECT * FROM source_oltp.claims

-- SELECT * FROM source_oltp.claim_lines