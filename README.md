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
│   └── etl/
├── 03_analytics/       8 business analytical queries
├── 04_quality/         Data quality checks
└── 05_optimization/    EXPLAIN plans and materialized views
docs/
├── dimensional-model-design.md
└── performance-optimization-report.md
```

The legacy flat layout in `medInsure-project/` is preserved separately; this repo is the structured capstone deliverable.

## Manual Execution Order

Run scripts in order against PostgreSQL 14+ using `psql -v ON_ERROR_STOP=1 -f <file>`:

| Step | File | Destructive? |
|------|------|--------------|
| 1 | `sql/00_bootstrap/create_schemas.sql` | Yes — drops `source_oltp` and `dw` |
| 2 | `sql/01_source/oltp_ddl.sql` | No |
| 3 | `sql/01_source/oltp_seed_data.sql` | No (inserts) |
| 4 | `sql/02_warehouse/ddl/dimensions.sql` | No |
| 5 | `sql/02_warehouse/ddl/facts_and_support.sql` | No |
| 6 | `sql/02_warehouse/etl/load_dim_date.sql` | No |
| 7 | `sql/02_warehouse/etl/load_dim_reference_type1.sql` | No |
| 8 | `sql/02_warehouse/etl/load_dim_member_scd2.sql` | No |
| 9 | `sql/02_warehouse/etl/load_dim_provider_scd2.sql` | No |
| 10 | `sql/02_warehouse/etl/load_fact_claim.sql` | No (incremental) |
| 11 | `sql/02_warehouse/etl/load_fact_claim_line.sql` | No |
| 12 | `sql/03_analytics/01_top_providers_yoy.sql` … `08_provider_ytd_cumulative.sql` | Read-only |
| 13 | `sql/04_quality/data_quality_checks.sql` | Read-only |
| 14 | `sql/05_optimization/explain_query_01_provider_yoy.sql` | Read-only |
| 15 | `sql/05_optimization/explain_query_06_monthly_trend.sql` | Read-only |
| 16 | `sql/05_optimization/materialized_views.sql` | DDL + refresh |

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
