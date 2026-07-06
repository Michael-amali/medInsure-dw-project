```text
WindowAgg  (cost=60700.56..60701.52 rows=49 width=120) (actual time=12461.211..12504.162 rows=6.00 loops=1)
  Window: w1 AS (ORDER BY (sum(fcl.paid_amount)) ROWS UNBOUNDED PRECEDING)
  Storage: Memory  Maximum Storage: 17kB
  Buffers: shared hit=1249 read=24240, temp read=13177 written=13216
  ->  Sort  (cost=60700.54..60700.67 rows=49 width=112) (actual time=12461.162..12504.087 rows=6.00 loops=1)
        Sort Key: (sum(fcl.paid_amount)) DESC
        Sort Method: quicksort  Memory: 25kB
        Buffers: shared hit=1249 read=24240, temp read=13177 written=13216
        ->  GroupAggregate  (cost=42173.12..60699.17 rows=49 width=112) (actual time=6895.375..12504.015 rows=6.00 loops=1)
              Group Key: ddg.diagnosis_category, ddg.icd_chapter
              Buffers: shared hit=1246 read=24240, temp read=13177 written=13216
              ->  Gather Merge  (cost=42173.12..59233.59 rows=146484 width=58) (actual time=5808.633..11279.673 rows=1535599.00 loops=1)
                    Workers Planned: 2
                    Workers Launched: 2
                    Buffers: shared hit=1246 read=24240, temp read=13177 written=13216
                    ->  Sort  (cost=41173.09..41325.68 rows=61035 width=58) (actual time=5669.435..7620.664 rows=511866.33 loops=3)
                          Sort Key: ddg.diagnosis_category, ddg.icd_chapter, fcl.claim_id
                          Sort Method: external merge  Disk: 34952kB
                          Buffers: shared hit=1246 read=24240, temp read=13177 written=13216
                          Worker 0:  Sort Method: external merge  Disk: 35312kB
                          Worker 1:  Sort Method: external merge  Disk: 35152kB
                          ->  Hash Join  (cost=576.95..34025.62 rows=61035 width=58) (actual time=13.218..565.613 rows=511866.33 loops=3)
                                Hash Cond: (fcl.diagnosis_key = ddg.diagnosis_key)
                                Buffers: shared hit=1230 read=24240
                                ->  Hash Join  (cost=134.92..33423.32 rows=61035 width=22) (actual time=3.872..324.768 rows=511866.33 loops=3)
                                      Hash Cond: (fcl.date_key = d.date_key)
                                      Buffers: shared hit=714 read=24240
                                      ->  Parallel Seq Scan on fact_claim_line fcl  (cost=0.00..31522.85 rows=671885 width=26) (actual time=1.107..67.713 rows=537507.67 loops=3)
                                            Buffers: shared hit=564 read=24240
                                      ->  Hash  (cost=130.36..130.36 rows=365 width=4) (actual time=2.736..2.737 rows=365.00 loops=3)
                                            Buckets: 1024  Batches: 1  Memory Usage: 21kB
                                            Buffers: shared hit=150
                                            ->  Seq Scan on dim_date d  (cost=0.00..130.36 rows=365 width=4) (actual time=1.670..2.644 rows=365.00 loops=3)
                                                  Filter: (year_number = (EXTRACT(year FROM CURRENT_DATE))::integer)
                                                  Rows Removed by Filter: 3653
                                                  Buffers: shared hit=150
                                ->  Hash  (cost=292.01..292.01 rows=12001 width=44) (actual time=9.206..9.207 rows=12001.00 loops=3)
                                      Buckets: 16384  Batches: 1  Memory Usage: 1050kB
                                      Buffers: shared hit=516
                                      ->  Seq Scan on dim_diagnosis ddg  (cost=0.00..292.01 rows=12001 width=44) (actual time=0.542..4.748 rows=12001.00 loops=3)
                                            Buffers: shared hit=516
Planning:
  Buffers: shared hit=410
Planning Time: 18.106 ms
Execution Time: 12539.599 ms

```


## Plain English Interpretation
This query took 12.5 seconds to aggregate 7.5M claim lines by diagnosis category for the current year. Postgres used 2 parallel workers to scan fact_claim_line, hash joined it to dim_date to filter 2026 rows, then to dim_diagnosis. Because 1.5M rows came out of the join, Postgres couldn’t sort them in memory and spilled to disk: each worker did an external merge sort using ∼35MB of temp files. After sorting, it aggregated down to 6 diagnosis categories, sorted again for the final ranking, and applied the WindowAgg. With read=24240 buffers and 13MB of temp writes, the plan is both I/O and CPU bound.

## Most Expensive Node
Sort with Sort Method: external merge Disk: 34952kB is the most expensive: actual time=5669.435..7620.664 ms, roughly 61% of total runtime. It’s sorting 1.5M rows by diagnosis_category, icd_chapter, claim_id before the GroupAggregate. Because the dataset didn’t fit in work_mem, each of the 3 parallel workers spilled ∼35MB to disk, causing temp read=13177 written=13216 blocks. The child Parallel Seq Scan on fact_claim_line is fast at 68ms, but the downstream sort can’t keep up.

Fix: Increase work_mem so the sort stays in memory, or add an index on fact_claim_line(date_key, diagnosis_key) INCLUDE (paid_amount) and pre-aggregate with GROUP BY to avoid sorting 1.5M rows.



