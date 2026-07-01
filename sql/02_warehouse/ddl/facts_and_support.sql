SET search_path TO dw, public;

CREATE TABLE fact_claim (
    claim_key           BIGSERIAL   PRIMARY KEY,
    -- Degenerate dimension
    claim_id            VARCHAR(30) NOT NULL UNIQUE,  -- Natural key from OLTP
    -- Dimension FKs
    date_key            INT         NOT NULL REFERENCES dim_date(date_key),
    member_key          BIGINT      NOT NULL REFERENCES dim_member(member_key),
    provider_key        BIGINT      NOT NULL REFERENCES dim_provider(provider_key),
    -- Dates
    service_date        DATE        NOT NULL,         -- Used for SCD joins
    processed_date      DATE        NOT NULL,
    -- Claim attributes
    claim_type          VARCHAR(20),                  -- Professional, Institutional, Pharmacy
    claim_status        VARCHAR(20) NOT NULL,         -- Paid, Denied, Pending
    denial_reason       VARCHAR(100),
    -- Measures - rolled up from lines
    total_billed        DECIMAL(12,2) NOT NULL DEFAULT 0,
    total_allowed       DECIMAL(12,2) NOT NULL DEFAULT 0,
    total_paid          DECIMAL(12,2) NOT NULL DEFAULT 0,
    member_liability    DECIMAL(12,2) NOT NULL DEFAULT 0,
    line_count          SMALLINT    NOT NULL DEFAULT 0,
    -- ETL audit
    etl_loaded_at       TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for common query patterns
CREATE INDEX idx_fact_claim_date ON fact_claim(date_key);
CREATE INDEX idx_fact_claim_member ON fact_claim(member_key);
CREATE INDEX idx_fact_claim_provider ON fact_claim(provider_key);
CREATE INDEX idx_fact_claim_service_date ON fact_claim(service_date);
CREATE INDEX idx_fact_claim_status ON fact_claim(claim_status);
-- Covering index for provider performance report
CREATE INDEX idx_fact_claim_provider_date_cov 
    ON fact_claim(provider_key, date_key) 
    INCLUDE (total_paid, claim_status);

COMMENT ON TABLE fact_claim IS 'Transaction fact. Grain: one row per claim header. Amounts rolled from lines.';


CREATE TABLE fact_claim_line (
    claim_line_key      BIGSERIAL   PRIMARY KEY,
    -- FK to header fact
    claim_key           BIGINT      NOT NULL REFERENCES fact_claim(claim_key),
    -- Degenerate dimensions
    claim_id            VARCHAR(30) NOT NULL,         -- For drill-through
    claim_line_number   SMALLINT    NOT NULL,
    -- Dimension FKs
    date_key            INT         NOT NULL REFERENCES dim_date(date_key),
    procedure_key       INT         NOT NULL REFERENCES dim_procedure(procedure_key),
    diagnosis_key       INT         NOT NULL REFERENCES dim_diagnosis(diagnosis_key),
    -- Line attributes
    service_date        DATE        NOT NULL,
    place_of_service    VARCHAR(10),
    units               DECIMAL(8,2) NOT NULL DEFAULT 1,
    -- Measures
    billed_amount       DECIMAL(12,2) NOT NULL,
    allowed_amount      DECIMAL(12,2) NOT NULL,
    paid_amount         DECIMAL(12,2) NOT NULL,
    member_amount       DECIMAL(12,2) NOT NULL DEFAULT 0,
    -- ETL audit
    etl_loaded_at       TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(claim_id, claim_line_number)
);

-- Indexes
CREATE INDEX idx_fact_claim_line_claim ON fact_claim_line(claim_key);
CREATE INDEX idx_fact_claim_line_date ON fact_claim_line(date_key);
CREATE INDEX idx_fact_claim_line_procedure ON fact_claim_line(procedure_key);
CREATE INDEX idx_fact_claim_line_diagnosis ON fact_claim_line(diagnosis_key);
-- Covering for diagnosis spend queries
CREATE INDEX idx_fact_claim_line_diag_date_cov 
    ON fact_claim_line(diagnosis_key, date_key) 
    INCLUDE (paid_amount);

COMMENT ON TABLE fact_claim_line IS 'Transaction fact. Grain: one row per service line. Child of fact_claim.';


-- Dead letter queue for orphaned records during ETL
CREATE TABLE dlq_claim_load (
    dlq_id              BIGSERIAL PRIMARY KEY,
    claim_id            VARCHAR(30),
    error_type          VARCHAR(50),  -- MISSING_MEMBER, MISSING_PROVIDER, etc
    error_detail        TEXT,
    source_payload      JSONB,
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE dlq_claim_load IS 'ETL error handling. Pipeline does not fail on missing dims.';
