DROP SCHEMA IF EXISTS flat_mart CASCADE;

CREATE SCHEMA flat_mart;

SELECT 'Loading Flat Mart' AS info;

-- Grain: one row per job posting, all dimensions denormalized for ad-hoc queries
CREATE OR REPLACE TABLE flat_mart.job_postings AS
SELECT fjp.job_id,
    fjp.company_id,
    fjp.job_title_short,
    fjp.job_title_long,
    fjp.job_location,
    fjp.job_via,
    fjp.job_schedule_type,
    fjp.job_work_from_home,
    fjp.search_location,
    fjp.job_posted_date,
    fjp.job_no_degree_mention,
    fjp.job_health_insurance,
    fjp.job_country,
    fjp.salary_rate,
    fjp.salary_year_avg,
    fjp.salary_hour_avg,
    dc.company_id,
    dc.company_name,
    -- One posting can map to many skills; ARRAY_AGG keeps the grain at one row per posting
    ARRAY_AGG(
        STRUCT_PACK(
            skill_type := ds.skill_type,
            skill_name := ds.skill_name
        )
    ) AS skills_and_types
FROM fact_job_postings AS fjp
    LEFT JOIN dim_company AS dc ON fjp.company_id = dc.company_id
    LEFT JOIN bridge_job_skills AS bjs ON fjp.job_id = bjs.job_id
    LEFT JOIN dim_skills AS ds ON bjs.skill_id = ds.skill_id
GROUP BY fjp.job_id,
    fjp.company_id,
    fjp.job_title_short,
    fjp.job_title_long,
    fjp.job_location,
    fjp.job_via,
    fjp.job_schedule_type,
    fjp.job_work_from_home,
    fjp.search_location,
    fjp.job_posted_date,
    fjp.job_no_degree_mention,
    fjp.job_health_insurance,
    fjp.job_country,
    fjp.salary_rate,
    fjp.salary_year_avg,
    fjp.salary_hour_avg,
    dc.company_id,
    dc.company_name;

SELECT 'Flat Mart Job Postings' AS table_name,
    COUNT(*) AS row_count
FROM flat_mart.job_postings;

SELECT 'Flat Mart Sample' AS info;

SELECT *
FROM flat_mart.job_postings
LIMIT 10;