## EXPLAIN Output Before: Base Tables
```text
WindowAgg  (cost=11737.66..11782.04 rows=132 width=112) (actual time=150.420..156.216 rows=24.00 loops=1)
  Window: w1 AS (ORDER BY d.year_month ROWS BETWEEN '2'::bigint PRECEDING AND CURRENT ROW)
  Storage: Memory  Maximum Storage: 17kB
  Buffers: shared hit=3449 read=4333
  ->  Finalize GroupAggregate  (cost=11737.33..11779.07 rows=132 width=48) (actual time=150.387..156.133 rows=24.00 loops=1)
        Group Key: d.year_month
        Buffers: shared hit=3449 read=4333
        ->  Gather Merge  (cost=11737.33..11774.25 rows=317 width=48) (actual time=150.377..156.083 rows=70.00 loops=1)
              Workers Planned: 2
              Workers Launched: 2
              Buffers: shared hit=3449 read=4333
              ->  Sort  (cost=10737.31..10737.64 rows=132 width=48) (actual time=105.411..105.413 rows=23.33 loops=3)
                    Sort Key: d.year_month
                    Sort Method: quicksort  Memory: 27kB
                    Buffers: shared hit=3449 read=4333
                    Worker 0:  Sort Method: quicksort  Memory: 27kB
                    Worker 1:  Sort Method: quicksort  Memory: 27kB
                    ->  Partial HashAggregate  (cost=10731.01..10732.66 rows=132 width=48) (actual time=105.323..105.334 rows=23.33 loops=3)
                          Group Key: d.year_month
                          Batches: 1  Memory Usage: 32kB
                          Buffers: shared hit=3435 read=4333
                          Worker 0:  Batches: 1  Memory Usage: 32kB
                          Worker 1:  Batches: 1  Memory Usage: 32kB
                          ->  Hash Join  (cost=141.81..9938.63 rows=105650 width=14) (actual time=1.938..67.335 rows=143277.33 loops=3)
                                Hash Cond: (fc.date_key = d.date_key)
                                Buffers: shared hit=3435 read=4333
                                ->  Parallel Seq Scan on fact_claim fc  (cost=0.00..9326.15 rows=179115 width=10) (actual time=0.598..16.088 rows=143291.67 loops=3)
                                      Buffers: shared hit=3203 read=4332
                                ->  Hash  (cost=112.18..112.18 rows=2370 width=12) (actual time=1.309..1.309 rows=2370.00 loops=3)
                                      Buckets: 4096  Batches: 1  Memory Usage: 134kB
                                      Buffers: shared hit=232 read=1
                                      ->  Index Scan using dim_date_full_date_key on dim_date d  (cost=0.28..112.18 rows=2370 width=12) (actual time=0.212..0.942 rows=2370.00 loops=3)
                                            Index Cond: (full_date >= (CURRENT_DATE - '2 years'::interval))
                                            Index Searches: 3
                                            Buffers: shared hit=232 read=1
Planning:
  Buffers: shared hit=371
Planning Time: 6.171 ms
Execution Time: 156.394 ms
```

## Interpretation: 
This query aggregates 24 months of claims and calculates 3-month rolling averages. Postgres uses 2 parallel workers to scan fact_claim, joining ∼430K total rows to dim_date using an index on full_date >= CURRENT_DATE - '2 years'. Each worker does a Partial HashAggregate by year_month, then the results are merged and finalized into 24 month buckets. WindowAgg computes the rolling averages in memory over just 24 rows. With read=4333 buffers and 156ms runtime, it’s fast for ad-hoc use but still touches the 2M-row fact table on every run.

## Most Expensive Node: 
Parallel Seq Scan on fact_claim fc drives cost: cost=0.00..9326.15, actual time=16ms per worker, read=4332 buffers. It reads ∼21% of the table for 24 months of data. The planner is correct to use a seq scan at this selectivity, but that’s still 4K disk pages every execution.


---


## EXPLAIN Output After: Materialized View
```text
Seq Scan on mv_monthly_claims_summary  (cost=0.00..1.24 rows=24 width=136) (actual time=0.026..0.027 rows=24.00 loops=1)
  Buffers: shared hit=1
Planning:
  Buffers: shared hit=33 read=1
Planning Time: 1.240 ms
Execution Time: 0.036 ms
```

### Interpretation: 
Querying the materialized view mv_monthly_claims_summary returns the same 24 pre-aggregated rows in 0.036ms vs 156ms. It’s a single sequential scan of 1 page because the aggregation, joins, and window functions are already computed. No parallelism, no sorting, no I/O on fact_claim. The 4300x speedup comes from eliminating the scan + aggregation at query time.

### Most Expensive Node: 
Seq Scan on mv_monthly_claims_summary. There’s only one node, and it’s trivial: actual time=0.026 ms, Buffers: shared hit=1. The view fits in one 8KB page and was in cache.


---

## Refresh Schedule Recommendation


| Schedule | Command | Justification |
| --- | --- | --- |
| Daily, 2:00 AM | `REFRESH MATERIALIZED VIEW CONCURRENTLY dw.mv_monthly_claims_summary;` | **Data latency tolerance**: The query is monthly granularity with a 3-month rolling average. Intra-day changes don’t affect the result until the next month closes. Refreshing after nightly ETL/loads ensures consistency.<br><br>**Query cost delta**: Base query = 156ms and 4,333 disk reads. MV = 0.036ms and 1 buffer hit. If this dashboard/API is hit 1K+ times/day, you save ∼150s CPU and ∼4M buffer reads daily.<br><br>**CONCURRENTLY**: Lets you refresh without locking reads. Requires a unique index on `year_month`.<br><br>**Staleness**: Claims can backfill, but 99% land within 30 days. Daily refresh catches late arrivals fast enough for exec reporting. If you need intra-month, add a view-union with current month from base tables. |