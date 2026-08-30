# 🏗️ Data Warehouse & Mart Build: Production ETL Pipeline

An end-to-end data engineering pipeline that transforms raw CSV files from Google Cloud Storage into a normalized star schema data warehouse, then builds analytical data marts on top of it.

---

## 🧾 Summary

- Built a complete ETL pipeline: raw CSVs to star schema warehouse to analytical marts
- Designed a star schema with a fact table, dimension tables, and a bridge table for the job-skill many-to-many relationship
- Implemented idempotent load and transformation logic with validation queries at every step
- Built three data marts (flat, skills, opportunity), each with a distinct grain and purpose
- Implemented a MERGE-based incremental update pipeline demonstrating INSERT, UPDATE, and DELETE in a single statement

---

## 🧩 Problem & Context

Raw job posting data arrives as flat CSV files in Google Cloud Storage, not structured for analytical queries. Analysts need to answer questions such as:

- Which skills are most in demand over time?
- How do salary patterns vary by role and skill?
- Which postings represent the strongest overall opportunity, based on pay, flexibility, and requirements?

A single warehouse gives the organization one consistent source of truth. Data marts sit on top of it, pre-aggregating or pre-scoring data for specific use cases so consumers aren't repeating expensive logic at query time.

**Note on scope:** This project follows a guided build through the warehouse and the first two marts (flat, skills). From the third mart onward, the design is my own: a job opportunity mart with a composite scoring rule and a MERGE-based incremental update, built to practice production upsert patterns rather than to replicate a reference implementation.

---

## 📌 Data Source

Raw CSV data sourced from Luke Barousse's [SQL Data Engineering Course](https://github.com/lukebarousse/SQL_Data_Engineering_Course).

---

## 🧰 Tech Stack

- **Database:** DuckDB (file-based OLAP database with GCS integration via `httpfs`)
- **Language:** SQL (DDL for schema design, DML for loading and transformation)
- **Data Model:** Star schema (fact, dimension, and bridge tables)
- **Development:** VS Code for SQL editing, terminal for DuckDB CLI execution
- **Automation:** Master SQL script for pipeline orchestration
- **Version Control:** Git/GitHub for versioned pipeline scripts
- **Storage:** Google Cloud Storage for source CSV files

---

## 📂 Repository Structure

```text
job-postings-warehouse/
├── sql/
│   ├── 01_create_tables_dw.sql          # Star schema DDL
│   ├── 02_load_schema_dw.sql            # GCS data extraction & loading
│   ├── 03_create_flat_mart.sql          # Denormalized flat mart
│   ├── 04_create_skills_mart.sql        # Skills demand mart
│   ├── 05_create_opportunity_mart.sql   # Opportunity mart, initial build
│   ├── 06_update_opportunity_mart.sql   # Opportunity mart incremental update (MERGE)
│   ├── demo_new_batch.sql               # Mutates sample data to demo the MERGE (debug/demo only)
│   └── build_dw_marts.sql               # Master SQL build script
└── README.md                            # You are here
```

---

## 🏗️ Pipeline Architecture

The pipeline loads job posting CSVs from Google Cloud Storage into a normalized star schema warehouse, then builds three marts on top of it. BI tools (Excel, Power BI, Tableau, Python) can consume from either layer.

### Data Warehouse

Star schema with `dim_company`, `dim_skills`, `fact_job_postings`, and `bridge_job_skills`.

- **SQL Files:**
  - [`01_create_tables_dw.sql`](./sql/01_create_tables_dw.sql) – Defines the star schema
  - [`02_load_schema_dw.sql`](./sql/02_load_schema_dw.sql) – Loads CSVs from GCS into the warehouse tables
- **Purpose:** Single source of truth for all downstream marts
- **Grain:** One row per job posting in `fact_job_postings`

### Flat Mart

Denormalized table with all dimensions joined, for ad-hoc queries.

- **SQL File:** [`03_create_flat_mart.sql`](./sql/03_create_flat_mart.sql)
- **Purpose:** Quick ad-hoc queries without joining across tables
- **Grain:** One row per job posting, skills aggregated into an array

### Skills Mart

Time-series skill demand analysis with additive measures.

- **SQL File:** [`04_create_skills_mart.sql`](./sql/04_create_skills_mart.sql)
- **Purpose:** Track skill demand over time, broken down by job title
- **Grain:** `skill_id + month_start_date + job_title_short`
- **Key Features:** All measures are additive counts, safe to re-aggregate at any level

### Opportunity Mart

Current snapshot of job postings, tagged with a computed opportunity tier and kept in sync via MERGE.

- **SQL Files:**
  - [`05_create_opportunity_mart.sql`](./sql/05_create_opportunity_mart.sql) – Initial build of the opportunity snapshot
  - [`06_update_opportunity_mart.sql`](./sql/06_update_opportunity_mart.sql) – Incremental update using MERGE
  - [`demo_new_batch.sql`](./sql/demo_new_batch.sql) – Mutates a few rows in the source table to demo the MERGE branches; debug/demo only, not part of production runs
- **Purpose:** Tag each posting with a composite opportunity score so downstream tools can filter or sort without recomputing the logic
- **Grain:** One row per job posting
- **Scoring rule:** Each posting earns one point for each of the following: remote-friendly, no degree required, offers health insurance, and pays above the median for that job title (via a `MEDIAN() OVER (PARTITION BY ...)` window function). Score maps to a tier: High (3–4), Medium (2), Low (0–1)
- **Key Features:** A single MERGE statement handles INSERT (new posting), UPDATE (tier changed), and DELETE (posting removed from source) in one pass; this is a current-state snapshot, not a history table, so removed postings are deleted rather than archived

---

## 💻 Data Engineering Skills Demonstrated

### ETL Pipeline Development

- **Extract:** Direct CSV loading from Google Cloud Storage using DuckDB's `httpfs` extension
- **Transform:** Data normalization, type conversion (`CAST`, `DATE_TRUNC`), and null handling (`COALESCE`)
- **Load:** Idempotent table and schema creation with `DROP ... IF EXISTS` patterns
- **Incremental Updates:** MERGE for upsert and soft-delete patterns (INSERT, UPDATE, DELETE in one statement)
- **Orchestration:** Master SQL script (`build_dw_marts.sql`) for automated pipeline execution

### Dimensional Modeling

- **Star Schema Design:** Fact table (`fact_job_postings`) with dimension tables (`dim_company`, `dim_skills`)
- **Bridge Tables:** Many-to-many relationship handling (`bridge_job_skills`)
- **Grain Definition:** Distinct, explicit grain per mart (posting-level, skill+month+title, posting-level with scoring)
- **Additive Measures:** Counts and sums in the skills mart that can be safely re-aggregated at any level

### SQL Advanced Techniques

- **DDL Operations:** `CREATE TABLE`, `CREATE SCHEMA`, primary and foreign key constraints
- **MERGE Operations:** `MERGE INTO` with `WHEN MATCHED`, `WHEN NOT MATCHED BY TARGET`, and `WHEN NOT MATCHED BY SOURCE` for production-style upsert and delete handling
- **Window Functions:** `MEDIAN() OVER (PARTITION BY ...)` for title-relative salary comparisons
- **CTEs:** Multi-step transformations, kept readable by separating raw joins from scoring logic
- **Date Functions:** `DATE_TRUNC('month')`, `EXTRACT(quarter)` for temporal dimension creation
- **Nested Types:** `ARRAY_AGG` and `STRUCT_PACK` to collapse a one-to-many skill relationship into a single column without duplicating fact rows
- **Boolean Logic:** `CASE WHEN` conversions for aggregating flags (remote, health insurance, no degree) and combining them into a composite score

### Data Quality & Production Practices

- **Idempotency:** All build scripts are safely rerunnable without side effects
- **Data Validation:** Row counts, uniqueness checks, and sample previews at each pipeline step
- **Type Safety:** Explicit data types (`VARCHAR`, `INTEGER`, `DOUBLE`, `BOOLEAN`, `TIMESTAMP`)
- **Schema Organization:** Separate schemas (`flat_mart`, `skills_mart`, `opportunity_mart`) for logical separation from the warehouse
- **Reproducible Demos:** A dedicated script (`demo_new_batch.sql`) to simulate an incoming batch, so the MERGE logic can be verified end to end rather than assumed to work
