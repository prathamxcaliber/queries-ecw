-- ============================================================================
-- Patients Query - SPIKE TEST for Pending Issues
-- ============================================================================
-- Test all possible fixes for the 7 remaining patient mismatches
-- Run this query and check if the fixes work before updating main query
-- ============================================================================

-- Test for patientId 278882
SELECT
    p.pid AS patientId,
    
    -- ============================================================================
    -- FIX 1: ethnicity (currently shows code "ASKU", should show "Declined to Specify")
    -- ============================================================================
    -- CURRENT (WRONG):
    p.ethnicity AS ethnicity_current,
    
    -- PROPOSED FIX (manual mapping since no lookup table found):
    CASE 
        WHEN p.ethnicity = 'ASKU' THEN 'Declined to Specify'
        WHEN p.ethnicity = 'H' THEN 'Hispanic or Latino'
        WHEN p.ethnicity = 'NH' THEN 'Not Hispanic or Latino'
        WHEN p.ethnicity = 'UNK' THEN 'Unknown'
        ELSE p.ethnicity
    END AS ethnicity_fixed,
    
    -- ============================================================================
    -- FIX 2: needsTranslator (currently 0, should be 1)
    -- ============================================================================
    -- CURRENT (WRONG):
    ISNULL(p.bTranslator, 0) AS needsTranslator_current,
    
    -- PROPOSED FIX - check raw value:
    p.bTranslator AS bTranslator_raw,
    
    -- ============================================================================
    -- FIX 3: primaryCareProvider 
    -- Currently: "PATEL, JITESH, V"
    -- Expected: "Patel MD, Jitesh, V" (proper case + credentials)
    -- ============================================================================
    -- CURRENT (WRONG):
    ISNULL(
        doc_att.PrintName,
        ISNULL(u_att.ulname, '') +
        CASE WHEN ISNULL(u_att.suffix,'') <> '' THEN ' ' + u_att.suffix ELSE '' END +
        ', ' + ISNULL(u_att.ufname,'') +
        CASE WHEN ISNULL(u_att.uminitial,'') <> '' THEN ', ' + u_att.uminitial ELSE '' END
    ) AS primaryCareProvider_current,
    
    -- PROPOSED FIX (proper case + credentials from degreeCredentials):
    ISNULL(
        doc_att.PrintName,
        -- Proper case for last name (capitalize first letter only)
        UPPER(LEFT(u_att.ulname, 1)) + LOWER(SUBSTRING(u_att.ulname, 2, LEN(u_att.ulname))) +
        -- Add credentials/suffix after last name with space
        CASE 
            WHEN ISNULL(u_att.degreeCredentials,'') <> '' THEN ' ' + u_att.degreeCredentials
            WHEN ISNULL(u_att.suffix,'') <> '' THEN ' ' + u_att.suffix
            ELSE '' 
        END +
        ', ' + ISNULL(u_att.ufname,'') +
        CASE WHEN ISNULL(u_att.uminitial,'') <> '' THEN ', ' + u_att.uminitial ELSE '' END
    ) AS primaryCareProvider_fixed,
    
    -- Debug fields:
    u_att.ulname AS att_lastname,
    u_att.ufname AS att_firstname,
    u_att.uminitial AS att_middle,
    u_att.degreeCredentials AS att_credentials,
    u_att.suffix AS att_suffix,
    doc_att.PrintName AS att_printname,
    
    -- ============================================================================
    -- FIX 4: primaryServiceLocation (currently 0, should be 3)
    -- ============================================================================
    -- CURRENT (WRONG):
    ISNULL(p.pmcId, 0) AS primaryServiceLocation_current,
    
    -- Test alternative sources:
    p.pmcId AS pmcId_raw,
    p.DefFeeSchId AS DefFeeSchId_option,
    p.AttendingDoctorId AS AttendingDoctorId_option,
    u.primaryservicelocation AS primaryservicelocation_from_users,
    
    -- ============================================================================
    -- FIX 5: referringProvider 
    -- Currently: "" (empty)
    -- Expected: "Need, Updated Information"
    -- ============================================================================
    -- CURRENT (WRONG):
    ISNULL(
        doc_ref.PrintName,
        ISNULL(u_ref.ulname, '') +
        CASE WHEN ISNULL(u_ref.suffix,'') <> '' THEN ' ' + u_ref.suffix ELSE '' END +
        ', ' + ISNULL(u_ref.ufname,'') +
        CASE WHEN ISNULL(u_ref.uminitial,'') <> '' THEN ', ' + u_ref.uminitial ELSE '' END
    ) AS referringProvider_current,
    
    -- PROPOSED FIX (proper case + credentials):
    ISNULL(
        doc_ref.PrintName,
        CASE 
            WHEN u_ref.ulname IS NOT NULL THEN
                UPPER(LEFT(u_ref.ulname, 1)) + LOWER(SUBSTRING(u_ref.ulname, 2, LEN(u_ref.ulname))) +
                CASE 
                    WHEN ISNULL(u_ref.degreeCredentials,'') <> '' THEN ' ' + u_ref.degreeCredentials
                    WHEN ISNULL(u_ref.suffix,'') <> '' THEN ' ' + u_ref.suffix
                    ELSE '' 
                END +
                ', ' + ISNULL(u_ref.ufname,'') +
                CASE WHEN ISNULL(u_ref.uminitial,'') <> '' THEN ', ' + u_ref.uminitial ELSE '' END
            ELSE ''
        END
    ) AS referringProvider_fixed,
    
    -- Debug fields:
    p.refPrId,
    u_ref.ulname AS ref_lastname,
    u_ref.ufname AS ref_firstname,
    u_ref.degreeCredentials AS ref_credentials,
    
    -- ============================================================================
    -- FIX 6: renderingProvider
    -- Currently: "" (empty)
    -- Expected: "Need, Updated Information"
    -- ============================================================================
    -- CURRENT (WRONG):
    ISNULL(
        doc_rend.PrintName,
        ISNULL(u_rend.ulname, '') +
        CASE WHEN ISNULL(u_rend.suffix,'') <> '' THEN ' ' + u_rend.suffix ELSE '' END +
        ', ' + ISNULL(u_rend.ufname,'') +
        CASE WHEN ISNULL(u_rend.uminitial,'') <> '' THEN ', ' + u_rend.uminitial ELSE '' END
    ) AS renderingProvider_current,
    
    -- PROPOSED FIX (proper case + credentials):
    ISNULL(
        doc_rend.PrintName,
        CASE 
            WHEN u_rend.ulname IS NOT NULL THEN
                UPPER(LEFT(u_rend.ulname, 1)) + LOWER(SUBSTRING(u_rend.ulname, 2, LEN(u_rend.ulname))) +
                CASE 
                    WHEN ISNULL(u_rend.degreeCredentials,'') <> '' THEN ' ' + u_rend.degreeCredentials
                    WHEN ISNULL(u_rend.suffix,'') <> '' THEN ' ' + u_rend.suffix
                    ELSE '' 
                END +
                ', ' + ISNULL(u_rend.ufname,'') +
                CASE WHEN ISNULL(u_rend.uminitial,'') <> '' THEN ', ' + u_rend.uminitial ELSE '' END
            ELSE ''
        END
    ) AS renderingProvider_fixed,
    
    -- Debug fields:
    p.rendPrId,
    u_rend.ulname AS rend_lastname,
    u_rend.ufname AS rend_firstname,
    u_rend.degreeCredentials AS rend_credentials

FROM mobiledoc.dbo.patients p
LEFT JOIN mobiledoc.dbo.users u ON u.uid = p.pid
-- Doctor joins for provider name resolution
LEFT JOIN mobiledoc.dbo.doctors doc_att ON doc_att.doctorID = p.AttendingDoctorId
LEFT JOIN mobiledoc.dbo.doctors doc_ref ON doc_ref.doctorID = p.refPrId
LEFT JOIN mobiledoc.dbo.doctors doc_rend ON doc_rend.doctorID = p.rendPrId
-- Fallback: build provider name from users
LEFT JOIN mobiledoc.dbo.users u_att ON u_att.updid = p.AttendingDoctorId
LEFT JOIN mobiledoc.dbo.users u_ref ON u_ref.updid = p.refPrId
LEFT JOIN mobiledoc.dbo.users u_rend ON u_rend.updid = p.rendPrId

WHERE p.pid = 278882;

-- ============================================================================
-- FIX 7: insurances[0].feeScheduleName (test separately - requires subquery)
-- ============================================================================
-- This is nested in JSON, testing the join logic for slidingscalesetup
SELECT 
    p.pid,
    idr.Id AS ptInsId,
    ins.FeeSchedId,
    
    -- CURRENT (WRONG):
    ISNULL(sss.FeeSchedule, '') AS feeScheduleName_current,
    
    -- Alternative source if slidingscalesetup doesn't map:
    sss.FeeSchedule AS slidingscalesetup_value,
    sss.FeeScheduleId AS slidingscalesetup_id,
    
    -- Check if there's a description field in insurance table:
    ins.insuranceName,
    ins.FeeSchedId
    
FROM mobiledoc.dbo.patients p
JOIN mobiledoc.dbo.insurancedetail idr ON idr.pid = p.pid AND idr.DeleteFlag = 0
JOIN mobiledoc.dbo.insurance ins ON ins.insId = idr.insid
LEFT JOIN mobiledoc.dbo.slidingscalesetup sss ON sss.FeeScheduleId = ins.FeeSchedId
WHERE p.pid = 278882
  AND idr.SeqNo = 1;  -- First insurance record

-- ============================================================================
-- EXPECTED RESULTS to verify:
-- ============================================================================
-- ethnicity_fixed: "Declined to Specify"
-- needsTranslator_current should already be 1 (check bTranslator_raw)
-- primaryCareProvider_fixed: "Patel MD, Jitesh, V"
-- primaryServiceLocation: one of the alternative fields should show 3
-- referringProvider_fixed: "Need, Updated Information" (check if data exists)
-- renderingProvider_fixed: "Need, Updated Information" (check if data exists)
-- feeScheduleName_current: "4. Selfpay"
-- ============================================================================

-- ============================================================================
-- After running this spike, report which fixes work:
-- 1. ethnicity mapping
-- 2. needsTranslator - is bTranslator already 1?
-- 3. primaryCareProvider proper case + credentials
-- 4. primaryServiceLocation - which field has value 3?
-- 5. referringProvider - does data exist? Is formatting correct?
-- 6. renderingProvider - does data exist? Is formatting correct?
-- 7. feeScheduleName - does slidingscalesetup return "4. Selfpay"?
-- ============================================================================
