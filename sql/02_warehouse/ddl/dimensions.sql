SET search_path TO dw, public;

CREATE TABLE dim_date (
    date_key        INT         PRIMARY KEY,       -- YYYYMMDD
    full_date       DATE        NOT NULL UNIQUE,
    day_of_week     SMALLINT    NOT NULL,          -- 1=Mon, 7=Sun
    day_name        VARCHAR(10) NOT NULL,
    day_of_month    SMALLINT    NOT NULL,
    day_of_year     SMALLINT    NOT NULL,
    week_of_year    SMALLINT    NOT NULL,
    month_number    SMALLINT    NOT NULL,
    month_name      VARCHAR(10) NOT NULL,
    month_short     CHAR(3)     NOT NULL,
    quarter_number  SMALLINT    NOT NULL,
    quarter_name    CHAR(2)     NOT NULL,
    year_number     INT         NOT NULL,
    year_month      CHAR(7)     NOT NULL,          -- '2024-03'
    is_weekend      BOOLEAN     NOT NULL,
    is_us_holiday   BOOLEAN     NOT NULL DEFAULT FALSE,
    holiday_name    VARCHAR(50)
);


CREATE TABLE dim_member (
    member_key          BIGSERIAL   PRIMARY KEY,   -- Surrogate key
    member_id           VARCHAR(20) NOT NULL,      -- Natural key from OLTP
    first_name          VARCHAR(100),
    last_name           VARCHAR(100),
    date_of_birth       DATE,
    gender              CHAR(1),                  -- M/F/U
    state               VARCHAR(2),
    zip_code            VARCHAR(10),
    plan_id             VARCHAR(20),               -- Current plan from plan history
    plan_name           VARCHAR(100),              -- Denormalized for BI tool ease
    plan_type           VARCHAR(20),               -- HMO, PPO, EPO, HDHP
    enrollment_date     DATE,
    -- SCD Type 2 columns
    effective_start     DATE        NOT NULL,      -- Business date of plan/state change
    effective_end       DATE        NOT NULL DEFAULT '9999-12-31',
    is_current          BOOLEAN     NOT NULL DEFAULT TRUE,
    source_updated_at   TIMESTAMP                  -- For ETL change detection
);

CREATE INDEX idx_dim_member_nk_current ON dim_member(member_id, is_current);
CREATE INDEX idx_dim_member_daterange ON dim_member(member_id, effective_start, effective_end);

-- Not Applicable row for orphaned FKs
INSERT INTO dim_member (
    member_key, member_id, first_name, last_name, plan_id, plan_name, plan_type,
    effective_start, effective_end, is_current
) VALUES (-1, 'N/A', 'Not Applicable', 'Not Applicable', 'N/A', 'Not Applicable', 'N/A',
          '1900-01-01', '9999-12-31', FALSE);

COMMENT ON TABLE dim_member IS 'SCD Type 2. Tracks plan_id, state, zip_code changes for compliance + utilization.';


CREATE TABLE dim_provider (
    provider_key        BIGSERIAL   PRIMARY KEY,
    provider_id         VARCHAR(20) NOT NULL,      -- NPI usually
    provider_name       VARCHAR(200) NOT NULL,
    provider_type       VARCHAR(50),               -- Individual, Facility, Group
    specialty           VARCHAR(100),
    network_status      VARCHAR(20),               -- In-Network, Out-of-Network
    state               VARCHAR(2),
    zip_code            VARCHAR(10),
    -- SCD Type 2 columns
    effective_start     DATE        NOT NULL,      -- Date network status or specialty changed
    effective_end       DATE        NOT NULL DEFAULT '9999-12-31',
    is_current          BOOLEAN     NOT NULL DEFAULT TRUE,
    source_updated_at   TIMESTAMP
);

CREATE INDEX idx_dim_provider_nk_current ON dim_provider(provider_id, is_current);
CREATE INDEX idx_dim_provider_daterange ON dim_provider(provider_id, effective_start, effective_end);

INSERT INTO dim_provider (
    provider_key, provider_id, provider_name, provider_type, specialty, network_status,
    effective_start, effective_end, is_current
) VALUES (-1, 'N/A', 'Not Applicable', 'N/A', 'N/A', 'N/A',
          '1900-01-01', '9999-12-31', FALSE);

COMMENT ON TABLE dim_provider IS 'SCD Type 2. Network status at service_date is critical for OON analysis.';


CREATE TABLE dim_diagnosis (
    diagnosis_key       SERIAL      PRIMARY KEY,
    diagnosis_code      VARCHAR(10) NOT NULL UNIQUE,  -- ICD-10-CM full code
    diagnosis_desc      VARCHAR(500) NOT NULL,
    diagnosis_category  VARCHAR(100),                 -- First 3 chars group
    icd_chapter         VARCHAR(200),                 -- Chapter 1-21
    is_active           BOOLEAN     NOT NULL DEFAULT TRUE
);

CREATE INDEX idx_dim_diagnosis_code ON dim_diagnosis(diagnosis_code);

INSERT INTO dim_diagnosis (diagnosis_key, diagnosis_code, diagnosis_desc, diagnosis_category, icd_chapter)
VALUES (-1, 'N/A', 'Not Applicable', 'N/A', 'N/A');

COMMENT ON TABLE dim_diagnosis IS 'Type 1. ICD-10 reference. Hierarchy denormalized for BI performance.';


CREATE TABLE dim_procedure (
    procedure_key       SERIAL      PRIMARY KEY,
    procedure_code      VARCHAR(10) NOT NULL UNIQUE,  -- CPT/HCPCS
    procedure_desc      VARCHAR(500) NOT NULL,
    procedure_category  VARCHAR(100),
    is_active           BOOLEAN     NOT NULL DEFAULT TRUE
);

CREATE INDEX idx_dim_procedure_code ON dim_procedure(procedure_code);

INSERT INTO dim_procedure (procedure_key, procedure_code, procedure_desc, procedure_category)
VALUES (-1, 'N/A', 'Not Applicable', 'N/A');

COMMENT ON TABLE dim_procedure IS 'Type 1. CPT/HCPCS reference.';


CREATE TABLE dim_plan (
    plan_key            SERIAL      PRIMARY KEY,
    plan_id             VARCHAR(20) NOT NULL UNIQUE,
    plan_name           VARCHAR(100) NOT NULL,
    plan_type           VARCHAR(20) NOT NULL,      -- HMO, PPO, EPO, HDHP
    annual_deductible   DECIMAL(10,2),
    oop_max             DECIMAL(10,2),             -- Out of pocket max
    is_active           BOOLEAN     NOT NULL DEFAULT TRUE
);

INSERT INTO dim_plan (plan_key, plan_id, plan_name, plan_type, annual_deductible, oop_max)
VALUES (-1, 'N/A', 'Not Applicable', 'N/A', 0, 0);

COMMENT ON TABLE dim_plan IS 'Type 1. Plan attributes. Historical deductible tracked via dim_member SCD2.';
