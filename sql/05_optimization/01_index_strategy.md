## Index Strategy - MedInsure DW

### fact_claim indexes

| Index | Columns | Type | Query Supported | Reason |
| --- | --- | --- | --- | --- |
| `idx_fact_claim_date` | `date_key` | B-tree | All time filters | Partition pruning, range scans |
| `idx_fact_claim_member` | `member_key` | B-tree | Member 360, Query #3 | Join to `dim_member` |
| `idx_fact_claim_provider` | `provider_key` | B-tree | Query #1, #4, #8 | Join to `dim_provider` |
| `idx_fact_claim_service_date` | `service_date` | B-tree | SCD2 point-in-time joins | Direct date comparison |
| `idx_fact_claim_status` | `claim_status` | B-tree | Query #4 Denial analysis | Filter Paid vs Denied |
| `idx_fact_claim_provider_date_cov` | `(provider_key, date_key) INCLUDE (total_paid, claim_status)` | Covering | Query #1 YoY Provider | Index Only Scan, avoids heap |

### fact_claim_line indexes

| Index | Columns | Type | Query Supported | Reason |
| --- | --- | --- | --- | --- |
| `idx_fact_claim_line_claim` | `claim_key` | B-tree | Header → line drill |        Join to `fact_claim` |
| `idx_fact_claim_line_date` | `date_key` | B-tree | All time filters | Partition pruning, range scans |
| `idx_fact_claim_line_procedure` | `procedure_key` | B-tree | Utilization by CPT | Join to `dim_procedure` |
| `idx_fact_claim_line_diagnosis` | `diagnosis_key` | B-tree | Query #2 Diagnosis spend | Join to `dim_diagnosis` |
| `idx_fact_claim_line_diag_date_cov` | `(diagnosis_key, date_key) INCLUDE (paid_amount)` | Covering | Query #2 | Index Only Scan, avoids heap lookup



Rule: Every FK has an index. Every `WHERE` or `GROUP BY` column in top 8 queries is indexed or covered.


---

## MedInsure DW - Indexes NOT Created for `fact_claim` and `fact_claim_line`

### **1. Indexes on Measure Columns**
**Not created**: `CREATE INDEX ON fact_claim(total_paid)`  
**Not created**: `CREATE INDEX ON fact_claim_line(billed_amount, allowed_amount, paid_amount)`  

**Why**:  
- Measures are aggregated, not filtered. Queries use `SUM(total_paid)`, not `WHERE total_paid = 500`. 
- B-tree on high-cardinality decimals has huge size and low selectivity. A range scan `WHERE total_paid > 10000` would still touch 20% of rows → Seq Scan is faster.
- **Trade-off**: Index write cost = +15% slower `INSERT/COPY`. Read benefit = ~0 for current query set.  


### **2. Index on `claim_type`**
**Not created**: `CREATE INDEX idx_fact_claim_type ON fact_claim(claim_type)`  

**Why**:  
- Low cardinality: only 3 values `Professional, Institutional, Pharmacy`. 
- Not in `WHERE` for Top 8 queries. Dashboards slice by provider/member/date, not claim type alone.
- **Trade-off**: If 33% of data is 'Professional', an index scan reads 33% of table + heap fetches → slower than Seq Scan. 

### **3. Indexes Already Auto-Created**
**Not created manually**: `CREATE INDEX ON fact_claim(claim_key)` or `CREATE INDEX ON fact_claim(claim_id)`  

**Why**:  
- `claim_key BIGSERIAL PRIMARY KEY` auto-creates a unique B-tree index. 
- `claim_id VARCHAR(30) UNIQUE` auto-creates a unique B-tree index. 
- Adding them again would duplicate storage and double write overhead.