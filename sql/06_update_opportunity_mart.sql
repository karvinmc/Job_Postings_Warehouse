-- Step 1: Build the incoming snapshot with the same median-based
-- scoring logic used in the initial load.
CREATE OR REPLACE TEMP TABLE staging_job_opportunities AS WITH title_median_salary AS (
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
    END AS opportunity_tier
FROM scored;

-- Step 2: MERGE -- single statement handles UPDATE, INSERT, and DELETE
MERGE INTO opportunity_mart.snapshot_job_opportunity AS target USING staging_job_opportunities AS source ON target.job_id = source.job_id -- Posting exists in both, but its computed tier has changed
WHEN MATCHED
AND target.opportunity_tier <> source.opportunity_tier THEN
UPDATE
SET company_id = source.company_id,
    job_title_short = source.job_title_short,
    job_location = source.job_location,
    job_schedule_type = source.job_schedule_type,
    salary_year_avg = source.salary_year_avg,
    salary_hour_avg = source.salary_hour_avg,
    is_remote = source.is_remote,
    no_degree_required = source.no_degree_required,
    has_health_insurance = source.has_health_insurance,
    pays_above_title_median = source.pays_above_title_median,
    opportunity_score = source.opportunity_score,
    opportunity_tier = source.opportunity_tier,
    snapshot_date = CURRENT_DATE -- Posting is new to this batch -> insert it
    WHEN NOT MATCHED BY TARGET THEN
INSERT (
        job_id,
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
        opportunity_tier,
        snapshot_date
    )
VALUES (
        source.job_id,
        source.company_id,
        source.job_title_short,
        source.job_location,
        source.job_schedule_type,
        source.salary_year_avg,
        source.salary_hour_avg,
        source.is_remote,
        source.no_degree_required,
        source.has_health_insurance,
        source.pays_above_title_median,
        source.opportunity_score,
        source.opportunity_tier,
        CURRENT_DATE
    ) -- Posting no longer exists in source -> remove it from the snapshot
    WHEN NOT MATCHED BY SOURCE THEN DELETE
RETURNING merge_action,
    *;

-- Validation
-- job_id should still be unique after the merge
SELECT job_id,
    COUNT(*) AS row_count
FROM opportunity_mart.snapshot_job_opportunity
GROUP BY job_id
HAVING COUNT(*) > 1;

-- Current tier distribution
SELECT opportunity_tier,
    COUNT(*) AS posting_count
FROM opportunity_mart.snapshot_job_opportunity
GROUP BY opportunity_tier
ORDER BY posting_count DESC;

-- Total row count should match the size of the incoming snapshot
SELECT (
        SELECT COUNT(*)
        FROM opportunity_mart.snapshot_job_opportunity
    ) AS mart_row_count,
    (
        SELECT COUNT(*)
        FROM staging_job_opportunities
    ) AS staging_row_count;