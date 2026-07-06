```text
GroupAggregate  (cost=1855278.83..1856078.38 rows=200 width=52) (actual time=5449.462..5956.345 rows=4.00 loops=1)
  Group Key: ((date_trunc('year'::text, (dim_member.enrollment_date)::timestamp with time zone))::date)
  Buffers: shared hit=3451482 read=3956, temp read=4039 written=4043
  ->  GroupAggregate  (cost=1855278.83..1855716.66 rows=15921 width=21) (actual time=5449.310..5895.199 rows=234054.00 loops=1)
        Group Key: ((date_trunc('year'::text, (dim_member.enrollment_date)::timestamp with time zone))::date), dim_member.member_id
        Buffers: shared hit=3451474 read=3956, temp read=4039 written=4043
        ->  Sort  (cost=1855278.83..1855318.63 rows=15921 width=13) (actual time=5449.298..5782.047 rows=348326.00 loops=1)
              Sort Key: ((date_trunc('year'::text, (dim_member.enrollment_date)::timestamp with time zone))::date), dim_member.member_id
              Sort Method: external merge  Disk: 7848kB
              Buffers: shared hit=3451474 read=3956, temp read=4039 written=4043
              ->  Hash Join  (cost=19010.35..1854167.65 rows=15921 width=13) (actual time=271.493..3869.535 rows=348326.00 loops=1)
                    Hash Cond: (((SubPlan 1))::text = (dim_member.member_id)::text)
                    Join Filter: ((fc.service_date >= dim_member.enrollment_date) AND (fc.service_date <= (dim_member.enrollment_date + '1 year'::interval)))
                    Rows Removed by Join Filter: 81549
                    Buffers: shared hit=3451468 read=3956, temp read=3058 written=3058
                    ->  Seq Scan on fact_claim fc  (cost=0.00..11833.75 rows=429875 width=12) (actual time=0.236..108.425 rows=429875.00 loops=1)
                          Buffers: shared hit=3579 read=3956
                    ->  Hash  (cost=16113.01..16113.01 rows=166667 width=13) (actual time=270.833..270.834 rows=500000.00 loops=1)
                          Buckets: 262144 (originally 262144)  Batches: 4 (originally 2)  Memory Usage: 7529kB
                          Buffers: shared hit=8613, temp written=1510
                          ->  Seq Scan on dim_member  (cost=0.00..16113.01 rows=166667 width=13) (actual time=0.051..161.678 rows=500000.00 loops=1)
                                Filter: (is_current AND (EXTRACT(year FROM enrollment_date) >= '2022'::numeric))
                                Rows Removed by Filter: 1
                                Buffers: shared hit=8613
                    SubPlan 1
                      ->  Limit  (cost=0.42..8.44 rows=1 width=9) (actual time=0.003..0.003 rows=1.00 loops=859819)
                            Buffers: shared hit=3439276
                            ->  Index Scan using dim_member_pkey on dim_member dim_member_1  (cost=0.42..8.44 rows=1 width=9) (actual time=0.003..0.003 rows=1.00 loops=859819)
                                  Index Cond: (member_key = fc.member_key)
                                  Index Searches: 859819
                                  Buffers: shared hit=3439276
Planning:
  Buffers: shared hit=449
Planning Time: 7.347 ms
Execution Time: 5979.258 ms
```




## Plain English Interpretation
This query takes 6 seconds and does cohort analysis by member enrollment year. It scans 430K claims and 500K current members enrolled since 2022, then for each claim runs a correlated subquery to look up the member’s business ID. After filtering to claims within 1 year of enrollment, 348K rows remain. Postgres sorts those rows to disk using an external merge, aggregates by member-year, then rolls up again by enrollment year to return 4 yearly totals. The plan shows 3.4M buffer hits, meaning the subquery is hammering the buffer cache.

## Most Expensive Node
SubPlan 1 -> Index Scan using dim_member_pkey is the bottleneck. It runs 859,819 times at 0.003ms each, consuming ∼2.6 seconds and shared hit=3439276 buffers, or ∼58% of total runtime. It’s doing a primary key lookup on dim_member for every claim row because the Hash Join condition is ((SubPlan 1))::text = dim_member.member_id, not a direct join on member_key.

Why this happens: You likely wrote WHERE member_id = (SELECT member_id FROM dim_member WHERE member_key = fc.member_key) or joined on member_id instead of member_key. Postgres can’t hash join on that, so it falls back to a nested loop with 860K index scans.

Fix: Join fact_claim.member_key = dim_member.member_key directly and drop the subplan. That converts this to a single hash join and should cut runtime to ∼500ms. Also increase work_mem to avoid the external merge Disk: 7848kB sort.

