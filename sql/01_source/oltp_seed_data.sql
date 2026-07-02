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

-- 2. Diagnosis codes - sample 500 ICD-10
INSERT INTO diagnosis_codes (diagnosis_code, description, chapter)
SELECT 
    'E11.' || LPAD(gs::TEXT, 3, '0'),
    'Type 2 diabetes mellitus, ICD-10 sample ' || gs,
    'Endocrine, nutritional and metabolic diseases'
FROM GENERATE_SERIES(1, 100) gs
UNION ALL
SELECT 
    'I10.' || LPAD(gs::TEXT, 3, '0'),
    'Essential hypertension ' || gs,
    'Diseases of the circulatory system'
FROM GENERATE_SERIES(1, 100) gs
UNION ALL
SELECT 
    'M54.' || LPAD(gs::TEXT, 3, '0'),
    'Dorsalgia ' || gs,
    'Diseases of the musculoskeletal system'
FROM GENERATE_SERIES(1, 100) gs
UNION ALL
SELECT 
    'J06.' || LPAD(gs::TEXT, 3, '0'),
    'Acute upper respiratory infection ' || gs,
    'Diseases of the respiratory system'
FROM GENERATE_SERIES(1, 100) gs
UNION ALL
SELECT 
    'Z00.' || LPAD(gs::TEXT, 3, '0'),
    'Encounter for general examination ' || gs,
    'Factors influencing health status'
FROM GENERATE_SERIES(1, 100) gs;

-- 3. Procedure codes - sample 200 CPT
INSERT INTO procedure_codes (procedure_code, description, category)
SELECT 
    '992' || LPAD(gs::TEXT, 2, '0'),
    'Office visit E&M ' || gs,
    'Evaluation and Management'
FROM GENERATE_SERIES(11, 15) gs
UNION ALL
SELECT 
    '8005' || gs,
    'Lab panel ' || gs,
    'Pathology and Laboratory'
FROM GENERATE_SERIES(0, 9) gs
UNION ALL
SELECT 
    '710' || LPAD(gs::TEXT, 2, '0'),
    'Radiology ' || gs,
    'Radiology'
FROM GENERATE_SERIES(10, 99) gs;

-- 4. Members - 50k
INSERT INTO members (member_id, first_name, last_name, date_of_birth, gender, state, zip_code, enrollment_date)
SELECT 
    'M' || LPAD(gs::TEXT, 7, '0'),
    'First' || gs,
    'Last' || gs,
    '1970-01-01'::DATE + (random() * 20000)::INT,
    CASE WHEN random() < 0.5 THEN 'M' ELSE 'F' END,
    (ARRAY['CA','TX','FL','NY','PA','IL','OH','GA'])[floor(random()*8+1)],
    LPAD((10000 + floor(random()*89999))::TEXT, 5, '0'),
    CASE 
        WHEN random() < 0.60 THEN '2026-01-01'::DATE + (random() * 180)::INT
        WHEN random() < 0.90 THEN '2025-01-01'::DATE + (random() * 364)::INT
        ELSE '2023-01-01'::DATE + (random() * 730)::INT
    END
FROM GENERATE_SERIES(1, 50000) gs;

-- 5. Member plan history - ~75k rows
INSERT INTO member_plan_history (member_id, plan_id, effective_date, end_date)
SELECT 
    m.member_id,
    (ARRAY['PLN_HMO_STD','PLN_PPO_STD','PLN_HDHP_1'])[floor(random()*3+1)],
    m.enrollment_date,
    NULL::DATE
FROM members m
UNION ALL
SELECT 
    m.member_id,
    (ARRAY['PLN_HMO_PLUS','PLN_PPO_PLUS','PLN_HDHP_2'])[floor(random()*3+1)],
    m.enrollment_date + 1 + (random() * 364)::INT,
    NULL::DATE
FROM members m
WHERE random() < 0.5;

-- 6. Providers - 2k
INSERT INTO providers (provider_id, provider_name, provider_type, specialty, state, zip_code)
SELECT 
    'P' || LPAD(gs::TEXT, 6, '0'),
    'Provider ' || gs || ' MD',
    CASE WHEN random() < 0.8 THEN 'Individual' ELSE 'Facility' END,
    (ARRAY['Family Medicine','Cardiology','Orthopedics','Pediatrics','Internal Medicine'])[floor(random()*5+1)],
    (ARRAY['CA','TX','FL','NY','PA'])[floor(random()*5+1)],
    LPAD((10000 + floor(random()*89999))::TEXT, 5, '0')
FROM GENERATE_SERIES(1, 2000) gs;

-- 7. Provider network history - ~2.2k rows
INSERT INTO provider_network_history (provider_id, network_status, effective_date)
SELECT 
    provider_id,
    'In-Network',
    CASE 
        WHEN random() < 0.5 THEN '2024-01-01'::DATE + (random() * 364)::INT
        ELSE '2025-01-01'::DATE + (random() * 364)::INT
    END
FROM providers
UNION ALL
SELECT 
    provider_id,
    'Out-of-Network',
    '2025-06-01'::DATE + (random() * 395)::INT
FROM providers
WHERE random() < 0.1;

-- 8. Claims - 50k headers
INSERT INTO claims (
    claim_id, member_id, provider_id, service_date, processed_date, claim_type,
    claim_status, total_billed, total_allowed, total_paid, member_liability, line_count
)
SELECT
    'CLM' || LPAD(gs::TEXT, 8, '0'),
    'M' || LPAD((1 + floor(random()*49999))::TEXT, 7, '0'),
    'P' || LPAD((1 + floor(random()*1999))::TEXT, 6, '0'),
    CASE 
        WHEN random() < 0.60 THEN '2026-01-01'::DATE + (random() * 180)::INT
        WHEN random() < 0.90 THEN '2025-01-01'::DATE + (random() * 364)::INT
        ELSE '2024-01-01'::DATE + (random() * 364)::INT
    END AS service_date,
    LEAST(
        CASE
            WHEN random() < 0.60 THEN '2026-01-01'::DATE + (random() * 180)::INT + 7
            WHEN random() < 0.90 THEN '2025-01-01'::DATE + (random() * 364)::INT + 7
            ELSE '2024-01-01'::DATE + (random() * 364)::INT + 7
        END,
        CURRENT_DATE
    ) AS processed_date,
    CASE WHEN random() < 0.9 THEN 'Professional' ELSE 'Institutional' END,
    CASE WHEN random() < 0.92 THEN 'Paid' WHEN random() < 0.97 THEN 'Denied' ELSE 'Pending' END,
    (random() * 5000 + 100)::DECIMAL(12,2),
    (random() * 4000 + 80)::DECIMAL(12,2),
    (random() * 3500 + 50)::DECIMAL(12,2),
    (random() * 500)::DECIMAL(12,2),
    floor(random()*4 + 1)::SMALLINT
FROM GENERATE_SERIES(1, 50000) gs;

-- 9. Claim lines - ~200k
INSERT INTO claim_lines (
    claim_id, line_number, service_date, procedure_code, diagnosis_code,
    place_of_service, units, billed_amount, allowed_amount, paid_amount, member_amount
)
SELECT 
    c.claim_id,
    row_number() OVER (PARTITION BY c.claim_id ORDER BY random()) AS line_number,
    c.service_date,
    (SELECT procedure_code FROM procedure_codes ORDER BY random() LIMIT 1),
    (SELECT diagnosis_code FROM diagnosis_codes ORDER BY random() LIMIT 1),
    (ARRAY['11','21','22','23'])[floor(random()*4+1)],
    1,
    (c.total_billed / c.line_count)::DECIMAL(12,2),
    (c.total_allowed / c.line_count)::DECIMAL(12,2),
    (c.total_paid / c.line_count)::DECIMAL(12,2),
    (c.member_liability / c.line_count)::DECIMAL(12,2)
FROM claims c
CROSS JOIN GENERATE_SERIES(1, c.line_count) gs;

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