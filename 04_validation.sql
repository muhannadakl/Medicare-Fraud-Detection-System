-- MEDICARE FRAUD DETECTION - VALIDATION
-- Did our flags catch the actual fraudsters?
USE medicare_fraud;
-- Create risk scores based on how many signals each provider triggered

-- SIGNAL 1: Claims for dead people
DROP TEMPORARY TABLE IF EXISTS signal_1;
CREATE TEMPORARY TABLE signal_1 AS
SELECT DISTINCT provider_id, 1 as signal_weight
FROM inpatient_claims c
JOIN beneficiaries b ON c.bene_id = b.bene_id
WHERE b.dod IS NOT NULL AND c.claim_start_dt > b.dod
UNION
SELECT DISTINCT provider_id, 1
FROM outpatient_claims c
JOIN beneficiaries b ON c.bene_id = b.bene_id
WHERE b.dod IS NOT NULL AND c.claim_start_dt > b.dod;

SELECT CONCAT('Signal 1: ', COUNT(DISTINCT provider_id), ' providers flagged (claims after death)') as Status FROM signal_1;

-- SIGNAL 2: High payments per patient (adjusted threshold to 2x)
DROP TEMPORARY TABLE IF EXISTS signal_2;
CREATE TEMPORARY TABLE signal_2 AS
SELECT provider_id, 1 as signal_weight
FROM inpatient_claims
GROUP BY provider_id
HAVING SUM(insc_claim_amt_reimbursed) / COUNT(DISTINCT bene_id) > 
       (SELECT AVG(insc_claim_amt_reimbursed) * 2 FROM inpatient_claims)  -- Changed from 3x to 2x
   AND COUNT(DISTINCT bene_id) > 5;

SELECT CONCAT('Signal 2: ', COUNT(DISTINCT provider_id), ' providers flagged (high payments)') as Status FROM signal_2;

-- SIGNAL 3: Providers who treat patients with excessive procedures (adjusted threshold to 5)
DROP TEMPORARY TABLE IF EXISTS signal_3;
CREATE TEMPORARY TABLE signal_3 AS
SELECT DISTINCT 
    c.provider_id, 
    1 as signal_weight
FROM inpatient_claims c
WHERE c.bene_id IN (
    SELECT bene_id
    FROM inpatient_claims
    GROUP BY bene_id
    HAVING COUNT(DISTINCT claim_id) > 5  -- Changed from 6 to 5
);

SELECT CONCAT('Signal 3: ', COUNT(DISTINCT provider_id), ' providers flagged (high-utilization patients)') as Status FROM signal_3;

-- SIGNAL 4: Repetitive Diagnosis Pattern 
DROP TEMPORARY TABLE IF EXISTS signal_4;
CREATE TEMPORARY TABLE signal_4 AS
SELECT DISTINCT 
    c.provider_id, 
    1 as signal_weight
FROM inpatient_claims c
WHERE c.clm_diagnosis_code_1 IS NOT NULL AND c.clm_diagnosis_code_1 != ''
GROUP BY c.provider_id
HAVING COUNT(DISTINCT c.claim_id) >= 3  -- At least 3 claims
   AND COUNT(DISTINCT c.clm_diagnosis_code_1) <= 2;  -- 2 or fewer unique diagnoses

SELECT CONCAT('Signal 4: ', COUNT(DISTINCT provider_id), ' providers flagged (repetitive diagnoses)') as Status FROM signal_4;

-- Combine all signals
DROP TEMPORARY TABLE IF EXISTS all_signals;
CREATE TEMPORARY TABLE all_signals AS
SELECT provider_id, SUM(signal_weight) as signal_count
FROM (
    SELECT provider_id, signal_weight FROM signal_1
    UNION ALL
    SELECT provider_id, signal_weight FROM signal_2
    UNION ALL
    SELECT provider_id, signal_weight FROM signal_3
    UNION ALL
    SELECT provider_id, signal_weight FROM signal_4
) combined
GROUP BY provider_id;

SELECT CONCAT('Total providers flagged: ', COUNT(*)) as Status FROM all_signals;
SELECT CONCAT('Average signals per flagged provider: ', ROUND(AVG(signal_count), 2)) as Stats FROM all_signals;
SELECT CONCAT('Providers with 1 signal: ', SUM(CASE WHEN signal_count = 1 THEN 1 ELSE 0 END)) as Stats FROM all_signals;
SELECT CONCAT('Providers with 2+ signals: ', SUM(CASE WHEN signal_count >= 2 THEN 1 ELSE 0 END)) as Stats FROM all_signals;

-- VALIDATION RESULTS - Compare against ground truth
-- VALIDATION RESULTS - DO THE FLAGS CATCH REAL FRAUDSTERS?

SELECT 
    CASE 
        WHEN s.signal_count >= 2 THEN 'HIGH RISK (2+ signals)'
        WHEN s.signal_count = 1 THEN 'MEDIUM RISK (1 signal)'
        ELSE 'LOW RISK (0 signals)'
    END as risk_category,
    COUNT(DISTINCT s.provider_id) as providers_flagged,
    SUM(CASE WHEN p.potential_fraud = 1 THEN 1 ELSE 0 END) as actual_fraudsters_caught,
    ROUND(
        SUM(CASE WHEN p.potential_fraud = 1 THEN 1 ELSE 0 END) * 100.0 / 
        NULLIF(COUNT(DISTINCT s.provider_id), 0), 2
    ) as pct_of_flagged_that_are_fraudsters
FROM all_signals s
JOIN providers p ON s.provider_id = p.provider_id
GROUP BY 
    CASE 
        WHEN s.signal_count >= 2 THEN 'HIGH RISK (2+ signals)'
        WHEN s.signal_count = 1 THEN 'MEDIUM RISK (1 signal)'
        ELSE 'LOW RISK (0 signals)'
    END
ORDER BY pct_of_flagged_that_are_fraudsters DESC;

-- OVERALL CATCH RATE
SELECT 
    COUNT(DISTINCT CASE WHEN p.potential_fraud = 1 THEN p.provider_id END) as total_fraudsters_in_data,
    COUNT(DISTINCT CASE WHEN p.potential_fraud = 1 AND s.provider_id IS NOT NULL THEN p.provider_id END) as fraudsters_caught_by_my_flags,
    ROUND(
        COUNT(DISTINCT CASE WHEN p.potential_fraud = 1 AND s.provider_id IS NOT NULL THEN p.provider_id END) * 100.0 /
        NULLIF(COUNT(DISTINCT CASE WHEN p.potential_fraud = 1 THEN p.provider_id END), 0), 2
    ) as percent_of_fraudsters_caught
FROM providers p
LEFT JOIN all_signals s ON p.provider_id = s.provider_id;

-- TOP 20 MOST SUSPICIOUS PROVIDERS (with fraud status)
SELECT 
    s.provider_id,
    s.signal_count,
    p.potential_fraud as is_actual_fraudster,
    CASE 
        WHEN p.potential_fraud = 1 THEN 'ACTUAL FRAUDSTER' 
        ELSE '❌ NOT IN FRAUD LIST' 
    END as fraud_status
FROM all_signals s
JOIN providers p ON s.provider_id = p.provider_id
ORDER BY s.signal_count DESC, p.potential_fraud DESC
LIMIT 20;

-- BREAKDOWN: Which signals are most effective?
SELECT 'SIGNAL EFFECTIVENESS BREAKDOWN' as '';

SELECT 'Signal 1 (Claims after death)' as signal_name,
       COUNT(DISTINCT s.provider_id) as providers_flagged,
       SUM(CASE WHEN p.potential_fraud = 1 THEN 1 ELSE 0 END) as fraudsters_caught,
       ROUND(SUM(CASE WHEN p.potential_fraud = 1 THEN 1 ELSE 0 END) * 100.0 / 
             NULLIF(COUNT(DISTINCT s.provider_id), 0), 2) as accuracy_pct
FROM signal_1 s
JOIN providers p ON s.provider_id = p.provider_id

UNION ALL

SELECT 'Signal 2 (High payments)',
       COUNT(DISTINCT s.provider_id),
       SUM(CASE WHEN p.potential_fraud = 1 THEN 1 ELSE 0 END),
       ROUND(SUM(CASE WHEN p.potential_fraud = 1 THEN 1 ELSE 0 END) * 100.0 / 
             NULLIF(COUNT(DISTINCT s.provider_id), 0), 2)
FROM signal_2 s
JOIN providers p ON s.provider_id = p.provider_id

UNION ALL

SELECT 'Signal 3 (High-utilization patients)',
       COUNT(DISTINCT s.provider_id),
       SUM(CASE WHEN p.potential_fraud = 1 THEN 1 ELSE 0 END),
       ROUND(SUM(CASE WHEN p.potential_fraud = 1 THEN 1 ELSE 0 END) * 100.0 / 
             NULLIF(COUNT(DISTINCT s.provider_id), 0), 2)
FROM signal_3 s
JOIN providers p ON s.provider_id = p.provider_id

UNION ALL

SELECT 'Signal 4 (Repetitive diagnoses)',
       COUNT(DISTINCT s.provider_id),
       SUM(CASE WHEN p.potential_fraud = 1 THEN 1 ELSE 0 END),
       ROUND(SUM(CASE WHEN p.potential_fraud = 1 THEN 1 ELSE 0 END) * 100.0 / 
             NULLIF(COUNT(DISTINCT s.provider_id), 0), 2)
FROM signal_4 s
JOIN providers p ON s.provider_id = p.provider_id

ORDER BY accuracy_pct DESC;

-- FINAL SUMMARY (Store results in variables to avoid temp table reuse)
SELECT 'PROJECT SUMMARY' as '';

-- Get counts into variables
SELECT @total_providers := COUNT(*) FROM providers;
SELECT @total_fraudsters := SUM(potential_fraud) FROM providers;
SELECT @flagged_count := COUNT(*) FROM all_signals;
SELECT @fraudsters_caught := COUNT(DISTINCT s.provider_id)
FROM all_signals s
JOIN providers p ON s.provider_id = p.provider_id
WHERE p.potential_fraud = 1;
SELECT @false_positives := COUNT(DISTINCT s.provider_id)
FROM all_signals s
JOIN providers p ON s.provider_id = p.provider_id
WHERE p.potential_fraud = 0;

-- Display summary
SELECT 
    CONCAT('Total providers in database: ', @total_providers) as '',
    CONCAT('Actual fraudsters: ', @total_fraudsters) as '',
    CONCAT('Providers flagged by system: ', @flagged_count) as '',
    CONCAT('Fraudsters caught: ', @fraudsters_caught) as '',
    CONCAT('False positives: ', @false_positives) as '';

-- TOTAL FRAUDULENT CLAIMS AMOUNT
SELECT 'TOTAL FRAUDULENT CLAIMS AMOUNT' as '';

SELECT 
    SUM(c.insc_claim_amt_reimbursed) as total_fraudulent_claims
FROM inpatient_claims c
JOIN all_signals s ON c.provider_id = s.provider_id
JOIN providers p ON c.provider_id = p.provider_id
WHERE p.potential_fraud = 1;

-- BREAKDOWN BY RISK LEVEL
SELECT 'FRAUDULENT CLAIMS BY RISK LEVEL' as '';

-- Create a temporary copy of all_signals for this query
DROP TEMPORARY TABLE IF EXISTS signals_copy;
CREATE TEMPORARY TABLE signals_copy AS SELECT * FROM all_signals;

SELECT 
    CASE 
        WHEN sc.signal_count >= 2 THEN 'HIGH RISK (2+ signals)'
        WHEN sc.signal_count = 1 THEN 'MEDIUM RISK (1 signal)'
    END as risk_level,
    COUNT(DISTINCT c.claim_id) as number_of_claims,
    SUM(c.insc_claim_amt_reimbursed) as total_amount,
    ROUND(AVG(c.insc_claim_amt_reimbursed), 2) as avg_claim_amount
FROM inpatient_claims c
JOIN signals_copy sc ON c.provider_id = sc.provider_id
JOIN providers p ON c.provider_id = p.provider_id
WHERE p.potential_fraud = 1
GROUP BY risk_level
ORDER BY total_amount DESC;

-- Clean up
DROP TEMPORARY TABLE IF EXISTS signals_copy;