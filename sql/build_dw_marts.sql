-- duckdb dw_marts.duckdb -c ".read build_dw_marts.sql"

.read 01_create_tables_dw.sql

.read 02_load_schema_dw.sql

.read 03_create_flat_mart.sql

.read 04_create_skills_mart.sql