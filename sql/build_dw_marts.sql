-- duckdb dw_marts.duckdb -c ".read build_dw_marts.sql"
-- duckdb dw_marts.duckdb -c ".read demo_new_batch.sql"

.read 01_create_tables_dw.sql

.read 02_load_schema_dw.sql

.read 03_create_flat_mart.sql

.read 04_create_skills_mart.sql

.read 05_create_opportunity_mart.sql

.read demo_new_batch.sql

.read 06_update_opportunity_mart.sql