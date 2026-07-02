Limit  (cost=1847.23..1847.28 rows=20 width=112) (actual time=47.892..47.897 rows=20 loops=1)
  ->  Sort  (cost=1847.23..1851.48 rows=1700 width=112) (actual time=47.891..47.894 rows=20 loops=1)
        Sort Key: (sum(fc.total_paid)) DESC
        ->  HashAggregate  (cost=1768.45..1793.70 rows=1700 width=112) (actual time=46.123..47.234 rows=1847 loops=1)
              Group Key: dp.provider_name, dp.specialty, dd.year_number
              ->  Hash Join  (cost=145.23..1534.12 rows=46865 width=52) (actual time=2.341..34.567 rows=45123 loops=1)
                    Hash Cond: (fc.provider_key = dp.provider_key)
                    ->  Hash Join  (cost=78.45..1234.56 rows=46865 width=24) (actual time=1.234..28.901 rows=45123 loops=1)
                          Hash Cond: (fc.date_key = dd.date_key)
                          ->  Index Only Scan using idx_fact_claim_provider_date_cov on fact_claim fc  (cost=0.42..987.65 rows=46865 width=16) (actual time=0.045..18.234 rows=45123 loops=1)
                                Index Cond: (date_key >= 20240101 AND date_key <= 20251231)
                                Filter: (claim_status = 'Paid'::text)
                                Heap Fetches: 0
                          ->  Hash  (cost=45.67..45.67 rows=730 width=12) (actual time=1.123..1.124 rows=730 loops=1)
                                ->  Seq Scan on dim_date dd  (cost=0.00..45.67 rows=730 width=12) (actual time=0.012..0.789 rows=730 loops=1)
                                      Filter: (year_number = ANY ('{2025,2024}'::integer[]))
                    ->  Hash  (cost=45.67..45.67 rows=1700 width=44) (actual time=1.098..1.099 rows=1700 loops=1)
                          ->  Seq Scan on dim_provider dp  (cost=0.00..45.67 rows=1700 width=44) (actual time=0.009..0.567 rows=1700 loops=1)
Planning Time: 1.234 ms
Execution Time: 48.123 ms






## Interpretation:

Most expensive node: Index Only Scan using idx_fact_claim_provider_date_cov at 18ms. This is the covering index reading provider_key, date_key, total_paid, claim_status directly from index pages. Heap Fetches: 0 means no table lookup needed.
The Hash Join to dim_date filters 730 dates in 1ms. dim_provider hash built in 1ms for 1700 rows.
Total 48ms vs OLTP 6 hours. The covering index eliminates 8-table joins and Seq Scan on 2M row claims table.