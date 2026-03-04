-- MEDICARE FRAUD DETECTION - LOAD DATA
USE medicare_fraud;
-- Disable foreign key checks for faster loading
SET FOREIGN_KEY_CHECKS = 0;

-- 1. LOAD PROVIDERS
TRUNCATE TABLE providers;
LOAD DATA LOCAL INFILE 'C:/Users/dell/JupyterProjects/Projects/fraud_detection_using_sql/data/Train-1542865627584.csv'
INTO TABLE providers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS (provider_id, @potential_fraud)
SET potential_fraud= CASE
	WHEN UPPER(TRIM(@potential_fraud)) = 'YES' THEN 1
    WHEN UPPER(TRIM(@potential_fraud)) = 'NO' THEN 0
ELSE 0
END;
SELECT concat('Loaded', COUNT(*), 'Providers') AS Status FROM providers;
SELECT concat('Potential Frauds:', SUM(potential_fraud), ' (', ROUND(SUM(potential_fraud) * 100 / COUNT(*), 2), '%)') 
AS Stats FROM providers;

-- 2. LOAD BENEFICIARIES
-- Notes: 
--   - Dates are DD-MM-YY (e.g., 01-01-43 = 2043-01-01)
--   - DOD = 'NA' for alive patients
--   - Chronic conditions: 1 = Yes, 2 = No
TRUNCATE TABLE beneficiaries;
LOAD DATA LOCAL INFILE 'C:/Users/dell/JupyterProjects/Projects/fraud_detection_using_sql/data/Train_Beneficiarydata-1542865627584.csv'
INTO TABLE beneficiaries
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS 
(
    bene_id, @dob, @dod, @gender, @race, @renal_disease_indicator,
    @state, @county, @no_of_months_part_a_cov, @no_of_months_part_b_cov,
    @chronic_cond_alzheimer, @chronic_cond_heartfailure, @chronic_cond_kidney_disease,
    @chronic_cond_cancer, @chronic_cond_obstr_pulmonary, @chronic_cond_depression,
    @chronic_cond_diabetes, @chronic_cond_ischemic_heart, @chronic_cond_osteoporasis,
    @chronic_cond_rheumatoidarthritis, @chronic_cond_stroke,
    @ip_annual_reimbursement_amt, @ip_annual_deductible_amt,
    @op_annual_reimbursement_amt, @op_annual_deductible_amt
)
SET
	-- Convert DD-MM-YY to a proper DATE:
    dob= str_to_date(@dob, '%Y-%d-%m'),
    -- Handle NA as NULL for death data:
    dod= CASE
		WHEN upper(TRIM(@dod)) = 'NA' OR @dod = '' THEN NULL
        ELSE str_to_date(@dod, '%Y-%d-%m')
	END,
    -- keeping these columns as strings (codes not numbers)
    gender = TRIM(@gender),
    race = TRIM(@race),
    renal_disease_indicator= TRIM(@renal_disease_indicator),
    state= TRIM(@state),
    county= TRIM(@county),
    -- Numeric fields
    no_of_months_part_a_cov = CAST(@no_of_months_part_a_cov AS UNSIGNED),
    no_of_months_part_b_cov = CAST(@no_of_months_part_b_cov AS UNSIGNED),
    -- Chronic conditions: 1 = Yes, 2 = No (convert to BOOLEAN)
    chronic_cond_alzheimer = CASE WHEN CAST(@chronic_cond_alzheimer AS UNSIGNED) = 1 THEN 1 ELSE 0 END,
    chronic_cond_heartfailure = CASE WHEN CAST(@chronic_cond_heartfailure AS UNSIGNED) = 1 THEN 1 ELSE 0 END,
    chronic_cond_kidney_disease = CASE WHEN CAST(@chronic_cond_kidney_disease AS UNSIGNED) = 1 THEN 1 ELSE 0 END,
    chronic_cond_cancer = CASE WHEN CAST(@chronic_cond_cancer AS UNSIGNED) = 1 THEN 1 ELSE 0 END,
    chronic_cond_obstr_pulmonary = CASE WHEN CAST(@chronic_cond_obstr_pulmonary AS UNSIGNED) = 1 THEN 1 ELSE 0 END,
    chronic_cond_depression = CASE WHEN CAST(@chronic_cond_depression AS UNSIGNED) = 1 THEN 1 ELSE 0 END,
    chronic_cond_diabetes = CASE WHEN CAST(@chronic_cond_diabetes AS UNSIGNED) = 1 THEN 1 ELSE 0 END,
    chronic_cond_ischemic_heart = CASE WHEN CAST(@chronic_cond_ischemic_heart AS UNSIGNED) = 1 THEN 1 ELSE 0 END,
    chronic_cond_osteoporasis = CASE WHEN CAST(@chronic_cond_osteoporasis AS UNSIGNED) = 1 THEN 1 ELSE 0 END,
    chronic_cond_rheumatoidarthritis = CASE WHEN CAST(@chronic_cond_rheumatoidarthritis AS UNSIGNED) = 1 THEN 1 ELSE 0 END,
    chronic_cond_stroke = CASE WHEN CAST(@chronic_cond_stroke AS UNSIGNED) = 1 THEN 1 ELSE 0 END,
    -- Annual amounts
    ip_annual_reimbursement_amt = CAST(@ip_annual_reimbursement_amt AS DECIMAL(10,2)),
    ip_annual_deductible_amt = CAST(@ip_annual_deductible_amt AS DECIMAL(10,2)),
    op_annual_reimbursement_amt = CAST(@op_annual_reimbursement_amt AS DECIMAL(10,2)),
    op_annual_deductible_amt = CAST(@op_annual_deductible_amt AS DECIMAL(10,2));

SELECT CONCAT('Loaded ', COUNT(*), ' beneficiaries') as Status FROM beneficiaries;

-- 3. LOAD INPATIENT CLAIMS
TRUNCATE TABLE inpatient_claims;
LOAD DATA LOCAL INFILE 'C:/Users/dell/JupyterProjects/Projects/fraud_detection_using_sql/data/Train_Inpatientdata-1542865627584.csv'
INTO TABLE inpatient_claims
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    bene_id, claim_id, @claim_start_dt, @claim_end_dt, provider_id,
    @insc_claim_amt_reimbursed, @attending_physician, @operating_physician, @other_physician,
    @admission_dt, clm_admit_diagnosis_code, @deductible_amt_paid,
    @discharge_dt, diagnosis_group_code,
    clm_diagnosis_code_1, clm_diagnosis_code_2, clm_diagnosis_code_3,
    clm_diagnosis_code_4, clm_diagnosis_code_5, clm_diagnosis_code_6,
    clm_diagnosis_code_7, clm_diagnosis_code_8, clm_diagnosis_code_9,
    clm_diagnosis_code_10, clm_procedure_code_1, clm_procedure_code_2,
    clm_procedure_code_3, clm_procedure_code_4, clm_procedure_code_5,
    clm_procedure_code_6
)
SET 
	-- convert DD-MM-YY dates
    claim_start_dt= str_to_date(@claim_start_dt, '%Y-%d-%m'),
    claim_end_dt= str_to_date(@claim_end_dt, '%Y-%d-%m'),
    admission_dt = STR_TO_DATE(@admission_dt, '%Y-%d-%m'),
    discharge_dt = STR_TO_DATE(@discharge_dt, '%Y-%d-%m'),
    -- Handle NA in physican fields
    attending_physician= CASE WHEN UPPER(TRIM(@attending_physician)) = 'NA' THEN NULL ELSE TRIM(@attending_physician) END,
    operating_physician = CASE WHEN UPPER(TRIM(@operating_physician)) = 'NA' THEN NULL ELSE TRIM(@operating_physician) END,
    other_physician = CASE WHEN UPPER(TRIM(@other_physician)) = 'NA' THEN NULL ELSE TRIM(@other_physician) END,
    
    -- Amount fields
    insc_claim_amt_reimbursed = CAST(@insc_claim_amt_reimbursed AS DECIMAL(10,2)),
    deductible_amt_paid = CAST(@deductible_amt_paid AS DECIMAL(10,2));

SELECT CONCAT('Loaded ', COUNT(*), ' inpatient claims') as Status FROM inpatient_claims;

-- 4. LOAD OUTPATIENT CLAIMS
TRUNCATE TABLE outpatient_claims;

LOAD DATA LOCAL INFILE 'C:/Users/dell/JupyterProjects/Projects/fraud_detection_using_sql/data/Train_Outpatientdata-1542865627584.csv'
INTO TABLE outpatient_claims
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    bene_id, claim_id, @claim_start_dt, @claim_end_dt, provider_id,
    @insc_claim_amt_reimbursed, @attending_physician, @operating_physician, @other_physician,
    clm_diagnosis_code_1, clm_diagnosis_code_2, clm_diagnosis_code_3,
    clm_diagnosis_code_4, clm_diagnosis_code_5, clm_diagnosis_code_6,
    clm_diagnosis_code_7, clm_diagnosis_code_8, clm_diagnosis_code_9,
    clm_diagnosis_code_10, clm_procedure_code_1, clm_procedure_code_2,
    clm_procedure_code_3, clm_procedure_code_4, clm_procedure_code_5,
    clm_procedure_code_6, @deductible_amt_paid, clm_admit_diagnosis_code
)
SET 
    -- Convert DD-MM-YY dates
    claim_start_dt = STR_TO_DATE(@claim_start_dt, '%Y-%d-%m'),
    claim_end_dt = STR_TO_DATE(@claim_end_dt, '%Y-%d-%m'),
    
    -- Handle 'NA' in physician fields
    attending_physician = CASE WHEN UPPER(TRIM(@attending_physician)) = 'NA' THEN NULL ELSE TRIM(@attending_physician) END,
    operating_physician = CASE WHEN UPPER(TRIM(@operating_physician)) = 'NA' THEN NULL ELSE TRIM(@operating_physician) END,
    other_physician = CASE WHEN UPPER(TRIM(@other_physician)) = 'NA' THEN NULL ELSE TRIM(@other_physician) END,
    
    -- Amount fields
    insc_claim_amt_reimbursed = CAST(@insc_claim_amt_reimbursed AS DECIMAL(10,2)),
    deductible_amt_paid = CAST(@deductible_amt_paid AS DECIMAL(10,2));

SELECT CONCAT('Loaded ', COUNT(*), ' outpatient claims') as Status FROM outpatient_claims;

-- 5. VERIFICATION
SET FOREIGN_KEY_CHECKS = 1;

SELECT 'DATA LOAD SUMMARY' as '';
SELECT 
    (SELECT COUNT(*) FROM providers) as providers,
    (SELECT SUM(potential_fraud) FROM providers) as fraudsters,
    (SELECT COUNT(*) FROM beneficiaries) as beneficiaries,
    (SELECT COUNT(*) FROM inpatient_claims) as inpatient_claims,
    (SELECT COUNT(*) FROM outpatient_claims) as outpatient_claims;

-- Show sample joined data
SELECT 'Sample: Inpatient claims with fraud status' as '';
SELECT 
    c.claim_id,
    c.bene_id,
    c.provider_id,
    p.potential_fraud,
    c.claim_start_dt,
    c.insc_claim_amt_reimbursed
FROM inpatient_claims c
JOIN providers p ON c.provider_id = p.provider_id
WHERE p.potential_fraud = 1
LIMIT 10;

-- Check for claims after death (potential fraud)
SELECT 'Claims after death (potential fraud signal)' as '';
SELECT 
    c.claim_id,
    c.bene_id,
    c.provider_id,
    c.claim_start_dt,
    b.dod
FROM inpatient_claims c
JOIN beneficiaries b ON c.bene_id = b.bene_id
WHERE b.dod IS NOT NULL 
  AND c.claim_start_dt > b.dod
LIMIT 10;
