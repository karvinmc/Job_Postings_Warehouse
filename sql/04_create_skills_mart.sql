DROP SCHEMA IF EXISTS skills_mart CASCADE;

CREATE SCHEMA skills_mart;

SELECT 'Loading Dim Skills for Skills Mart' AS info;

CREATE TABLE IF NOT EXISTS skills_mart.dim_skills (
    skill_id INT PRIMARY KEY,
    skill_name VARCHAR(255),
    skill_type VARCHAR(255)
);

INSERT INTO skills_mart.dim_skills (skill_id, skill_name, skill_type)
SELECT skill_id,
    skill_name,
    skill_type
FROM dim_skills;

SELECT 'Loading Dim Date for Skills Mart' AS info;

CREATE TABLE IF NOT EXISTS skills_mart.dim_date_month (
    month_start_date DATE PRIMARY KEY,
    year INT,
    MONTH INT,
    quarter INT,
    quarter_name VARCHAR(10),
    year_quarter VARCHAR(10)
);

-- One row per distinct month present in the fact data
-- DATE_TRUNC returns TIMESTAMP by default, so it's cast to DATE for the join key
INSERT INTO skills_mart.dim_date_month (
        month_start_date,
        year,
        MONTH,
        quarter,
        quarter_name,
        year_quarter
    )
SELECT DISTINCT CAST(DATE_TRUNC('month', job_posted_date) AS DATE) AS month_start_date,
    EXTRACT(
        YEAR
        FROM job_posted_date
    ) AS year,
    EXTRACT(
        MONTH
        FROM job_posted_date
    ) AS MONTH,
    EXTRACT(
        QUARTER
        FROM job_posted_date
    ) AS quarter,
    'Q-' || EXTRACT(
        QUARTER
        FROM job_posted_date
    )::VARCHAR AS quarter_name,
    EXTRACT(
        YEAR
        FROM job_posted_date
    )::VARCHAR || '-Q' || EXTRACT(
        QUARTER
        FROM job_posted_date
    )::VARCHAR AS year_quarter
FROM fact_job_postings
ORDER BY month_start_date;

SELECT 'Loading Fact Skills for Skills Mart' AS info;

-- Grain: skill_id + month_start_date + job_title_short
-- All measures are additive counts, safe to re-aggregate at any level
CREATE TABLE IF NOT EXISTS skills_mart.fact_skill_demand_monthly (
    skill_id INT,
    month_start_date DATE,
    job_title_short VARCHAR,
    total_postings_count INT,
    onsite_postings_count INT,
    remote_postings_count INT,
    health_insurance_postings_count INT,
    no_degree_mention_postings_count INT,
    PRIMARY KEY (skill_id, month_start_date, job_title_short),
    FOREIGN KEY (skill_id) REFERENCES skills_mart.dim_skills(skill_id),
    FOREIGN KEY (month_start_date) REFERENCES skills_mart.dim_date_month(month_start_date)
);

INSERT INTO skills_mart.fact_skill_demand_monthly (
        skill_id,
        month_start_date,
        job_title_short,
        total_postings_count,
        onsite_postings_count,
        remote_postings_count,
        health_insurance_postings_count,
        no_degree_mention_postings_count
    ) -- Flatten booleans to 0/1 so they can be summed as additive counts
    WITH job_postings_prep AS (
        SELECT bjs.skill_id,
            CAST(DATE_TRUNC('month', fjp.job_posted_date) AS DATE) AS month_start_date,
            fjp.job_title_short,
            CASE
                WHEN fjp.job_work_from_home = FALSE THEN 1
                ELSE 0
            END AS is_onsite,
            CASE
                WHEN fjp.job_work_from_home = TRUE THEN 1
                ELSE 0
            END AS is_remote,
            CASE
                WHEN fjp.job_health_insurance = TRUE THEN 1
                ELSE 0
            END AS has_health_insurance,
            CASE
                WHEN fjp.job_no_degree_mention = TRUE THEN 1
                ELSE 0
            END AS no_degree_mentioned
        FROM fact_job_postings AS fjp
            INNER JOIN bridge_job_skills AS bjs ON bjs.job_id = fjp.job_id
    )
SELECT skill_id,
    month_start_date,
    job_title_short,
    COUNT(*) AS total_postings_count,
    SUM(is_onsite) AS onsite_postings_count,
    SUM(is_remote) AS remote_postings_count,
    SUM(has_health_insurance) AS health_insurance_postings_count,
    SUM(no_degree_mentioned) AS no_degree_mention_postings_count
FROM job_postings_prep
GROUP BY skill_id,
    month_start_date,
    job_title_short
ORDER BY skill_id,
    month_start_date,
    job_title_short;

-- Validation
SELECT 'Dim Skills' AS table_name,
    COUNT(*) AS row_count
FROM skills_mart.dim_skills
UNION ALL
SELECT 'Dim Date Month',
    COUNT(*)
FROM skills_mart.dim_date_month
UNION ALL
SELECT 'Fact Skill Demand',
    COUNT(*)
FROM skills_mart.fact_skill_demand_monthly;

SELECT 'Skill Dimension Sample' AS info;

SELECT *
FROM skills_mart.dim_skills
LIMIT 5;

SELECT 'Date Month Dimension Sample' AS info;

SELECT *
FROM skills_mart.dim_date_month
LIMIT 5;

SELECT 'Skill Demand Fact Sample' AS info;

SELECT *
FROM skills_mart.fact_skill_demand_monthly
LIMIT 5;