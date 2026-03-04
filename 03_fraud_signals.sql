-- MEDICARE FRAUD DETECTION - FRAUD SIGNALS
USE medicare_fraud;
SELECT 'SIGNAL 1: Claims for Deceased Patients' as '';
SELECT 
	c.claim_id,
    c.provider_id,
    c.bene_id,
    c.claim_start_dt,
    b.dod,
    datediff(c.claim_start_dt, b.dod) as days_after_death,
    c.insc_claim_amt_reimbursed as amount,
    CASE WHEN p.potential_fraud = 1 THEN 'ACTUAL FRAUDSTER' ELSE '' END AS fraudster
FROM inpatient_claims as c
join beneficiaries as b on c.bene_id= b.bene_id
join providers as p on c.provider_id= p.provider_id
where b.dod IS NOT NULL
	AND c.claim_start_dt > b.dod
UNION ALL
SELECT
	c.claim_id,
	c.provider_id,
    c.bene_id,
    c.claim_start_dt,
    b.dod,
    datediff(c.claim_start_dt, b.dod) as days_after_death,
    c.insc_claim_amt_reimbursed as amount,
    CASE WHEN p.potential_fraud = 1 THEN 'ACTUAL FRAUDSTER' ELSE ''  END AS fraudster
FROM outpatient_claims  as c
join beneficiaries as b on c.bene_id = b.bene_id
join providers as p on c.provider_id = p.provider_id
WHERE b.dod IS NOT NULL
	AND c.claim_start_dt > b.dod
ORDER BY days_after_death
LIMIT 20;

-- SIGNAL 2: Unusually High Payments Per Patient
SELECT 'SIGNAL 2: High Payments Per Patient' as '';
SELECT 
	c.provider_id,
    p.potential_fraud as actual_fraudster,
    COUNT(DISTINCT c.bene_id) as unique_patients,
    COUNT(c.claim_id) as total_claims,
    ROUND(SUM(c.insc_claim_amt_reimbursed) / COUNT(DISTINCT c.bene_id), 2) as paid_per_patient
FROM inpatient_claims as c 
join providers as p on c.provider_id= p.provider_id
GROUP BY c.provider_id, p.potential_fraud
HAVING COUNT(DISTINCT c.bene_id) > 5
	AND SUM(c.insc_claim_amt_reimbursed) / COUNT(DISTINCT c.bene_id) >
    (SELECT AVG(insc_claim_amt_reimbursed)* 3 FROM inpatient_claims)
ORDER BY paid_per_patient DESC
LIMIT 20;

-- SIGNAL 3: Patients with Unusually Many Procedures
SELECT 'SIGNAL 3: High_Utilization Patients' AS '';
SELECT
	c.bene_id,
    COUNT(DISTINCT c.claim_id) as procedure_count,
    COUNT(DISTINCT c.provider_id) as different_providers,
    SUM(c.insc_claim_amt_reimbursed) as total_paid,
    GROUP_CONCAT(DISTINCT p.potential_fraud) as fraudsrers_involved
FROM inpatient_claims as c
join providers as p on c.provider_id = p.provider_id
GROUP BY c.bene_id
HAVING COUNT(DISTINCT c.claim_id) > 
	(SELECT AVG(claim_count) * 3 FROM (SELECT COUNT(*) as claim_count FROM inpatient_claims GROUP BY bene_id) t)
ORDER BY procedure_count DESC 
LIMIT 20;

-- SIGNAL 4: Providers with Unusual Diagnosis Patterns
-- (Same diagnosis code on every claim)
SELECT 'SIGNAL 4: Repetitive Diagnosis Pattern' as '';
SELECT 
    c.provider_id,
    p.potential_fraud,
    COUNT(DISTINCT c.claim_id) as total_claims,
    COUNT(DISTINCT c.clm_diagnosis_code_1) as unique_diagnosis_1,
    CASE WHEN COUNT(DISTINCT c.clm_diagnosis_code_1) <= 2 THEN '🔴 HIGH RISK' ELSE '🟢 NORMAL' END as risk_level,
    CASE WHEN p.potential_fraud = 1 THEN '⚠️ ACTUAL FRAUDSTER' ELSE '' END as fraudster
FROM inpatient_claims c
JOIN providers p ON c.provider_id = p.provider_id
WHERE c.clm_diagnosis_code_1 IS NOT NULL AND c.clm_diagnosis_code_1 != ''
GROUP BY c.provider_id, p.potential_fraud
HAVING COUNT(DISTINCT c.claim_id) > 10
   AND COUNT(DISTINCT c.clm_diagnosis_code_1) <= 2
ORDER BY total_claims DESC
LIMIT 20;
-- SIGNAL 5: Providers Treating Only Healthy Patients
-- (No chronic conditions among their patients)
-- Note: 1 = Yes (has condition), 2 = No
SELECT 'SIGNAL 5: Providers Treating Only Healthy Patients' as '';
SELECT 
    c.provider_id,
    p.potential_fraud,
    COUNT(DISTINCT c.bene_id) as total_patients,
    SUM(CASE 
        WHEN b.chronic_cond_alzheimer = 1 
          OR b.chronic_cond_heartfailure = 1
          OR b.chronic_cond_cancer = 1
          OR b.chronic_cond_diabetes = 1
          OR b.chronic_cond_stroke = 1
          OR b.chronic_cond_kidney_disease = 1
          OR b.chronic_cond_obstr_pulmonary = 1
          OR b.chronic_cond_depression = 1
          OR b.chronic_cond_ischemic_heart = 1
          OR b.chronic_cond_osteoporasis = 1
          OR b.chronic_cond_rheumatoidarthritis = 1
        THEN 1 ELSE 0 END) as patients_with_chronic,
    ROUND(
        SUM(CASE 
            WHEN b.chronic_cond_alzheimer = 1 
              OR b.chronic_cond_heartfailure = 1
              OR b.chronic_cond_cancer = 1
              OR b.chronic_cond_diabetes = 1
              OR b.chronic_cond_stroke = 1
              OR b.chronic_cond_kidney_disease = 1
              OR b.chronic_cond_obstr_pulmonary = 1
              OR b.chronic_cond_depression = 1
              OR b.chronic_cond_ischemic_heart = 1
              OR b.chronic_cond_osteoporasis = 1
              OR b.chronic_cond_rheumatoidarthritis = 1
            THEN 1 ELSE 0 END) * 100.0 / COUNT(DISTINCT c.bene_id), 2
    ) as pct_with_chronic
FROM inpatient_claims c
JOIN beneficiaries b ON c.bene_id = b.bene_id
JOIN providers p ON c.provider_id = p.provider_id
GROUP BY c.provider_id, p.potential_fraud
HAVING COUNT(DISTINCT c.bene_id) > 10
   AND pct_with_chronic < 20  -- Less than 20% have chronic conditions
ORDER BY pct_with_chronic ASC
LIMIT 20;

-- SIGNAL 6: Procedure Combinations That Don't Make Sense
SELECT 'SIGNAL 6: Suspicious Procedure Combinations' as '';
WITH procedure_pairs AS (
    SELECT 
        c.provider_id,
        c.clm_procedure_code_1 as proc1,
        c2.clm_procedure_code_1 as proc2,
        COUNT(*) as times_together
    FROM inpatient_claims c
    JOIN inpatient_claims c2 ON c.claim_id = c2.claim_id 
        AND c.clm_procedure_code_1 < c2.clm_procedure_code_1
    WHERE c.clm_procedure_code_1 IS NOT NULL 
      AND c.clm_procedure_code_1 != ''
      AND c2.clm_procedure_code_1 IS NOT NULL 
      AND c2.clm_procedure_code_1 != ''
    GROUP BY c.provider_id, c.clm_procedure_code_1, c2.clm_procedure_code_1
    HAVING COUNT(*) > 5
)
SELECT 
    pp.provider_id,
    pp.proc1,
    pp.proc2,
    pp.times_together,
    CASE WHEN p.potential_fraud = 1 THEN '⚠️ ACTUAL FRAUDSTER' ELSE '' END as fraudster
FROM procedure_pairs pp
JOIN providers p ON pp.provider_id = p.provider_id
ORDER BY pp.times_together DESC
LIMIT 20;