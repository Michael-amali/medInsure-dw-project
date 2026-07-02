# MedInsure Analytics Data Warehouse

Capstone project for MedInsure, a regional health insurance provider. This repository implements a PostgreSQL star-schema data warehouse with SCD Type 2 dimensions, ETL SQL, analytical queries, performance optimization, and data quality checks.

**Schemas:**
- `source_oltp` — 3NF claims processing system (synthetic data)
- `dw` — Dimensional warehouse for analytics

See [docs/dimensional-model-design.md](docs/dimensional-model-design.md) for the star schema design document.

## Project Structure

```
sql/
├── 00_bootstrap/       Schema creation (destructive reset)
├── 01_source/          OLTP DDL and synthetic seed data
├── 02_warehouse/       DW DDL and ETL loads
│   ├── ddl/
│   └── etl/            Numbered 01–06 (run in order)
├── 03_analytics/       8 business analytical queries
├── 04_quality/         Data quality checks
└── 05_optimization/    EXPLAIN plans and materialized views
docs/
├
└── dimensional-model-design.md
```




## Analytics Queries

| # | File | Business Question |
|---|------|-------------------|
| 1 | `03_analytics/01_top_providers_yoy.sql` | Top 20 providers by paid amount with YoY comparison |
| 2 | `03_analytics/02_diagnosis_category_spend.sql` | Claims paid by ICD-10 category, ranked by spend |
| 3 | `03_analytics/03_member_utilization_by_plan.sql` | Member utilization rate by plan type and month |
| 4 | `03_analytics/04_denied_claims_by_specialty.sql` | Denial rate by provider specialty and claim type |
| 5 | `03_analytics/05_out_of_network_cost_comparison.sql` | In-network vs out-of-network paid per member per year |
| 6 | `03_analytics/06_monthly_volume_moving_avg.sql` | Monthly claims volume with 3-month moving average |
| 7 | `03_analytics/07_member_cohort_first_year.sql` | Claims frequency in first 12 months by enrollment cohort |
| 8 | `03_analytics/08_provider_ytd_cumulative.sql` | Running cumulative paid by provider YTD, $1M flag |

## Deliverables

| Deliverable | Location |
|-------------|----------|
| Dimensional model design | `docs/dimensional-model-design.md` |
| Physical DDL | `sql/02_warehouse/ddl/` |
| ETL SQL | `sql/02_warehouse/etl/` |
| Analytical queries | `sql/03_analytics/` |
| Performance optimization | `docs/performance-optimization-report.md` + `sql/05_optimization/` |
| Data quality report | `sql/04_quality/data_quality_checks.sql` |
