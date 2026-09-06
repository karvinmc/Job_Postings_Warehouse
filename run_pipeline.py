from __future__ import annotations
 
import argparse
import sys
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
 
import duckdb

DEFAULT_DB_PATH = "dw_marts.duckdb"
SQL_DIR = Path("sql")

@dataclass(frozen=True)
class Step:
    name: str
    sql_file: str
    count_table: str | list[str] | None

PIPELINE_STEPS: list[Step] = [
    Step("create_tables_dw", "01_create_tables_dw.sql", None),
    Step("load_schema_dw", "02_load_schema_dw.sql", "fact_job_postings"),
    Step("flat_mart", "03_create_flat_mart.sql", "flat_mart.job_postings"),
    Step("skills_mart", "04_create_skills_mart.sql", [
        "skills_mart.dim_skills", "skills_mart.dim_date_month", "skills_mart.fact_skill_demand_monthly"
        ]),
    Step("opportunity_mart", "05_create_opportunity_mart.sql", "opportunity_mart.snapshot_job_opportunity"),
    Step("update_opportunity_mart", "06_update_opportunity_mart.sql", [
        "staging_job_opportunities", "opportunity_mart.snapshot_job_opportunity"
        ]),
]

CREATE_LOG_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS pipeline_run_log (
    run_id       VARCHAR,
    step_name    VARCHAR,
    sql_file     VARCHAR,
    table_name   VARCHAR,
    status       VARCHAR,
    rows_affected BIGINT,
    started_at   TIMESTAMP,
    finished_at  TIMESTAMP,
    duration_sec DOUBLE,
    error_message VARCHAR
);
"""

def ensure_log_table(con: duckdb.DuckDBPyConnection) -> None:
    con.execute(CREATE_LOG_TABLE_SQL)

def log_step(
    con: duckdb.DuckDBPyConnection,
    run_id: str,
    step: Step,
    status: str,
    started_at: datetime,
    finished_at: datetime,
    error_message: str | None,
    table_name: str | None = None,
    rows_affected: int | None = None,
) -> None:
    duration = (finished_at - started_at).total_seconds()
    con.execute(
        """
        INSERT INTO pipeline_run_log
            (run_id, step_name, sql_file, table_name, status, rows_affected,
             started_at, finished_at, duration_sec, error_message)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
            run_id,
            step.name,
            step.sql_file,
            table_name,
            status,
            rows_affected,
            started_at,
            finished_at,
            duration,
            error_message,
        ],
    )

def run_sql_file(con: duckdb.DuckDBPyConnection, path: Path) -> None:
    sql_text = path.read_text()
    con.execute(sql_text)

def count_rows(con: duckdb.DuckDBPyConnection, table: str) -> int:
    return con.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]

def run_step(con: duckdb.DuckDBPyConnection, run_id: str, step: Step) -> bool:
    sql_path = SQL_DIR / step.sql_file
    started_at = datetime.now(timezone.utc)
 
    print(f"\n[{step.name}] running {sql_path} ...")
 
    if not sql_path.exists():
        finished_at = datetime.now(timezone.utc)
        err = f"SQL file not found: {sql_path}"
        print(f"[{step.name}] FAILED — {err}")
        log_step(con, run_id, step, "FAILED", started_at, finished_at, err)
        return False
 
    if step.count_table is None:
        tables_to_count: list[str] = []
    elif isinstance(step.count_table, str):
        tables_to_count = [step.count_table]
    else:
        tables_to_count = list(step.count_table)
 
    try:
        run_sql_file(con, sql_path)
        finished_at = datetime.now(timezone.utc)
        duration = (finished_at - started_at).total_seconds()
 
        if not tables_to_count:
            # DDL-only step, nothing to count — log a single row with table_name=NULL.
            print(f"[{step.name}] SUCCESS — no table configured to count — duration={duration:.2f}s")
            log_step(con, run_id, step, "SUCCESS", started_at, finished_at, None)
            return True
        
        rows_summary = []
        for table in tables_to_count:
            rows = None
            try:
                rows = count_rows(con, table)
                rows_summary.append(f"{table}={rows}")
            except Exception as count_err:
                rows_summary.append(f"{table}=ERROR")
                print(f"[{step.name}] could not count rows in '{table}': {count_err}")
 
            log_step(con, run_id, step, "SUCCESS", started_at, finished_at, None,
                      table_name=table, rows_affected=rows)
 
        print(f"[{step.name}] SUCCESS — {', '.join(rows_summary)} duration={duration:.2f}s")
        return True
 
    except Exception as e:
        finished_at = datetime.now(timezone.utc)
        duration = (finished_at - started_at).total_seconds()
        print(f"[{step.name}] FAILED after {duration:.2f}s — {e}")

        if tables_to_count:
            for table in tables_to_count:
                log_step(con, run_id, step, "FAILED", started_at, finished_at, str(e), table_name=table)
        else:
            log_step(con, run_id, step, "FAILED", started_at, finished_at, str(e))
        return False

def run_pipeline(db_path: str, only_step: str | None) -> int:
    steps_to_run = PIPELINE_STEPS
    if only_step:
        steps_to_run = [s for s in PIPELINE_STEPS if s.name == only_step]
        if not steps_to_run:
            known = ", ".join(s.name for s in PIPELINE_STEPS)
            print(f"Unknown step '{only_step}'. Known steps: {known}")
            return 1
 
    run_id = str(uuid.uuid4())
    print(f"=== Pipeline run {run_id} starting ({len(steps_to_run)} step(s)) ===")
 
    con = duckdb.connect(db_path)
    ensure_log_table(con)
 
    all_ok = True
    for step in steps_to_run:
        ok = run_step(con, run_id, step)
        if not ok:
            all_ok = False
            print(f"\nStopping pipeline: '{step.name}' failed. "
                  f"Later steps were skipped so they don't run against a "
                  f"partially-updated warehouse.")
            break
 
    con.close()
 
    print(f"\n=== Pipeline run {run_id} finished: {'SUCCESS' if all_ok else 'FAILED'} ===")
    return 0 if all_ok else 1

def main() -> int:
    parser = argparse.ArgumentParser(description="Run the job-postings-warehouse ETL pipeline.")
    parser.add_argument(
        "--db", default=DEFAULT_DB_PATH,
        help=f"Path to the DuckDB database file (default: {DEFAULT_DB_PATH})",
    )
    parser.add_argument(
        "--step", default=None,
        help="Run only this step (see --list for valid names). Omit to run the full pipeline.",
    )
    parser.add_argument(
        "--list", action="store_true",
        help="List configured pipeline steps and exit.",
    )
    args = parser.parse_args()
 
    if args.list:
        print("Configured pipeline steps (in order):")
        for s in PIPELINE_STEPS:
            print(f"  - {s.name:<24} {s.sql_file}")
        return 0
 
    return run_pipeline(db_path=args.db, only_step=args.step)
 
 
if __name__ == "__main__":
    sys.exit(main())