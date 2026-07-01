-- Destructive reset: drops both schemas and all objects within them.
DROP SCHEMA IF EXISTS source_oltp CASCADE;
DROP SCHEMA IF EXISTS dw CASCADE;

CREATE SCHEMA IF NOT EXISTS source_oltp;
CREATE SCHEMA IF NOT EXISTS dw;

COMMENT ON SCHEMA source_oltp IS 'Claims OLTP - 3NF, 18mo retention';
COMMENT ON SCHEMA dw IS 'MedInsure Analytics Warehouse - Star Schema';
