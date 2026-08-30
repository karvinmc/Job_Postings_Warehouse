/*
 SCHEMA SETUP
 Drops existing tables (if any) and recreates the star schema
 */
DROP TABLE IF EXISTS bridge_job_skills;

DROP TABLE IF EXISTS fact_job_postings;

DROP TABLE IF EXISTS dim_skills;

DROP TABLE IF EXISTS dim_company;

-- Dimension: companies
CREATE TABLE IF NOT EXISTS dim_company (
    company_id INT PRIMARY KEY,
    company_name VARCHAR(255)
);

-- Dimension: skills, with a type/category label
CREATE TABLE IF NOT EXISTS dim_skills (
    skill_id INT PRIMARY KEY,
    skill_name VARCHAR(255),
    skill_type VARCHAR(255)
);

-- Fact table: one row per job posting
-- Links to dim_company via company_id
CREATE TABLE IF NOT EXISTS fact_job_postings (
    job_id INT PRIMARY KEY,
    company_id INT,
    job_title_short VARCHAR(255),
    job_title_long VARCHAR(255),
    job_location VARCHAR(255),
    job_via VARCHAR(255),
    job_schedule_type VARCHAR(255),
    job_work_from_home BOOLEAN,
    search_location VARCHAR(255),
    job_posted_date TIMESTAMP,
    job_no_degree_mention BOOLEAN,
    job_health_insurance BOOLEAN,
    job_country VARCHAR(255),
    salary_rate VARCHAR(255),
    salary_year_avg DOUBLE,
    salary_hour_avg DOUBLE,
    FOREIGN KEY (company_id) REFERENCES dim_company(company_id)
);

-- Bridge table: many-to-many link between jobs and skills
CREATE TABLE IF NOT EXISTS bridge_job_skills (
    job_id INT,
    skill_id INT,
    PRIMARY KEY (job_id, skill_id),
    FOREIGN KEY (job_id) REFERENCES fact_job_postings(job_id),
    FOREIGN KEY (skill_id) REFERENCES dim_skills(skill_id)
);

-- Sanity check: confirm all tables were created in the schema
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'main';