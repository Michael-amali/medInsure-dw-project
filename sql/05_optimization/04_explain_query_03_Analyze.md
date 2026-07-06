```text
Sort  (cost=108569.19..108570.51 rows=528 width=60) (actual time=6926.617..6936.429 rows=24.00 loops=1)
  Sort Key: mc.year_month, mc.plan_type
  Sort Method: quicksort  Memory: 26kB
  Buffers: shared hit=10253 read=14723, temp read=1914 written=1921
  ->  Merge Left Join  (cost=103206.85..108545.31 rows=528 width=60) (actual time=5889.882..6936.241 rows=24.00 loops=1)
        Merge Cond: (((mc.plan_type)::text = (dim_member.plan_type)::text) AND (((mc.year_month)::text) = (to_char((dim_member.effective_start)::timestamp with time zone, 'YYYY-MM'::text))))
        Buffers: shared hit=10253 read=14723, temp read=1914 written=1921
        ->  Incremental Sort  (cost=24382.31..24558.13 rows=528 width=20) (actual time=583.815..593.646 rows=24.00 loops=1)
              Sort Key: mc.plan_type, ((mc.year_month)::text)
              Presorted Key: mc.plan_type
              Full-sort Groups: 1  Sort Method: quicksort  Average Memory: 26kB  Peak Memory: 26kB
              Buffers: shared hit=6268 read=10095
              ->  Subquery Scan on mc  (cost=24381.48..24543.83 rows=528 width=20) (actual time=583.622..593.512 rows=24.00 loops=1)
                    Buffers: shared hit=6268 read=10095
                    ->  Finalize GroupAggregate  (cost=24381.48..24543.83 rows=528 width=20) (actual time=583.064..592.944 rows=24.00 loops=1)
                          Group Key: dm.plan_type, d.year_month
                          Buffers: shared hit=6268 read=10095
                          ->  Gather Merge  (cost=24381.48..24529.05 rows=1267 width=20) (actual time=583.058..592.909 rows=72.00 loops=1)
                                Workers Planned: 2
                                Workers Launched: 2
                                Buffers: shared hit=6268 read=10095
                                ->  Sort  (cost=23381.46..23382.78 rows=528 width=20) (actual time=520.649..520.656 rows=24.00 loops=3)
                                      Sort Key: dm.plan_type, d.year_month
                                      Sort Method: quicksort  Memory: 25kB
                                      Buffers: shared hit=6268 read=10095
                                      Worker 0:  Sort Method: quicksort  Memory: 25kB
                                      Worker 1:  Sort Method: quicksort  Memory: 25kB
                                      ->  Partial HashAggregate  (cost=23352.30..23357.58 rows=528 width=20) (actual time=520.562..520.576 rows=24.00 loops=3)
                                            Group Key: dm.plan_type, d.year_month
                                            Batches: 1  Memory Usage: 49kB
                                            Buffers: shared hit=6238 read=10095
                                            Worker 0:  Batches: 1  Memory Usage: 49kB
                                            Worker 1:  Batches: 1  Memory Usage: 49kB
                                            ->  Parallel Hash Join  (cost=10925.04..22741.80 rows=81400 width=12) (actual time=126.609..479.469 rows=136447.67 loops=3)
                                                  Hash Cond: (dm.member_key = fc.member_key)
                                                  Buffers: shared hit=6238 read=10095
                                                  ->  Parallel Seq Scan on dim_member dm  (cost=0.00..10696.34 rows=208334 width=12) (actual time=0.898..247.504 rows=166667.00 loops=3)
                                                        Buffers: shared hit=3703 read=4910
                                                  ->  Parallel Hash  (cost=9907.54..9907.54 rows=81400 width=16) (actual time=124.772..124.774 rows=136447.67 loops=3)
                                                        Buckets: 524288 (originally 262144)  Batches: 1 (originally 1)  Memory Usage: 25408kB
                                                        Buffers: shared hit=2535 read=5185
                                                        ->  Hash Join  (cost=110.72..9907.54 rows=81400 width=16) (actual time=2.874..75.111 rows=136447.67 loops=3)
                                                              Hash Cond: (fc.date_key = d.date_key)
                                                              Buffers: shared hit=2535 read=5185
                                                              ->  Parallel Seq Scan on fact_claim fc  (cost=0.00..9326.15 rows=179115 width=12) (actual time=0.673..20.229 rows=143291.67 loops=3)
                                                                    Buffers: shared hit=2357 read=5178
                                                              ->  Hash  (cost=87.89..87.89 rows=1826 width=12) (actual time=2.175..2.176 rows=1826.00 loops=3)
                                                                    Buckets: 2048  Batches: 1  Memory Usage: 95kB
                                                                    Buffers: shared hit=178 read=7
                                                                    ->  Index Scan using dim_date_full_date_key on dim_date d  (cost=0.29..87.89 rows=1826 width=12) (actual time=0.434..1.699 rows=1826.00 loops=3)
                                                                          Index Cond: (full_date >= date_trunc('year'::text, (CURRENT_DATE)::timestamp with time zone))
                                                                          Index Searches: 3
                                                                          Buffers: shared hit=178 read=7
        ->  GroupAggregate  (cost=78824.54..83893.85 rows=4620 width=44) (actual time=5150.580..6341.803 rows=168.00 loops=1)
              Group Key: dim_member.plan_type, (to_char((dim_member.effective_start)::timestamp with time zone, 'YYYY-MM'::text))
              Buffers: shared hit=3985 read=4628, temp read=1914 written=1921
              ->  Sort  (cost=78824.54..80074.54 rows=500001 width=45) (actual time=5149.825..6051.357 rows=500000.00 loops=1)
                    Sort Key: dim_member.plan_type, (to_char((dim_member.effective_start)::timestamp with time zone, 'YYYY-MM'::text)), dim_member.member_id
                    Sort Method: external merge  Disk: 15312kB
                    Buffers: shared hit=3985 read=4628, temp read=1914 written=1921
                    ->  Seq Scan on dim_member  (cost=0.00..16113.01 rows=500001 width=45) (actual time=1.956..554.012 rows=500000.00 loops=1)
                          Filter: is_current
                          Rows Removed by Filter: 1
                          Buffers: shared hit=3985 read=4628
Planning:
  Buffers: shared hit=522 read=14
Planning Time: 57.047 ms
Execution Time: 6977.134 ms
```


## Plain English Interpretation
This query runs in 7 seconds and compares monthly claim counts to member counts by plan_type. The left side uses 2 parallel workers to scan fact_claim and dim_member, hash join them, and aggregate to 24 rows for current-year months. The right side does a full scan of 500K dim_member rows, sorts them on disk using 15MB of temp space, then aggregates to 168 month/plan buckets. Those two streams are merge-joined and sorted for the final 24-row output. With read=14723 buffers and temp written=1921, the query is I/O heavy and spills to disk on the member side.

## Most Expensive Node
Sort with Sort Method: external merge Disk: 15312kB is the most expensive: actual time=5149.825..6051.357 ms, or ∼87% of total runtime. It’s sorting 500,000 dim_member rows by plan_type, to_char(effective_start, 'YYYY-MM'), and member_id so GroupAggregate can compute member counts per plan-month. Because that sort doesn’t fit in work_mem, Postgres spills 15MB to disk, shown by temp read=1914 written=1921. The left branch aggregates in ∼593ms, so the right branch sort is the bottleneck.

Fix: Either bump work_mem to avoid the disk sort, or pre-aggregate dim_member into a monthly snapshot table so you don’t sort 500K rows on the fly.



