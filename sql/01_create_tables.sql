-- MEDICARE FRAUD DETECTION - CREATE TABLES
drop DATABASE if EXISTS medicare_fraud;
create DATABASE medicare_fraud;
use medicare_fraud;

-- 1. PROVIDERS TABLE (from Train-1542865627584.csv)
CREATE TABLE providers (
    provider_id VARCHAR(20) PRIMARY KEY,
    potential_fraud BOOLEAN,  -- Yes/No converted to 1/0
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP -- tracking when the data was loaded
);

-- 2. BENEFICIARIES (PATIENTS) TABLE
CREATE TABLE beneficiaries (
    bene_id VARCHAR(20) PRIMARY KEY,
    dob DATE,
    dod DATE NULL,
    gender VARCHAR(5),  -- 1, 2 as strings
    race VARCHAR(5),    -- 1, 2, 3, 4, 5 as strings
    renal_disease_indicator VARCHAR(5),  -- 0, 1 as strings
    state VARCHAR(5),
    county VARCHAR(10),
    no_of_months_part_a_cov INT,
    no_of_months_part_b_cov INT,
    -- Chronic conditions (1 = Yes, 2 = No in CSV, we'll store as BOOLEAN)
    chronic_cond_alzheimer BOOLEAN,
    chronic_cond_heartfailure BOOLEAN,
    chronic_cond_kidney_disease BOOLEAN,
    chronic_cond_cancer BOOLEAN,
    chronic_cond_obstr_pulmonary BOOLEAN,
    chronic_cond_depression BOOLEAN,
    chronic_cond_diabetes BOOLEAN,
    chronic_cond_ischemic_heart BOOLEAN,
    chronic_cond_osteoporasis BOOLEAN,
    chronic_cond_rheumatoidarthritis BOOLEAN,
    chronic_cond_stroke BOOLEAN,
    -- Annual amounts
    ip_annual_reimbursement_amt DECIMAL(10,2),
    ip_annual_deductible_amt DECIMAL(10,2),
    op_annual_reimbursement_amt DECIMAL(10,2),
    op_annual_deductible_amt DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. INPATIENT CLAIMS TABLE
CREATE TABLE inpatient_claims (
    claim_id VARCHAR(20) PRIMARY KEY,
    bene_id VARCHAR(20),
    claim_start_dt DATE,
    claim_end_dt DATE,
    provider_id VARCHAR(20),
    insc_claim_amt_reimbursed DECIMAL(10,2),
    attending_physician VARCHAR(20) NULL,
    operating_physician VARCHAR(20) NULL,
    other_physician VARCHAR(20) NULL,
    admission_dt DATE,
    clm_admit_diagnosis_code VARCHAR(10),
    deductible_amt_paid DECIMAL(10,2),
    discharge_dt DATE,
    diagnosis_group_code VARCHAR(10),
    -- Diagnosis codes (up to 10)
    clm_diagnosis_code_1 VARCHAR(10),
    clm_diagnosis_code_2 VARCHAR(10),
    clm_diagnosis_code_3 VARCHAR(10),
    clm_diagnosis_code_4 VARCHAR(10),
    clm_diagnosis_code_5 VARCHAR(10),
    clm_diagnosis_code_6 VARCHAR(10),
    clm_diagnosis_code_7 VARCHAR(10),
    clm_diagnosis_code_8 VARCHAR(10),
    clm_diagnosis_code_9 VARCHAR(10),
    clm_diagnosis_code_10 VARCHAR(10),
    -- Procedure codes (up to 6)
    clm_procedure_code_1 VARCHAR(10),
    clm_procedure_code_2 VARCHAR(10),
    clm_procedure_code_3 VARCHAR(10),
    clm_procedure_code_4 VARCHAR(10),
    clm_procedure_code_5 VARCHAR(10),
    clm_procedure_code_6 VARCHAR(10),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (bene_id) REFERENCES beneficiaries(bene_id),
    FOREIGN KEY (provider_id) REFERENCES providers(provider_id)
);

-- 4. OUTPATIENT CLAIMS TABLE
CREATE TABLE outpatient_claims (
    claim_id VARCHAR(20) PRIMARY KEY,
    bene_id VARCHAR(20),
    claim_start_dt DATE,
    claim_end_dt DATE,
    provider_id VARCHAR(20),
    insc_claim_amt_reimbursed DECIMAL(10,2),
    attending_physician VARCHAR(20) NULL,
    operating_physician VARCHAR(20) NULL,
    other_physician VARCHAR(20) NULL,
    -- Diagnosis codes (up to 10)
    clm_diagnosis_code_1 VARCHAR(10),
    clm_diagnosis_code_2 VARCHAR(10),
    clm_diagnosis_code_3 VARCHAR(10),
    clm_diagnosis_code_4 VARCHAR(10),
    clm_diagnosis_code_5 VARCHAR(10),
    clm_diagnosis_code_6 VARCHAR(10),
    clm_diagnosis_code_7 VARCHAR(10),
    clm_diagnosis_code_8 VARCHAR(10),
    clm_diagnosis_code_9 VARCHAR(10),
    clm_diagnosis_code_10 VARCHAR(10),
    -- Procedure codes (up to 6)
    clm_procedure_code_1 VARCHAR(10),
    clm_procedure_code_2 VARCHAR(10),
    clm_procedure_code_3 VARCHAR(10),
    clm_procedure_code_4 VARCHAR(10),
    clm_procedure_code_5 VARCHAR(10),
    clm_procedure_code_6 VARCHAR(10),
    deductible_amt_paid DECIMAL(10,2),
    clm_admit_diagnosis_code VARCHAR(10),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (bene_id) REFERENCES beneficiaries(bene_id),
    FOREIGN KEY (provider_id) REFERENCES providers(provider_id)
);
-- 5. CREATE INDEXES FOR FASTER QUERIES
CREATE INDEX idx_inpatient_provider ON inpatient_claims(provider_id);
CREATE INDEX idx_inpatient_bene ON inpatient_claims(bene_id);
CREATE INDEX idx_inpatient_dates ON inpatient_claims(claim_start_dt, claim_end_dt);
CREATE INDEX idx_outpatient_provider ON outpatient_claims(provider_id);
CREATE INDEX idx_outpatient_bene ON outpatient_claims(bene_id);
CREATE INDEX idx_outpatient_dates ON outpatient_claims(claim_start_dt, claim_end_dt);
CREATE INDEX idx_beneficiaries_dod ON beneficiaries(dod);
CREATE INDEX idx_beneficiaries_state ON beneficiaries(state);
CREATE INDEX idx_providers_fraud ON providers(potential_fraud);

SHOW TABLES;
SELECT 'Tables created successfully' as Status;
