## Index Strategy - MedInsure DW

### fact_claim indexes

| Index | Columns | Type | Query Supported | Reason |
| --- | --- | --- | --- | --- |
| `idx_fact_claim_date` | `date_key` | B-tree | All time filters | Partition pruning, range scans |
| `idx_fact_claim_member` | `member_key` | B-tree | Member 360, Query #3 | Join to dim_member |
| `idx_fact_claim_provider` | `provider_key` | B-tree | Query #1, #4, #8 | Join to dim_provider |
| `idx_fact_claim_service_date` | `service_date` | B-tree | SCD2 point-in-time joins | Direct date comparison |
| `idx_fact_claim_status` | `claim_status` | B-tree | Query #4 Denial analysis | Filter Paid vs Denied |
| `idx_fact_claim_provider_date_cov` | `(provider_key, date_key) INCLUDE (total_paid, claim_status)` | Covering | Query #1 YoY Provider | Index Only Scan, avoids heap |

### fact_claim_line indexes

| Index | Columns | Type | Query Supported | Reason |
| --- | --- | --- |
| `idx_fact_claim_line_claim` | `claim_key` | B-tree | Header → line drill | FK join |
| `idx_fact_claim_line_date` | `date_key` | B-tree | Time filters | Partition pruning |
| `idx_fact_claim_line_procedure` | `procedure_key` | B-tree | Utilization by CPT | Join to dim_procedure |
| `idx_fact_claim_line_diagnosis` | `diagnosis_key` | B-tree | Query #2 Diagnosis spend | Join to dim_diagnosis |
| `idx_fact_claim_line_diag_date_cov` | `(diagnosis_key, date_key) INCLUDE (paid_amount)` | Covering | Query #2 | Index Only Scan |


Rule: Every FK has an index. Every `WHERE` or `GROUP BY` column in top 8 queries is indexed or covered.