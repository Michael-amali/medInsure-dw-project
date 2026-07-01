# Performance Optimization Report

> **Status:** Placeholder — content to be authored for Deliverable 5.

This document will cover:

## Index Strategy

List every index on `fact_claim` and `fact_claim_line` with:

- Column list
- Index type (B-tree / covering)
- Query supported
- Indexes intentionally omitted and why (write overhead vs benefit)

Runnable index definitions live in:

- `sql/02_warehouse/ddl/facts_and_support.sql`

## Execution Plan Analysis

EXPLAIN ANALYZE output and plain-English interpretation for:

- Query #1 — `sql/05_optimization/explain_query_01_provider_yoy.sql`
- Query #6 — `sql/05_optimization/explain_query_06_monthly_trend.sql`

Include identification of the most expensive node in each plan.

## Materialized View

Definition and refresh in `sql/05_optimization/materialized_views.sql`.

Document:

- EXPLAIN output before (base tables) and after (materialized view)
- Recommended refresh schedule and justification
