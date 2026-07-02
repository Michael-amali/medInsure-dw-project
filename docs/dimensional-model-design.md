# Deliverable 1: Dimensional Model Design

## Grain Declarations

- **fact_claim:** One row per claim header (one row per visit/encounter).
- **fact_claim_line:** One row per claim service line (one row per individual service/procedure within a claim).

## Dimensions and SCD Decisions

- **dim_date:** Type 0 (static calendar). No history needed; supports all date-based analysis.
- **dim_member:** SCD Type 2. Tracks changes to `plan_id`, `state`, `zip_code` over time. Justification: Member enrollment and plan changes must be accurately attributed to the service date for compliance and utilization analysis.
- **dim_provider:** SCD Type 2. Tracks `network_status` and `specialty` changes. Justification: Network status affects reimbursement and out-of-network reporting; historical accuracy required for contract reviews.
- **dim_diagnosis:** SCD Type 1. ICD-10 codes rarely change; overwrite description/category. Justification: Reference data; no need for history.
- **dim_procedure:** SCD Type 1. CPT codes rarely change. Justification: Reference data.
- **dim_plan:** SCD Type 1. Plan attributes (deductible, OOP max, plan type). Justification: Slow-changing reference; Type 1 sufficient.
- **Conformed dimension:** `dim_date` and `dim_plan` (plan type shared with future `fact_pharmacy`).

## Fact Table Classifications

- **fact_claim:** Transaction fact. Captures each claim event at the point it occurs. Justification: Claims are discrete events with measures like paid/allowed amounts.
- **fact_claim_line:** Transaction fact (line-level detail). Justification: Detailed cost and service metrics per line.

## Degenerate Dimensions

- **claim_id** (in `fact_claim`): Natural key for auditing/reference, not a dimension.
- **claim_line_id** or line sequence (in `fact_claim_line`).

## Additional Design Notes

- Surrogate keys (SERIAL or BIGSERIAL) for all dims.
- SCD Type 2 dims include effective_start, effective_end, is_current.
- NA row (-1) for dimensions.
- Indexes on FKs in facts.