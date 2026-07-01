SET search_path TO source_oltp, public;

-- ═══════════════════════════════════════════════════════════════
-- MEDINSURE OLTP - 3NF Claims Processing System
-- This is the source system. 18-month retention simulated.
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE plan_types (
    plan_id             VARCHAR(20) PRIMARY KEY,
    plan_name           VARCHAR(100) NOT NULL,
    plan_type           VARCHAR(20) NOT NULL,  -- HMO, PPO, EPO, HDHP
    annual_deductible   DECIMAL(10,2),
    oop_max             DECIMAL(10,2),
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE members (
    member_id           VARCHAR(20) PRIMARY KEY,
    first_name          VARCHAR(100),
    last_name           VARCHAR(100),
    date_of_birth       DATE,
    gender              CHAR(1),
    state               VARCHAR(2),
    zip_code            VARCHAR(10),
    enrollment_date     DATE NOT NULL,
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE member_plan_history (
    member_plan_id      BIGSERIAL PRIMARY KEY,
    member_id           VARCHAR(20) NOT NULL REFERENCES members(member_id),
    plan_id             VARCHAR(20) NOT NULL REFERENCES plan_types(plan_id),
    effective_date      DATE NOT NULL,
    end_date            DATE,
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(member_id, effective_date)
);

CREATE TABLE providers (
    provider_id         VARCHAR(20) PRIMARY KEY,  -- NPI
    provider_name       VARCHAR(200) NOT NULL,
    provider_type       VARCHAR(50),              -- Individual, Facility
    specialty           VARCHAR(100),
    state               VARCHAR(2),
    zip_code            VARCHAR(10),
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE provider_network_history (
    provider_network_id BIGSERIAL PRIMARY KEY,
    provider_id         VARCHAR(20) NOT NULL REFERENCES providers(provider_id),
    network_status      VARCHAR(20) NOT NULL,     -- In-Network, Out-of-Network
    effective_date      DATE NOT NULL,
    end_date            DATE,
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE diagnosis_codes (
    diagnosis_code      VARCHAR(10) PRIMARY KEY,  -- ICD-10-CM
    description         VARCHAR(500) NOT NULL,
    chapter             VARCHAR(200)
);

CREATE TABLE procedure_codes (
    procedure_code      VARCHAR(10) PRIMARY KEY,  -- CPT/HCPCS
    description         VARCHAR(500) NOT NULL,
    category            VARCHAR(100)
);

CREATE TABLE claims (
    claim_id            VARCHAR(30) PRIMARY KEY,
    member_id           VARCHAR(20) NOT NULL REFERENCES members(member_id),
    provider_id         VARCHAR(20) NOT NULL REFERENCES providers(provider_id),
    service_date        DATE NOT NULL,
    processed_date      DATE NOT NULL,
    claim_type          VARCHAR(20),              -- Professional, Institutional
    claim_status        VARCHAR(20) NOT NULL,     -- Paid, Denied, Pending
    denial_reason       VARCHAR(100),
    total_billed        DECIMAL(12,2) NOT NULL,
    total_allowed       DECIMAL(12,2) NOT NULL,
    total_paid          DECIMAL(12,2) NOT NULL,
    member_liability    DECIMAL(12,2) NOT NULL,
    line_count          SMALLINT NOT NULL,
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_claims_service_date ON claims(service_date);
CREATE INDEX idx_claims_member ON claims(member_id);
CREATE INDEX idx_claims_provider ON claims(provider_id);

CREATE TABLE claim_lines (
    claim_line_id       BIGSERIAL PRIMARY KEY,
    claim_id            VARCHAR(30) NOT NULL REFERENCES claims(claim_id),
    line_number         SMALLINT NOT NULL,
    service_date        DATE NOT NULL,
    procedure_code      VARCHAR(10) REFERENCES procedure_codes(procedure_code),
    diagnosis_code      VARCHAR(10) REFERENCES diagnosis_codes(diagnosis_code),
    place_of_service    VARCHAR(10),
    units               DECIMAL(8,2) DEFAULT 1,
    billed_amount       DECIMAL(12,2) NOT NULL,
    allowed_amount      DECIMAL(12,2) NOT NULL,
    paid_amount         DECIMAL(12,2) NOT NULL,
    member_amount       DECIMAL(12,2) DEFAULT 0,
    UNIQUE(claim_id, line_number)
);

CREATE INDEX idx_claim_lines_claim ON claim_lines(claim_id);
CREATE INDEX idx_claim_lines_procedure ON claim_lines(procedure_code);
