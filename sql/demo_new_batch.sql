INSERT INTO fact_job_postings (
        job_id,
        company_id,
        job_title_short,
        job_title_long,
        job_location,
        job_via,
        job_schedule_type,
        job_work_from_home,
        search_location,
        job_posted_date,
        job_no_degree_mention,
        job_health_insurance,
        job_country,
        salary_rate,
        salary_year_avg,
        salary_hour_avg
    )
SELECT (
        SELECT MAX(job_id)
        FROM fact_job_postings
    ) + 1 AS job_id,
    company_id,
    'Data Engineer' AS job_title_short,
    'Demo Data Engineer Posting' AS job_title_long,
    job_location,
    job_via,
    job_schedule_type,
    TRUE AS job_work_from_home,
    search_location,
    CURRENT_TIMESTAMP AS job_posted_date,
    TRUE AS job_no_degree_mention,
    TRUE AS job_health_insurance,
    job_country,
    salary_rate,
    salary_year_avg,
    salary_hour_avg
FROM fact_job_postings
LIMIT 1;

UPDATE fact_job_postings
SET job_work_from_home = TRUE,
    job_health_insurance = TRUE
WHERE job_id = (
        SELECT job_id
        FROM fact_job_postings
        WHERE COALESCE(job_work_from_home, false) = false
        ORDER BY job_id
        LIMIT 1
    );

DELETE FROM bridge_job_skills
WHERE job_id = (
        SELECT job_id
        FROM fact_job_postings
        ORDER BY job_id DESC
        LIMIT 1 OFFSET 1
    );

DELETE FROM fact_job_postings
WHERE job_id = (
        SELECT job_id
        FROM fact_job_postings
        ORDER BY job_id DESC
        LIMIT 1 OFFSET 1
    );

SELECT COUNT(*) AS fact_row_count
FROM fact_job_postings;