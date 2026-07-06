```text
Sort  (cost=11839.01..11839.02 rows=7 width=105) (actual time=220.633..229.690 rows=20.00 loops=1)
  Sort Key: (round((((sum(CASE WHEN ((fc.claim_status)::text = 'Denied'::text) THEN 1 ELSE 0 END))::numeric * 100.0) / (count(*))::numeric), 2)) DESC
  Sort Method: quicksort  Memory: 26kB
  Buffers: shared hit=3510 read=4896
  ->  Finalize GroupAggregate  (cost=11831.52..11838.91 rows=7 width=105) (actual time=220.512..229.659 rows=20.00 loops=1)
        Group Key: dp.specialty, fc.claim_type
        Filter: (count(*) > 100)
        Buffers: shared hit=3507 read=4896
        ->  Gather Merge  (cost=11831.52..11837.70 rows=53 width=73) (actual time=220.481..229.571 rows=60.00 loops=1)
              Workers Planned: 2
              Workers Launched: 2
              Buffers: shared hit=3507 read=4896
              ->  Sort  (cost=10831.50..10831.55 rows=22 width=73) (actual time=175.105..175.109 rows=20.00 loops=3)
                    Sort Key: dp.specialty, fc.claim_type
                    Sort Method: quicksort  Memory: 27kB
                    Buffers: shared hit=3507 read=4896
                    Worker 0:  Sort Method: quicksort  Memory: 27kB
                    Worker 1:  Sort Method: quicksort  Memory: 27kB
                    ->  Partial HashAggregate  (cost=10830.73..10831.01 rows=22 width=73) (actual time=175.026..175.037 rows=20.00 loops=3)
                          Group Key: dp.specialty, fc.claim_type
                          Batches: 1  Memory Usage: 32kB
                          Buffers: shared hit=3491 read=4896
                          Worker 0:  Batches: 1  Memory Usage: 32kB
                          Worker 1:  Batches: 1  Memory Usage: 32kB
                          ->  Hash Join  (cost=706.45..10545.99 rows=16271 width=36) (actual time=10.773..110.085 rows=136447.67 loops=3)
                                Hash Cond: (fc.provider_key = dp.provider_key)
                                Buffers: shared hit=3491 read=4896
                                ->  Hash Join  (cost=134.92..9931.75 rows=16271 width=32) (actual time=3.287..68.975 rows=136447.67 loops=3)
                                      Hash Cond: (fc.date_key = d.date_key)
                                      Buffers: shared hit=2789 read=4896
                                      ->  Parallel Seq Scan on fact_claim fc  (cost=0.00..9326.15 rows=179115 width=36) (actual time=0.701..18.339 rows=143291.67 loops=3)
                                            Buffers: shared hit=2639 read=4896
                                      ->  Hash  (cost=130.36..130.36 rows=365 width=4) (actual time=2.569..2.570 rows=365.00 loops=3)
                                            Buckets: 1024  Batches: 1  Memory Usage: 21kB
                                            Buffers: shared hit=150
                                            ->  Seq Scan on dim_date d  (cost=0.00..130.36 rows=365 width=4) (actual time=1.567..2.476 rows=365.00 loops=3)
                                                  Filter: (year_number = (EXTRACT(year FROM CURRENT_DATE))::integer)
                                                  Rows Removed by Filter: 3653
                                                  Buffers: shared hit=150
                                ->  Hash  (cost=384.01..384.01 rows=15001 width=20) (actual time=7.396..7.397 rows=15001.00 loops=3)
                                      Buckets: 16384  Batches: 1  Memory Usage: 948kB
                                      Buffers: shared hit=702
                                      ->  Seq Scan on dim_provider dp  (cost=0.00..384.01 rows=15001 width=20) (actual time=0.408..3.901 rows=15001.00 loops=3)
                                            Buffers: shared hit=702
Planning:
  Buffers: shared hit=519
Planning Time: 25.760 ms
Execution Time: 230.034 ms
```


## Plain English Interpretation
This query runs in 230ms and calculates denial rates by provider specialty and claim type for the current year. Postgres used 2 parallel workers to scan fact_claim, joined to dim_date to filter 2026, then to dim_provider. Each worker did a Partial HashAggregate on 143K rows to get specialty/claim_type counts and denied counts, then the leader merged and finalized the aggregates. The Filter: (count(*) > 100) removed low-volume groups, leaving 20 rows which were sorted by denial rate DESC. With read=4896 buffers, about 58% of reads were from disk, but the whole thing stayed in memory with no temp spills.

## Most Expensive Node
Parallel Seq Scan on fact_claim fc + the Hash Join above it are the cost drivers. The seq scan reads 4,896 disk pages in ∼18ms per worker, ∼429K rows total. The subsequent Hash Join to dim_date takes another 50ms and outputs 409K rows across 3 loops. Together they feed 136K rows per worker into the Partial HashAggregate, which runs in 175ms. The scan is expensive because you’re pulling ∼21% of the 2M-row table for one year of data, and the planner still chooses a sequential scan over an index due to that selectivity.

Optimization angle: An index on fact_claim(date_key, provider_key) INCLUDE (claim_status, claim_type) would help if you queried smaller date ranges. For a full year, seq scan is still optimal.




