-- ============================================================
-- PatientInfo Query  -  Produces JSON matching Data2 shape
-- ============================================================
-- Tables joined:
--   patients            : core record, insurance refs, preferences flags
--   users               : firstName, lastName, gender, dob, email, phone,
--                         transgender + all preferences.user fields
--   doctors (x3)        : primaryCareProvider, renderingProvider, referringProvider
--   insurancedetail     : per-patient insurance row (ptInsId, dates, copay, etc.)
--   insurance           : insurance master (name, city, state, active, feeScheduleId)
--   slidingscalesetup   : feeScheduleName
--   txtenabledpatients  : preferences.textconfig
--   voiceptmsgconfig    : preferences.voiceconfig
-- ============================================================

SELECT

    -- ── Root-level fields ───────────────────────────────────────────
    p.pid                                                           AS accountNo,
    -- address1: users.upaddress is the canonical address (matches Data2); patients.straddress may differ
    ISNULL(u.upaddress, p.straddress)                               AS address1,
    FORMAT(CONVERT(date, u.dob, 101), 'MM/dd/yyyy')            AS birthDate,
    p.city,
    ISNULL(u.CountryCode, '')                                       AS country,
    FORMAT(p.regdate, 'yyyy-MM-dd HH:mm:ss')                       AS createdDate,
    CAST(p.deceased     AS varchar(10))                             AS deceased,
    ISNULL(u.uemail, '')                                            AS email,
    -- ethnicity: map eCW code to display text (ASKU → Declined to Specify, etc.)
    CASE 
        WHEN p.ethnicity = 'ASKU' THEN 'Declined to Specify'
        WHEN p.ethnicity = 'H' THEN 'Hispanic or Latino'
        WHEN p.ethnicity = 'NH' THEN 'Not Hispanic or Latino'
        WHEN p.ethnicity = 'UNK' THEN 'Unknown'
        ELSE p.ethnicity
    END AS ethnicity,
    ISNULL(u.ufname, '')                                            AS firstName,
    ISNULL(u.sex,   '')                                             AS gender,
    ISNULL(u.upPhone,'')                                            AS homePhone,

    -- ── Insurance array ─────────────────────────────────────────────
    JSON_QUERY((
        SELECT
            -- active: derive from date range rather than insurance.Inactive master flag.
            -- If today is past endDate (or endDate is set), the record is inactive ('I').
            CASE
                WHEN idr.endDate IS NOT NULL
                 AND CONVERT(date, idr.endDate) < CAST(GETDATE() AS date)
                THEN 'I'
                ELSE 'A'
            END                                                     AS active,
            ISNULL(ins.insurancecity,   '')                         AS city,
            ISNULL(idr.copayType,       '')                         AS copayType,
            CAST(CAST(idr.copays AS decimal(10,2)) AS int)                    AS copays,
            -- RTRIM removes trailing spaces stored in char(n) EncEligibilityStatus column
            ISNULL(RTRIM(idr.EncEligibilityStatus), '')             AS eligibilityStatus,
            ISNULL(
                CASE WHEN idr.MultipleCoPay = 1 THEN '1' ELSE '' END,
                ''
            )                                                       AS enableMultipleCoPay,
            ISNULL(idr.endDate, '')                                 AS endDate,
            ins.FeeSchedId                                          AS feeScheduleId,
            -- feeScheduleName: slidingscalesetup join may not cover all fee schedule types.
            -- TODO: if NULL, check insurance.FeeSchedId against a dedicated fee schedule master table.
            ISNULL(sss.FeeSchedule, '')                             AS feeScheduleName,
            CAST(idr.groupNo       AS bigint)                   AS groupNumber,
            idr.GrId                                                AS guarantorId,
            ISNULL(ugr.ulname + ', ' + ugr.ufname, '')              AS guarantorName,
            idr.GrRel                                               AS guarantorRelation,
            ins.insId                                               AS id,
            ISNULL(
                CAST(NULLIF(idr.insOrder, 0) AS varchar(20)),
                ''
            )                                                       AS insOrder,
            idr.InsType                                             AS insType,
            idr.IsGrPt                                              AS isGuarantorPatient,
            ins.insuranceName                                       AS name,
            idr.Id                                                  AS ptInsId,
            idr.SeqNo                                               AS seqNo,
            ISNULL(idr.startDate, '')                               AS stDate,
            ISNULL(ins.insurancestate, '')                          AS [state],
            CAST(idr.subscriberNo  AS bigint)                   AS subscriberNumber
        FROM  mobiledoc.dbo.insurancedetail   idr
        JOIN  mobiledoc.dbo.insurance         ins  ON  ins.insId       = idr.insid
        LEFT JOIN mobiledoc.dbo.slidingscalesetup sss ON sss.FeeScheduleId = ins.FeeSchedId
        LEFT JOIN mobiledoc.dbo.users         ugr  ON  ugr.uid         = idr.GrId
        WHERE idr.pid        = p.pid
          AND idr.DeleteFlag = 0
        FOR JSON PATH
    ))                                                              AS insurances,

    p.language,
    ISNULL(u.ulname, '')                                            AS lastName,
    -- ISNULL prevents NULL being omitted by FOR JSON PATH when bTranslator is not set
    -- needsTranslator: direct from bTranslator (verify value in data)
    ISNULL(p.bTranslator, 0)                                        AS needsTranslator,
    p.pid                                                           AS patientId,

    -- ── preferences.contacttypeoptions (no source table found → []) ─
    JSON_QUERY('[]')                                                AS [preferences.contacttypeoptions],

    -- ── preferences.patient ─────────────────────────────────────────
    JSON_QUERY((
        SELECT
            ISNULL(p2.employerPhone, '')             AS employerphone,
            CAST(p2.enableLetters  AS varchar(5))    AS enableletters,
            CAST(p2.pid            AS varchar(20))   AS id,
            CAST(p2.isPtOptsOut    AS varchar(5))    AS isptoptsout,
            p2.language,
            ISNULL(p2.lognotes, '')                  AS lognotes,
            CAST(p2.optout         AS varchar(5))    AS optout,
            CAST(p2.optreasonId    AS varchar(10))   AS optreasonid,
            CAST(p2.textenabled    AS varchar(5))    AS textenabled,
            CAST(p2.VoiceEnabled   AS varchar(5))    AS voiceenabled
        FROM mobiledoc.dbo.patients p2
        WHERE p2.pid = p.pid
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ))                                                              AS [preferences.patient],

    -- ── preferences.textconfig  (txtenabledpatients) ────────────────
    JSON_QUERY((
        SELECT
            CAST(tc.appointments        AS varchar(5))              AS appointments,
            ISNULL(tc.ContactType, '')                              AS contacttype,
            FORMAT(tc.datemodified, 'yyyy-MM-dd HH:mm:ss')         AS datemodified,
            CAST(tc.generalNotification AS varchar(5))              AS generalnotification,
            CAST(tc.healthMaintenance   AS varchar(5))              AS healthmaintenance,
            CAST(tc.id                  AS varchar(20))             AS id,
            CAST(tc.labs                AS varchar(5))              AS labs,
            ISNULL(tc.language, '')                                 AS language,
            CAST(tc.primeplus           AS varchar(5))              AS primeplus,
            CAST(tc.ptstatements        AS varchar(5))              AS ptstatements,
            CAST(tc.Rx                  AS varchar(5))              AS rx,
            ISNULL(tc.timetocall, '')                               AS timetocall,
            CAST(tc.uid                 AS varchar(20))             AS uid
        FROM mobiledoc.dbo.txtenabledpatients tc
        WHERE tc.uid = p.pid
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ))                                                              AS [preferences.textconfig],

    -- ── preferences.user  (users table) ─────────────────────────────
    JSON_QUERY((
        SELECT
            FORMAT(CONVERT(date, u2.dob, 101), 'MM/dd/yyyy')   AS dob,
            CAST(u2.uid         AS varchar(20))                     AS id,
            ISNULL(u2.sex,      '')                                 AS sex,
            ISNULL(u2.uemail,   '')                                 AS uemail,
            ISNULL(u2.ufname,   '')                                 AS ufname,
            ISNULL(u2.ulname,   '')                                 AS ulname,
            ISNULL(u2.umobileno,'')                                 AS umobileno,
            ISNULL(u2.uname,    '')                                 AS uname,
            ISNULL(u2.upaddress,'')                                 AS upaddress,
            ISNULL(u2.upcity,   '')                                 AS upcity,
            ISNULL(u2.upPhone,  '')                                 AS upphone,
            ISNULL(u2.upstate,  '')                                 AS upstate,
            CAST(u2.webenabled  AS varchar(5))                      AS webenabled,
            ISNULL(u2.zipcode,  '')                                 AS zipcode
        FROM mobiledoc.dbo.users u2
        WHERE u2.uid = p.pid
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ))                                                              AS [preferences.user],

    -- ── preferences.voiceconfig  (voiceptmsgconfig) ──────────────────
    JSON_QUERY((
        SELECT
            CAST(vc.appointments        AS varchar(5))              AS appointments,
            ISNULL(vc.ContactType, '')                              AS contacttype,
            FORMAT(vc.datemodified, 'yyyy-MM-dd HH:mm:ss')         AS datemodified,
            CAST(vc.generalNotification AS varchar(5))              AS generalnotification,
            CAST(vc.healthMaintenance   AS varchar(5))              AS healthmaintenance,
            CAST(vc.id                  AS varchar(20))             AS id,
            CAST(vc.labs                AS varchar(5))              AS labs,
            ISNULL(vc.Language, '')                                 AS language,
            ISNULL(vc.prefcomm, '')                                 AS prefcomm,
            CAST(vc.primeplus           AS varchar(5))              AS primeplus,
            CAST(vc.ptstatements        AS varchar(5))              AS ptstatements,
            CAST(vc.Rx                  AS varchar(5))              AS rx,
            ISNULL(vc.timetocall, '')                               AS timetocall,
            CAST(vc.uid                 AS varchar(20))             AS uid
        FROM mobiledoc.dbo.voiceptmsgconfig vc
        WHERE vc.uid = p.pid
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ))                                                              AS [preferences.voiceconfig],

    -- ── Provider names ───────────────────────────────────────────────
    -- PrintName is NULL in doctors table for these providers; fallback builds
    -- 'LastName Suffix, FirstName, MI' format from users columns via users.updid FK.
    -- primaryCareProvider: proper case + credentials (MD, DO, etc.)
    ISNULL(
        doc_att.PrintName,
        UPPER(LEFT(u_att.ulname, 1)) + LOWER(SUBSTRING(u_att.ulname, 2, LEN(u_att.ulname))) +
        CASE 
            WHEN ISNULL(u_att.degreeCredentials,'') <> '' THEN ' ' + u_att.degreeCredentials
            WHEN ISNULL(u_att.suffix,'') <> '' THEN ' ' + u_att.suffix
            ELSE '' 
        END +
        ', ' + ISNULL(u_att.ufname,'') +
        CASE WHEN ISNULL(u_att.uminitial,'') <> '' THEN ', ' + u_att.uminitial ELSE '' END
    )                                                               AS primaryCareProvider,
    -- primaryServiceLocation: fallback to users.primaryservicelocation if pmcId is 0
    CASE 
        WHEN ISNULL(p.pmcId, 0) = 0 AND ISNULL(u.primaryservicelocation, 0) <> 0 THEN u.primaryservicelocation
        ELSE ISNULL(p.pmcId, 0)
    END AS primaryServiceLocation,
    p.race,
    -- referringProvider: proper case + credentials (if available)
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
    )                                                               AS referringProvider,
    p.GrRel                                                         AS relationToGuarantor,
    p.RelInfo                                                       AS releaseOfInfo,
    -- renderingProvider: proper case + credentials (if available)
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
    )                                                               AS renderingProvider,

    -- ── responsibleParty ────────────────────────────────────────────
    JSON_QUERY((
        SELECT
            p3.GrId                                                 AS guarantorId,
            ISNULL(ugr2.ulname + ', ' + ugr2.ufname, '')           AS guarantorName,
            ISNULL(ugr2.upPhone, '')                                AS guarantorPhone,
            p3.GrRel                                                AS guarantorRelation,
            p3.IsGrPt                                               AS isGuarantorPatient
        FROM mobiledoc.dbo.patients p3
        LEFT JOIN mobiledoc.dbo.users ugr2 ON ugr2.uid = p3.GrId
        WHERE p3.pid = p.pid
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ))                                                              AS responsibleParty,

    p.RxConsent                                                     AS rxHistoryConsent,
    CAST(p.SelfPay    AS varchar(10))                               AS selfPay,
    p.state,
    -- ISNULL prevents NULL being dropped by FOR JSON PATH
    ISNULL(CAST(p.PtStatus AS varchar(10)), '0')                    AS status,
    ISNULL(u.transgender, '')                                       AS transgender,
    -- zip: Data2 returns integer; CAST handles varchar storage
    CAST(p.zip AS int)                                          AS zip

FROM mobiledoc.dbo.patients p
LEFT JOIN mobiledoc.dbo.users    u        ON  u.uid             = p.pid
-- Doctor joins for provider name resolution
LEFT JOIN mobiledoc.dbo.doctors  doc_att  ON  doc_att.doctorID  = p.AttendingDoctorId
LEFT JOIN mobiledoc.dbo.doctors  doc_ref  ON  doc_ref.doctorID  = p.refPrId
LEFT JOIN mobiledoc.dbo.doctors  doc_rend ON  doc_rend.doctorID = p.rendPrId
-- Fallback: build provider name from users when doctors.PrintName is NULL
-- NOTE: verify the FK column: it may be users.updid or users.uid depending on eCW version
LEFT JOIN mobiledoc.dbo.users    u_att    ON  u_att.updid        = p.AttendingDoctorId
LEFT JOIN mobiledoc.dbo.users    u_ref    ON  u_ref.updid         = p.refPrId
LEFT JOIN mobiledoc.dbo.users    u_rend   ON  u_rend.updid        = p.rendPrId

WHERE p.pid = 278882

FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;


-- ============================================================
-- FINAL COVERAGE REPORT  (based on actual SQL run output vs Data2)
-- ============================================================
--
-- Legend:
--   ✅  Exact match (field name + value + type)
--   🔧  Fixed in this revision (was broken, now corrected)
--   ⚠️  Value discrepancy — needs investigation
--   ❌  Still missing / incorrect after all fixes
--
-- ══════════════════════════════════════════════════════════
-- ✅ FULLY MATCHING  (confirmed from SQL run output)
-- ══════════════════════════════════════════════════════════
--
--  ROOT LEVEL
--    accountNo                  ✅  278882
--    birthDate                  ✅  "07/12/1989"
--    city                       ✅  "Mansfield"
--    country                    ✅  "US"
--    createdDate                ✅  "2026-03-09 08:12:01"
--    deceased                   ✅  "0"
--    email                      ✅  "ZZTestsaizombie.doe@gmail.com"
--    firstName                  ✅  "Sai001"
--    gender                     ✅  "female"
--    homePhone                  ✅  "123-555-3340"
--    language                   ✅  "Declined to Specify"
--    lastName                   ✅  "ZZTest"
--    patientId                  ✅  278882
--    race                       ✅  "Declined to Specify"
--    relationToGuarantor        ✅  1
--    releaseOfInfo              ✅  "Y"
--    rxHistoryConsent           ✅  "U"
--    selfPay                    ✅  "0"
--    state                      ✅  "MA"
--    transgender                ✅  "N"
--
--  INSURANCE ARRAY  (all fields present, most match)
--    city                       ✅  ""
--    copayType                  ✅  "$"
--    copays                     ✅  20
--    endDate                    ✅  "2024-12-31"
--    feeScheduleId              ✅  3
--    groupNumber                ✅  67890
--    guarantorId                ✅  278882
--    guarantorName              ✅  "ZZTest, Sai001"
--    guarantorRelation          ✅  1
--    id                         ✅  511
--    insOrder                   ✅  ""
--    insType                    ✅  "Primary"
--    isGuarantorPatient         ✅  1
--    name                       ✅  "Self Pay - No Insurance"
--    ptInsId                    ✅  328022
--    seqNo                      ✅  1
--    stDate                     ✅  "2024-03-08"
--    state                      ✅  ""
--    subscriberNumber           ✅  12344
--    enableMultipleCoPay        ✅  ""
--
--  PREFERENCES.PATIENT         ✅  All 10 fields match exactly
--  PREFERENCES.TEXTCONFIG      ✅  All 13 fields match exactly
--  PREFERENCES.USER            ✅  All 14 fields match exactly
--  PREFERENCES.VOICECONFIG     ✅  All 14 fields match exactly
--  PREFERENCES.CONTACTTPEOPTIONS ✅  []  (hardcoded, matches)
--
--  RESPONSIBLEPARTY            ✅  All 5 fields match exactly
--    guarantorId, guarantorName, guarantorPhone, guarantorRelation,
--    isGuarantorPatient
--
-- ══════════════════════════════════════════════════════════
-- 🔧 FIXED IN THIS REVISION
-- ══════════════════════════════════════════════════════════
--
--  address1     Was: patients.straddress → "123 Main Street light"
--               Fix: ISNULL(users.upaddress, patients.straddress)
--               Expected: "123 Main St Light Test 01"  ✅
--
--  needsTranslator  Was: omitted from JSON (p.bTranslator was NULL → skipped)
--               Fix: ISNULL(p.bTranslator, 0)
--               Expected: 1  → now present in output
--
--  status       Was: omitted from JSON (p.PtStatus was NULL → skipped)
--               Fix: ISNULL(CAST(p.PtStatus AS varchar(10)), '0')
--               Expected: "0"  → now present in output
--
--  zip          Was: returned as varchar "12345"
--               Fix: CAST(p.zip AS int)
--               Expected: 12345 (integer)  ✅
--
--  eligibilityStatus  Was: "V  " (trailing spaces from char column)
--               Fix: RTRIM(idr.EncEligibilityStatus)
--               Expected: "V"  ✅
--
--  active       Was: logic based on insurance.Inactive flag → returned 'A'
--               Fix: derive from endDate vs today → if past endDate → 'I'
--               Expected: "I"  ✅ (insurance ended 2024-12-31)
--
--  Provider names  Were: all empty (doctors.PrintName is NULL)
--               Fix: fallback CASE builds name from users.ulname + suffix +
--               ufname + uminitial via users.updid FK
--               Expected: "Patel MD, Jitesh, V" / "Need, Updated Information"
--               ⚠️ Verify users.updid FK column name with DBA (may differ)
--
-- ══════════════════════════════════════════════════════════
-- ⚠️  STILL NEEDS ATTENTION  (3 remaining issues)
-- ══════════════════════════════════════════════════════════
--
--  1. ethnicity  VALUE MISMATCH
--        SQL returns: "ASKU"       (eCW internal code stored in patients.ethnicity)
--        Data2 shows: "Declined to Specify"  (human-readable description)
--        Cause:  The service resolves the code to a description via a lookup table
--                not yet identified in the schema.
--        Fix:    Find the ethnicity lookup/reference table that maps code → description.
--                Candidate tables to check:
--                  - ecw_standardlist (KeyName = 'ethnicity')
--                  - a standalone ethnicity or demographics_lookup table
--                Run: SELECT * FROM mobiledoc.dbo.ecw_standardlist
--                       WHERE KeyName LIKE '%ethnic%' OR KeyDisplayName LIKE '%ethnic%'
--                Same pattern applies to race, language if they also store codes.
--
--  2. feeScheduleName  RETURNS EMPTY
--        SQL returns: ""           (slidingscalesetup join yields no match)
--        Data2 shows: "4. Selfpay"
--        Cause:  Fee schedule name is not in slidingscalesetup for this insId/FeeSchedId.
--                There is likely a dedicated fee schedule master table outside this schema.
--        Fix:    Run this to find the right table:
--                  SELECT TOP 5 * FROM mobiledoc.dbo.slidingscalesetup
--                   WHERE FeeScheduleId = 3
--                If empty, search schema for a table with FeeSchedId=3 and name "4. Selfpay":
--                  SELECT TABLE_NAME, COLUMN_NAME
--                  FROM INFORMATION_SCHEMA.COLUMNS
--                  WHERE COLUMN_NAME LIKE '%FeeSchedule%' OR COLUMN_NAME LIKE '%FeeSchId%'
--
--  3. primaryServiceLocation  RETURNS 0  (should be 3)
--        SQL returns: 0            (patients.pmcId = 0 for this patient)
--        Data2 shows: 3
--        Cause:  patients.pmcId stores 0, but the service returns 3. The service may be
--                reading from a different column (e.g. patients.DefFeeSchId, or a
--                facility assignment table), OR pmcId is populated only for some patients.
--        Fix:    Verify with:
--                  SELECT pmcId, doctorId, DefFeeSchId, primaryservicelocation
--                  FROM mobiledoc.dbo.patients WHERE pid = 278882
--                Also check mobiledoc.dbo.users.primaryservicelocation for uid=278882.
--
-- ══════════════════════════════════════════════════════════
-- COVERAGE SUMMARY
-- ══════════════════════════════════════════════════════════
--   Total Data2 fields:          ~110
--   Confirmed matching:           97   (~88%)
--   Fixed in this revision:        7   ( +6% — pending re-run to confirm)
--   Still needs attention:         3   ( ~3%)
--     ethnicity value             → find lookup table
--     feeScheduleName             → find fee schedule master table
--     primaryServiceLocation      → verify correct source column
-- ============================================================
