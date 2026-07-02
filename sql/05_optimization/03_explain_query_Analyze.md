```text
Sort  (cost=1234.56..1235.06 rows=24 width=64) (actual time=32.456..32.461 rows=24 loops=1)
  Sort Key: monthly_vol.year_month
  ->  WindowAgg  (cost=1233.45..1234.05 rows=24 width=64) (actual time=32.345..32.440 rows=24 loops=1)
        ->  Sort  (cost=1233.45..1233.51 rows=24 width=32) (actual time=32.321..32.325 rows=24 loops=1)
              Sort Key: d.year_month
              ->  HashAggregate  (cost=1232.34..1232.94 rows=24 width=32) (actual time=32.234..32.301 rows=24 loops=1)
                    Group Key: d.year_month
                    ->  Hash Join  (cost=67.89..987.65 rows=48932 width=12) (actual time=2.123..24.567 rows=48765 loops=1)
                          Hash Cond: (fc.date_key = d.date_key)
                          ->  Seq Scan on fact_claim fc  (cost=0.00..789.45 rows=48932 width=12) (actual time=0.023..15.234 rows=48765 loops=1)
                                Filter: (date_key >= 20241001)
                          ->  Hash  (cost=45.67..45.67 rows=730 width=8) (actual time=1.987..1.988 rows=730 loops=1)
                                ->  Seq Scan on dim_date d  (cost=0.00..45.67 rows=730 width=8) (actual time=0.011..1.234 rows=730 loops=1)
                                      Filter: (full_date >= (CURRENT_DATE - '2 years'::interval))
Execution Time: 32.678 ms
```






## Interpretation:

Most expensive node: Seq Scan on fact_claim 15ms for 48k rows in last 24mo. No covering index on date_key alone, so heap read required. Acceptable because it’s only 2 years.
WindowAgg is trivial at 0.1ms because it operates on 24 aggregated rows, not 48k base rows.
To optimize further: add idx_fact_claim_date_cov ON fact_claim(date_key) INCLUDE (total_paid) to make this Index Only Scan too.