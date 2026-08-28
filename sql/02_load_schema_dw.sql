SELECT 'Loading company dimension table...' AS info;

INSERT INTO dim_company (company_id, company_name)
SELECT company_id,
    name
FROM read_csv(
        'https://storage.googleapis.com/sql_de/company_dim.csv',
        AUTO_DETECT = TRUE
    );

SELECT 'Loading skills dimension table...' AS info;

INSERT INTO dim_skills (skill_id, skill_name, skill_type)
SELECT skill_id,
    skills,
    TYPE
FROM read_csv(
        'https://storage.googleapis.com/sql_de/skills_dim.csv',
        AUTO_DETECT = TRUE
    );

SELECT 'Loading job postings fact table...' AS info;

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
SELECT job_id,
    company_id,
    job_title_short,
    job_title,
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
FROM read_csv(
        'https://storage.googleapis.com/sql_de/job_postings_fact.csv',
        AUTO_DETECT = TRUE
    );

SELECT 'Loading job skills bridge table...' AS info;

INSERT INTO bridge_job_skills (job_id, skill_id)
SELECT job_id,
    skill_id
FROM read_csv(
        'https://storage.googleapis.com/sql_de/skills_job_dim.csv',
        AUTO_DETECT = TRUE
    );