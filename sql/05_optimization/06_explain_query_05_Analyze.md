```text
GroupAggregate  (cost=34548.58..62017.12 rows=33 width=97) (actual time=1841.861..2423.334 rows=4.00 loops=1)
  Group Key: d.year_number, dp.network_status
  Buffers: shared hit=7882 read=9148, temp read=12144 written=12226
  ->  Gather Merge  (cost=34548.58..59354.07 rows=212984 width=32) (actual time=1825.001..2320.302 rows=391254.00 loops=1)
        Workers Planned: 2
        Workers Launched: 2
        Buffers: shared hit=7882 read=9148, temp read=12144 written=12226
        ->  Sort  (cost=33548.56..33770.41 rows=88743 width=32) (actual time=1669.229..1779.409 rows=130418.00 loops=3)
              Sort Key: d.year_number, dp.network_status, dm.member_id
              Sort Method: external merge  Disk: 6224kB
              Buffers: shared hit=7882 read=9148, temp read=12144 written=12226
              Worker 0:  Sort Method: external merge  Disk: 5648kB
              Worker 1:  Sort Method: external merge  Disk: 4608kB
              ->  Hash Join  (cost=12050.19..24130.56 rows=88743 width=32) (actual time=338.834..814.680 rows=130418.00 loops=3)
                    Hash Cond: (fc.provider_key = dp.provider_key)
                    Buffers: shared hit=7852 read=9148, temp read=10084 written=10160
                    ->  Parallel Hash Join  (cost=11478.67..23326.02 rows=88743 width=27) (actual time=329.841..753.028 rows=130418.00 loops=3)
                          Hash Cond: (dm.member_key = fc.member_key)
                          Buffers: shared hit=7150 read=9148, temp read=10084 written=10160
                          ->  Parallel Seq Scan on dim_member dm  (cost=0.00..10696.34 rows=208334 width=17) (actual time=0.338..22.006 rows=166667.00 loops=3)
                                Buffers: shared hit=4079 read=4534
                          ->  Parallel Hash  (cost=10369.38..10369.38 rows=88743 width=26) (actual time=170.894..170.896 rows=130418.00 loops=3)
                                Buckets: 131072 (originally 262144)  Batches: 8 (originally 1)  Memory Usage: 4128kB
                                Buffers: shared hit=3071 read=4614, temp written=2052
                                ->  Hash Join  (cost=167.79..10369.38 rows=88743 width=26) (actual time=4.123..90.826 rows=130418.00 loops=3)
                                      Hash Cond: (fc.date_key = d.date_key)
                                      Buffers: shared hit=3071 read=4614
                                      ->  Parallel Seq Scan on fact_claim fc  (cost=0.00..9773.93 rows=162743 width=26) (actual time=0.772..47.440 rows=130451.00 loops=3)
                                            Filter: ((claim_status)::text = 'Paid'::text)
                                            Rows Removed by Filter: 12841
                                            Buffers: shared hit=2921 read=4614
                                      ->  Hash  (cost=140.41..140.41 rows=2191 width=8) (actual time=3.317..3.317 rows=2191.00 loops=3)
                                            Buckets: 4096  Batches: 1  Memory Usage: 118kB
                                            Buffers: shared hit=150
                                            ->  Seq Scan on dim_date d  (cost=0.00..140.41 rows=2191 width=8) (actual time=1.538..2.783 rows=2191.00 loops=3)
                                                  Filter: (year_number >= ((EXTRACT(year FROM CURRENT_DATE))::integer - 1))
                                                  Rows Removed by Filter: 1827
                                                  Buffers: shared hit=150
                    ->  Hash  (cost=384.01..384.01 rows=15001 width=21) (actual time=8.917..8.917 rows=15001.00 loops=3)
                          Buckets: 16384  Batches: 1  Memory Usage: 949kB
                          Buffers: shared hit=702
                          ->  Seq Scan on dim_provider dp  (cost=0.00..384.01 rows=15001 width=21) (actual time=0.659..4.876 rows=15001.00 loops=3)
                                Buffers: shared hit=702
Planning:
  Buffers: shared hit=512
Planning Time: 14.205 ms
Execution Time: 2449.078 ms
```





## Plain English Interpretation
This query runs in 2.45s and aggregates paid claims by year and provider network status for 2025-2026. Postgres uses 2 parallel workers to scan fact_claim, filter to Paid, and hash join it to dim_date, dim_member, and dim_provider. The join outputs 391K rows, which then need to be sorted by year_number, network_status, member_id before the GroupAggregate can roll them up to just 4 summary rows. Because the 391K rows didn’t fit in work_mem, each worker spilled to disk and did an external merge sort. With read=9148 buffers and 12MB of temp writes, the plan is I/O and sort bound.

## Most Expensive Node
Sort with Sort Method: external merge Disk: 6224kB is the most expensive: actual time=1669.229..1779.409 ms, about 73% of total runtime. It’s sorting 391,254 rows across 3 parallel processes before GroupAggregate can run. The sort spilled to disk on all workers, shown by temp read=12144 written=12226. The root cause is that GROUP BY d.year_number, dp.network_status doesn’t require member_id in the sort key, but the planner added it, likely because of a COUNT(DISTINCT dm.member_id) or similar in the original query.

Fix: If you’re doing COUNT(DISTINCT member_id), replace it with a HashAggregate by raising work_mem, or pre-aggregate in a CTE. Also check if you have idx_fact_claim_date_provider_member so the data comes back pre-sorted and Postgres can skip the disk sort.
