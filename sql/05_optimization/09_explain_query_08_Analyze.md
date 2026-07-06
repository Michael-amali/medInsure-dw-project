```text
Sort  (cost=20551.76..20581.32 rows=11827 width=125) (actual time=1250.043..1250.053 rows=225.00 loops=1)
  Sort Key: with_running_total.provider_name, with_running_total.full_date
  Sort Method: quicksort  Memory: 39kB
  Buffers: shared hit=4063 read=3768, temp read=7606 written=10072
  ->  Subquery Scan on with_running_total  (cost=18480.29..19751.67 rows=11827 width=125) (actual time=991.929..1249.618 rows=225.00 loops=1)
        Filter: (with_running_total.ytd_cumulative_paid > '150000'::numeric)
        Rows Removed by Filter: 326487
        Buffers: shared hit=4057 read=3768, temp read=7606 written=10072
        ->  WindowAgg  (cost=18480.29..19278.59 rows=35481 width=105) (actual time=981.659..1229.410 rows=326712.00 loops=1)
              Window: w1 AS (PARTITION BY daily_provider_paid.provider_key, daily_provider_paid.year_number ORDER BY daily_provider_paid.full_date ROWS UNBOUNDED PRECEDING)
              Storage: Memory  Maximum Storage: 17kB
              Buffers: shared hit=4057 read=3768, temp read=7606 written=10072
              ->  Sort  (cost=18480.27..18568.97 rows=35481 width=73) (actual time=981.636..1050.923 rows=326712.00 loops=1)
                    Sort Key: daily_provider_paid.provider_key, daily_provider_paid.year_number, daily_provider_paid.full_date
                    Sort Method: external merge  Disk: 18976kB
                    Buffers: shared hit=4057 read=3768, temp read=7606 written=10072
                    ->  Subquery Scan on daily_provider_paid  (cost=15000.51..15798.83 rows=35481 width=73) (actual time=409.295..815.903 rows=326712.00 loops=1)
                          Buffers: shared hit=4051 read=3768, temp read=5234 written=7693
                          ->  HashAggregate  (cost=15000.51..15444.02 rows=35481 width=73) (actual time=409.293..790.143 rows=326712.00 loops=1)
                                Group Key: dp.provider_key, d.full_date
                                Batches: 37  Memory Usage: 8281kB  Disk Usage: 26200kB
                                Buffers: shared hit=4051 read=3768, temp read=5234 written=7693
                                ->  Hash Join  (cost=706.45..14734.40 rows=35481 width=47) (actual time=9.504..243.403 rows=372654.00 loops=1)
                                      Hash Cond: (fc.provider_key = dp.provider_key)
                                      Buffers: shared hit=4051 read=3768
                                      ->  Hash Join  (cost=134.92..14069.72 rows=35481 width=22) (actual time=2.200..159.567 rows=372654.00 loops=1)
                                            Hash Cond: (fc.date_key = d.date_key)
                                            Buffers: shared hit=3817 read=3768
                                            ->  Seq Scan on fact_claim fc  (cost=0.00..12908.44 rows=390584 width=18) (actual time=0.300..84.687 rows=391353.00 loops=1)
                                                  Filter: ((claim_status)::text = 'Paid'::text)
                                                  Rows Removed by Filter: 38522
                                                  Buffers: shared hit=3767 read=3768
                                            ->  Hash  (cost=130.36..130.36 rows=365 width=12) (actual time=1.882..1.883 rows=365.00 loops=1)
                                                  Buckets: 1024  Batches: 1  Memory Usage: 24kB
                                                  Buffers: shared hit=50
                                                  ->  Seq Scan on dim_date d  (cost=0.00..130.36 rows=365 width=12) (actual time=0.834..1.805 rows=365.00 loops=1)
                                                        Filter: (year_number = (EXTRACT(year FROM CURRENT_DATE))::integer)
                                                        Rows Removed by Filter: 3653
                                                        Buffers: shared hit=50
                                      ->  Hash  (cost=384.01..384.01 rows=15001 width=33) (actual time=7.217..7.218 rows=15001.00 loops=1)
                                            Buckets: 16384  Batches: 1  Memory Usage: 1099kB
                                            Buffers: shared hit=234
                                            ->  Seq Scan on dim_provider dp  (cost=0.00..384.01 rows=15001 width=33) (actual time=0.095..3.482 rows=15001.00 loops=1)
                                                  Buffers: shared hit=234
Planning:
  Buffers: shared hit=369
Planning Time: 41.784 ms
Execution Time: 1285.289 ms
```




## Plain English Interpretation
This query runs in 1.29s and finds all provider-days in 2026 where YTD cumulative paid > $150K. Postgres first hash joins 391K Paid claims to dim_date and dim_provider. It then does a HashAggregate to get daily totals per provider, but the aggregate spills to disk: Batches: 37 Disk Usage: 26200kB. The 327K daily rows are sorted to disk again with external merge Disk: 18976kB so the WindowAgg can compute the running YTD total. The outer filter ytd_cumulative_paid > 150000 removes 326,487 rows, leaving 225. With temp written=10072 blocks and read=3768, the query is I/O and sort bound due to disk spills.

## Most Expensive Node
HashAggregate with Batches: 37 Disk Usage: 26200kB is the most expensive: actual time=409.293..790.143 ms plus heavy temp I/O. It’s grouping 373K rows by provider_key, full_date to produce 327K daily provider aggregates. Because work_mem is too small, Postgres had to spill to 37 batches and 26MB of disk. The child Sort is also costly at 1.05s because it spills another 19MB to disk.

Fix: Increase work_mem so the HashAggregate stays in memory and uses fewer batches. If that’s not possible, pre-aggregate to provider_key, date_key before joining to dim_date, or materialize a daily summary table. Also consider adding claim_status to the covering index so the Seq Scan on fact_claim can become an Index Only Scan if you filter to fewer months.





