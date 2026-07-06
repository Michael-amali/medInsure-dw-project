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


## Plain English Interpretation
This query aggregates monthly claim metrics for the last 2 years and adds a 3-month moving average, finishing in 156ms. Postgres uses 2 parallel workers to scan fact_claim and joins it to dim_date using an index on full_date to filter the 2-year window, pulling ∼143K rows per worker. Each worker does a Partial HashAggregate by year_month, the results are merged, then a final GroupAggregate produces 24 month buckets. The WindowAgg computes the rolling average over those 24 rows in memory. With only read=4333 buffers and no disk spill, the plan is CPU-bound and efficient.

## Most Expensive Node
Parallel Seq Scan on fact_claim fc is the cost driver: cost=0.00..9326.15 and it accounts for most of the I/O with read=4332 buffers. It’s scanning the entire fact table in parallel and passing 430K total rows to the hash join, taking ∼16ms per worker. Because you’re querying 24 months of data, ∼21% of the 2M-row table, the planner correctly chose a sequential scan over an index scan on date_key. If you filtered to a smaller window, the covering index idx_fact_claim_provider_date_cov could be used for an Index Only Scan.




