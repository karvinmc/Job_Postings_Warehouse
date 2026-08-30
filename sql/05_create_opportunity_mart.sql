DROP SCHEMA IF EXISTS opportunity_mart CASCADE;

CREATE SCHEMA opportunity_mart;

CREATE TABLE opportunity_mart.snapshot_job_opportunity (
    job_id BIGINT PRIMARY KEY,
    company_id BIGINT,
    job_title_short VARCHAR,
    job_location VARCHAR,
    job_schedule_type VARCHAR,
    salary_year_avg DOUBLE,
    salary_hour_avg DOUBLE,
    is_remote BOOLEAN,
    no_degree_required BOOLEAN,
    has_health_insurance BOOLEAN,
    pays_above_title_median BOOLEAN,
    opportunity_score INTEGER,
    opportunity_tier VARCHAR,
    snapshot_date DATE NOT NULL
);

-- Initial load
WITH title_median_salary AS (
    SELECT job_title_short,
        MEDIAN(salary_year_avg) OVER (PARTITION BY job_title_short) AS median_salary_for_title,
        *
    FROM fact_job_postings
),
scored AS (
    SELECT job_id,
        company_id,
        job_title_short,
        job_location,
        job_schedule_type,
        salary_year_avg,
        salary_hour_avg,
        COALESCE(job_work_from_home, false) AS is_remote,
        COALESCE(job_no_degree_mention, false) AS no_degree_required,
        COALESCE(job_health_insurance, false) AS has_health_insurance,
        (
            salary_year_avg IS NOT NULL
            AND salary_year_avg > median_salary_for_title
        ) AS pays_above_title_median,
        (
            CASE
                WHEN COALESCE(job_work_from_home, false) THEN 1
                ELSE 0
            END + CASE
                WHEN COALESCE(job_no_degree_mention, false) THEN 1
                ELSE 0
            END + CASE
                WHEN COALESCE(job_health_insurance, false) THEN 1
                ELSE 0
            END + CASE
                WHEN (
                    salary_year_avg IS NOT NULL
                    AND salary_year_avg > median_salary_for_title
                ) THEN 1
                ELSE 0
            END
        ) AS opportunity_score
    FROM title_median_salary
)
INSERT INTO opportunity_mart.snapshot_job_opportunity
SELECT job_id,
    company_id,
    job_title_short,
    job_location,
    job_schedule_type,
    salary_year_avg,
    salary_hour_avg,
    is_remote,
    no_degree_required,
    has_health_insurance,
    pays_above_title_median,
    opportunity_score,
    CASE
        WHEN opportunity_score >= 3 THEN 'High'
        WHEN opportunity_score = 2 THEN 'Medium'
        ELSE 'Low'
    END AS opportunity_tier,
    CURRENT_DATE AS snapshot_date
FROM scored;

-- Validation
SELECT COUNT(*) AS total_postings
FROM opportunity_mart.snapshot_job_opportunity;

-- Distribution across tiers
SELECT opportunity_tier,
    COUNT(*) AS posting_count
FROM opportunity_mart.snapshot_job_opportunity
GROUP BY opportunity_tier
ORDER BY posting_count DESC;

-- job_id should be unique (snapshot grain, one row per posting)
SELECT job_id,
    COUNT(*) AS row_count
FROM opportunity_mart.snapshot_job_opportunity
GROUP BY job_id
HAVING COUNT(*) > 1;