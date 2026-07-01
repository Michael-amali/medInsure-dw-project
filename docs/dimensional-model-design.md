# Dimensional Model Design

> **Status:** Placeholder — content to be authored for Deliverable 1.

This document will describe the MedInsure analytics star schema including:

- Grain declaration for `fact_claim` and `fact_claim_line`
- Dimension list with SCD type decisions and justifications
- Fact table type classification (transaction / periodic snapshot / accumulating snapshot)
- Conformed dimensions shared with a future `fact_pharmacy` table
- Degenerate dimension identification

## Fact Tables

### fact_claim

_Grain: one row per claim header._

### fact_claim_line

_Grain: one row per service line within a claim._

## Dimensions

| Dimension | SCD Type | Tracks / Notes |
|-----------|----------|----------------|
| dim_date | N/A | Calendar 2020–2030 |
| dim_member | Type 2 | plan_id, state, zip_code |
| dim_provider | Type 2 | network_status, specialty |
| dim_diagnosis | Type 1 | ICD-10 reference |
| dim_procedure | Type 1 | CPT/HCPCS reference |
| dim_plan | Type 1 | Plan attributes (deductible, OOP max) |

## Conformed Dimensions

_TBD: identify dimensions shared with future fact_pharmacy._

## Degenerate Dimensions

_TBD: claim_id, claim_line_number._
