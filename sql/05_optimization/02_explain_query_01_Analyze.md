```text
Limit  (cost=37133.23..37133.88 rows=20 width=772) (actual time=549.260..549.290 rows=20.00 loops=1)
  Buffers: shared hit=2456 read=5366
  CTE yearly_provider
    ->  HashAggregate  (cost=21613.71..23609.51 rows=70962 width=69) (actual time=517.996..525.273 rows=15706.00 loops=1)
          Group Key: dp.provider_name, dp.specialty, dd.year_number
          Planned Partitions: 4  Batches: 1  Memory Usage: 6673kB
          Buffers: shared hit=2453 read=5366
          ->  Hash Join  (cost=751.19..14872.32 rows=70962 width=35) (actual time=21.902..332.419 rows=391254.00 loops=1)
                Hash Cond: (fc.provider_key = dp.provider_key)
                Buffers: shared hit=2453 read=5366
                ->  Hash Join  (cost=179.66..14114.46 rows=70962 width=18) (actual time=8.124..220.513 rows=391254.00 loops=1)
                      Hash Cond: (fc.date_key = dd.date_key)
                      Buffers: shared hit=2219 read=5366
                      ->  Seq Scan on fact_claim fc  (cost=0.00..12908.44 rows=390584 width=18) (actual time=2.288..115.575 rows=391353.00 loops=1)
                            Filter: ((claim_status)::text = 'Paid'::text)
                            Rows Removed by Filter: 38522
                            Buffers: shared hit=2169 read=5366
                      ->  Hash  (cost=170.54..170.54 rows=730 width=8) (actual time=5.735..5.735 rows=730.00 loops=1)
                            Buckets: 1024  Batches: 1  Memory Usage: 37kB
                            Buffers: shared hit=50
                            ->  Seq Scan on dim_date dd  (cost=0.00..170.54 rows=730 width=8) (actual time=2.663..5.486 rows=730.00 loops=1)
                                  Filter: (year_number = ANY (ARRAY[(EXTRACT(year FROM CURRENT_DATE))::integer, ((EXTRACT(year FROM CURRENT_DATE))::integer - 1)]))
                                  Rows Removed by Filter: 3288
                                  Buffers: shared hit=50
                ->  Hash  (cost=384.01..384.01 rows=15001 width=33) (actual time=13.456..13.456 rows=15001.00 loops=1)
                      Buckets: 16384  Batches: 1  Memory Usage: 1145kB
                      Buffers: shared hit=234
                      ->  Seq Scan on dim_provider dp  (cost=0.00..384.01 rows=15001 width=33) (actual time=0.058..6.526 rows=15001.00 loops=1)
                            Buffers: shared hit=234
  ->  WindowAgg  (cost=13523.72..13544.17 rows=630 width=772) (actual time=549.259..549.283 rows=20.00 loops=1)
        Window: w1 AS (ORDER BY cy.paid_amount ROWS UNBOUNDED PRECEDING)
        Storage: Memory  Maximum Storage: 17kB
        Buffers: shared hit=2456 read=5366
        ->  Sort  (cost=13523.70..13525.27 rows=630 width=700) (actual time=549.233..549.236 rows=20.00 loops=1)
              Sort Key: cy.paid_amount DESC
              Sort Method: quicksort  Memory: 1118kB
              Buffers: shared hit=2456 read=5366
              ->  Hash Right Join  (cost=2134.18..13494.40 rows=630 width=700) (actual time=537.519..543.564 rows=13317.00 loops=1)
                    Hash Cond: (((py.provider_name)::text = (cy.provider_name)::text) AND (py.year_number = (cy.year_number - 1)))
                    Buffers: shared hit=2453 read=5366
                    ->  CTE Scan on yearly_provider py  (cost=0.00..1419.24 rows=70962 width=454) (actual time=0.001..1.103 rows=15706.00 loops=1)
                          Storage: Memory  Maximum Storage: 1311kB
                    ->  Hash  (cost=2128.86..2128.86 rows=355 width=672) (actual time=537.496..537.497 rows=13317.00 loops=1)
                          Buckets: 16384 (originally 1024)  Batches: 1 (originally 1)  Memory Usage: 1077kB
                          Buffers: shared hit=2453 read=5366
                          ->  CTE Scan on yearly_provider cy  (cost=0.00..2128.86 rows=355 width=672) (actual time=518.003..534.044 rows=13317.00 loops=1)
                                Filter: (year_number = (EXTRACT(year FROM CURRENT_DATE))::integer)
                                Rows Removed by Filter: 2389
                                Storage: Memory  Maximum Storage: 1311kB
                                Buffers: shared hit=2453 read=5366
Planning:
  Buffers: shared hit=522
Planning Time: 103.756 ms
Execution Time: 551.356 ms
```






## Plain English Interpretation
The query completes in 551ms and scans 391K paid claims from fact_claim to build YoY provider totals. Postgres first hashes dim_date for 2 years and dim_provider for 15K providers, hash joins both to fact_claim, then aggregates to 15.7K provider-year rows in the CTE. After that it self-joins the CTE to compare years, sorts 13.3K current-year providers by spend, applies RANK(), and returns the top 20. With read=5366 buffers, about 68% of the I/O is from disk, so this plan is I/O bound now that fact_claim has 2M rows.

## Most Expensive Node
HashAggregate is the most expensive node: cost=21613.71..23609.51 and actual time=517.996..525.273 ms, which is ∼94% of total execution time. It’s grouping 391,254 rows from the joins into 15,706 buckets by provider_name, specialty, year_number and computing SUM(total_paid) and COUNT(*). The child Seq Scan on fact_claim is the I/O driver, reading 5,366 pages from disk in 116ms and filtering out 38.5K non-paid claims. Because you’re reading ∼20% of the 2M-row table for two years of data, the planner still prefers a sequential scan over the covering index idx_fact_claim_provider_date_cov.