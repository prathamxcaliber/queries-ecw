-- ============================================================
-- Office Visit Query
-- Returns fields matching the EHR Office Visit API payload shape.
-- Single SELECT -- one row per encounter.
-- ============================================================
-- Tables joined:
--   enc                  : core encounter (encounterID PK, patientID, doctorID, facilityId,
--                          status, visitType, reason, startTime, date, roomNo, encLock,
--                          readytobill, arrivedTime, stsAfterArr, stsAfterChkIn,
--                          timeOut, depTime, timeIn, ResourceId, STATUS)
--   users (patient)      : name, preferredname, sex, dob via enc.patientID
--   users (doctor)       : doctorName via enc.doctorID
--   doctors              : providerCode via enc.doctorID
--   patients             : VoiceEnabled via enc.patientID
--   patientinfo          : RegistryEnabled via enc.patientID
--   encounterdata        : notesStatus via enc.encounterID
--   enc_utctimes         : UTCTimeOut, UTCArrTime, UTCDepTime, UTCTimeIn via enc.encounterID
--   enc_ins_claimdata    : primary insurance link (displayIndex=1) via enc.encounterID
--   insurance            : insuranceName via enc_ins_claimdata.insId
--   edi_facilities       : TimeZoneCode (facilityTimeZone) via enc.facilityId
-- ============================================================
-- Column mappings:
--   encounterId          → enc.encounterID
--   PtOrders             → '0' (hardcoded -- no patient orders table for this context)
--   patientId            → enc.patientID
--   telemedVisit         → '0' (hardcoded -- visitcodes.telemedVisit not mapped per encounter)
--   archivalRunning      → 'false' (hardcoded)
--   archiveMessage       → '' (hardcoded)
--   unreviewed           → '0' (hardcoded -- review tracking not in schema)
--   qmList               → '' (hardcoded -- quality measures list not in schema)
--   healowInsightsSummary→ 'false' (hardcoded)
--   insName              → insurance.insuranceName (primary, displayIndex=1)
--   Voice                → patients.VoiceEnabled
--   RegistryEnabled      → patientinfo.RegistryEnabled
--   encDate              → enc.date formatted as YYYY-MM-DD
--   encLock              → enc.encLock
--   status               → enc.STATUS
--   visitType            → enc.VisitType
--   name                 → users.ulname + ', ' + users.ufname (patient)
--   preferredName        → users.preferredname
--   formattedPrefName    → '' (hardcoded -- EHR-computed display value)
--   reason               → enc.reason
--   time                 → enc.startTime formatted as 'HH:mm:ss' (24-hour)
--   room                 → enc.roomNo
--   sex                  → LOWER(users.sex) -- stored as 'male'/'female'
--   providercode         → doctors.providerCode
--   dob                  → users.dob formatted as MM/dd/yyyy
--   age                  → computed from users.dob
--   notesStatus          → encounterdata.notesstatus
--   readytobill          → enc.readytobill
--   arrivedTime          → enc.arrivedTime as 'HH:mm:ss' (00:00:00 if NULL)
--   stsAfterArr          → enc.stsAfterArr
--   stsAfterChkIn        → enc.stsAfterChkIn
--   doctorId             → enc.doctorID
--   doctorName           → users.ulname + ', ' + users.ufname + ' ' + users.uminitial (doctor)
--   UTCTimeOut           → enc_utctimes.UTCTimeOut as ISO string ('' if NULL)
--   UTCArrTime           → enc_utctimes.UTCArrTime as ISO string ('' if NULL)
--   UTCDepTime           → enc_utctimes.UTCDepTime as ISO string ('' if NULL)
--   UTCTimeIn            → enc_utctimes.UTCTimeIn as ISO string ('' if NULL)
--   factz_arrTime        → '' (hardcoded -- not in schema)
--   facilityTimeZone     → edi_facilities.TimeZoneCode
--   UTClogDate           → latest encstatushistory.UTClogDate ('' if NULL)
--   statusLogTime        → '' (hardcoded -- not stored)
--   statusDuration       → '' (hardcoded -- not stored)
--   timeOut              → enc.timeOut as 'HH:mm:ss' (00:00:00 if NULL)
--   depTime              → enc.depTime as 'HH:mm:ss' (00:00:00 if NULL)
--   timeIn               → enc.timeIn as 'HH:mm:ss' (00:00:00 if NULL)
--   facilityId           → enc.facilityId
--   ResourceId           → enc.ResourceId
--   isBhTimerRunning     → 'false' (hardcoded)
--   encCheckinSource     → 'NO_MODIFICATION' (hardcoded -- not in schema)
--   encCheckinStatus     → '' (hardcoded)
--   encCheckinStatusWithCompletedTime → '' (hardcoded)
--   patDgChangedEncId    → '0' (hardcoded)
--   patDgChanged         → 'no' (hardcoded)
--   patDgChangedMultiple → 'false' (hardcoded)
--   appointmentId        → enc.encounterID (same value as encounterId)
-- ============================================================

DECLARE @encounterId INT = 3256634;   -- Replace with target encounterId

SELECT

    -- ══════════════════════════════════════════════════════
    -- Core encounter / hardcoded defaults
    -- ══════════════════════════════════════════════════════
    CAST(e.encounterID AS varchar)                                         AS encounterId,
    NULL                                                                   AS PtOrders,
    CAST(e.patientID AS varchar)                                           AS patientId,
    CAST(ISNULL(vc.telemedVisit, 0) AS varchar)                            AS telemedVisit,
    NULL                                                                   AS archivalRunning,
    NULL                                                                   AS archiveMessage,
    NULL                                                                   AS unreviewed,
    NULL                                                                   AS qmList,
    NULL                                                                   AS healowInsightsSummary,
    ISNULL(ins.insuranceName, '')                                          AS insName,
    CAST(ISNULL(p.VoiceEnabled, 0) AS varchar)                             AS Voice,
    CAST(ISNULL(pi.RegistryEnabled, 0) AS varchar)                         AS RegistryEnabled,
    CONVERT(varchar(10), CAST(e.[date] AS date), 23)                       AS encDate,
    CAST(ISNULL(e.encLock, 0) AS varchar)                                  AS encLock,
    ISNULL(CAST(e.STATUS AS varchar), '')                                   AS [status],
    ISNULL(e.VisitType, '')                                                AS visitType,

    -- ══════════════════════════════════════════════════════
    -- Patient fields
    -- ══════════════════════════════════════════════════════
    ISNULL(u.ulname + ', ' + u.ufname, '')                                 AS [name],
    ISNULL(u.preferredname, '')                                            AS preferredName,
    NULL                                                                   AS formattedPrefName,
    ISNULL(CAST(e.reason AS varchar(MAX)), '')                              AS reason,

    -- time: 24-hour 'HH:mm:ss' from enc.startTime
    ISNULL(CONVERT(varchar(8), CAST(e.startTime AS time), 108), '')        AS [time],
    ISNULL(e.roomNo, '')                                                   AS room,
    LOWER(ISNULL(u.sex, ''))                                               AS sex,
    ISNULL(d.providerCode, '')                                             AS providercode,
    FORMAT(CONVERT(date, u.dob, 101), 'MM/dd/yyyy')                        AS dob,
    CAST(
        DATEDIFF(year, CAST(u.dob AS date), CAST(GETDATE() AS date))
        - CASE WHEN FORMAT(GETDATE(), 'MMdd') < FORMAT(CAST(u.dob AS date), 'MMdd')
               THEN 1 ELSE 0
          END
    AS varchar) + ' Y'                                                     AS age,

    -- ══════════════════════════════════════════════════════
    -- Encounter status / timing
    -- ══════════════════════════════════════════════════════
    CAST(ISNULL(ed.notesstatus, 0) AS varchar)                             AS notesStatus,
    CAST(ISNULL(e.readytobill, 0) AS varchar)                              AS readytobill,
    ISNULL(CONVERT(varchar(8), CAST(e.arrivedTime AS time), 108), '00:00:00') AS arrivedTime,
    ISNULL(e.stsAfterArr, '')                                              AS stsAfterArr,
    ISNULL(e.stsAfterChkIn, '')                                            AS stsAfterChkIn,

    -- ══════════════════════════════════════════════════════
    -- Doctor fields
    -- ══════════════════════════════════════════════════════
    CAST(e.doctorID AS varchar)                                            AS doctorId,
    ISNULL(
        doc.ulname + ', ' + doc.ufname
        + CASE WHEN ISNULL(doc.uminitial, '') <> '' THEN ' ' + doc.uminitial ELSE '' END,
        ''
    )                                                                      AS doctorName,

    -- ══════════════════════════════════════════════════════
    -- UTC times (from enc_utctimes; '' if NULL)
    -- ══════════════════════════════════════════════════════
    ISNULL(FORMAT(utc.UTCTimeOut, 'MM/dd/yyyy HH:mm:ss'), '')              AS UTCTimeOut,
    ISNULL(FORMAT(utc.UTCArrTime, 'MM/dd/yyyy HH:mm:ss'), '')              AS UTCArrTime,
    ISNULL(FORMAT(utc.UTCDepTime, 'MM/dd/yyyy HH:mm:ss'), '')              AS UTCDepTime,
    ISNULL(FORMAT(utc.UTCTimeIn,  'MM/dd/yyyy HH:mm:ss'), '')              AS UTCTimeIn,

    -- ══════════════════════════════════════════════════════
    -- Facility timezone / status log (hardcoded where not in schema)
    -- ══════════════════════════════════════════════════════
    NULL                                                                   AS factz_arrTime,
    ISNULL(ef.TimeZoneCode, '')                                            AS facilityTimeZone,
    ISNULL(
        (SELECT TOP 1 FORMAT(esh.UTClogDate, 'MM/dd/yyyy HH:mm:ss')
         FROM mobiledoc.dbo.encstatushistory esh
         WHERE esh.encId = e.encounterID
         ORDER BY esh.logDate DESC),
        ''
    )                                                                      AS UTClogDate,
    NULL                                                                   AS statusLogTime,
    NULL                                                                   AS statusDuration,

    -- ══════════════════════════════════════════════════════
    -- Check-out times
    -- ══════════════════════════════════════════════════════
    ISNULL(CONVERT(varchar(8), CAST(e.timeOut AS time), 108), '00:00:00')  AS timeOut,
    ISNULL(CONVERT(varchar(8), CAST(e.depTime AS time), 108), '00:00:00')  AS depTime,
    ISNULL(CONVERT(varchar(8), CAST(e.timeIn  AS time), 108), '00:00:00')  AS timeIn,
    CAST(ISNULL(e.facilityId, 0) AS varchar)                               AS facilityId,
    CAST(ISNULL(e.ResourceId, 0) AS varchar)                               AS ResourceId,

    -- ══════════════════════════════════════════════════════
    -- Hardcoded operational defaults (not stored in DB)
    -- ══════════════════════════════════════════════════════
    NULL                                                                   AS isBhTimerRunning,
    NULL                                                                   AS encCheckinSource,
    NULL                                                                   AS encCheckinStatus,
    NULL                                                                   AS encCheckinStatusWithCompletedTime,
    NULL                                                                   AS patDgChangedEncId,
    NULL                                                                   AS patDgChanged,
    NULL                                                                   AS patDgChangedMultiple,
    CAST(e.encounterID AS varchar)                                         AS appointmentId

FROM mobiledoc.dbo.enc e

    LEFT JOIN mobiledoc.dbo.users u
        ON  u.uid = e.patientID

    LEFT JOIN mobiledoc.dbo.users doc
        ON  doc.uid = e.doctorID

    LEFT JOIN mobiledoc.dbo.doctors d
        ON  d.doctorID = e.doctorID

    LEFT JOIN mobiledoc.dbo.patients p
        ON  p.pid = e.patientID

    LEFT JOIN mobiledoc.dbo.patientinfo pi
        ON  pi.pid = e.patientID

    LEFT JOIN mobiledoc.dbo.encounterdata ed
        ON  ed.encounterID = e.encounterID

    LEFT JOIN mobiledoc.dbo.enc_utctimes utc
        ON  utc.encounterID = e.encounterID

    LEFT JOIN mobiledoc.dbo.enc_ins_claimdata eic
        ON  eic.encId        = e.encounterID
        AND eic.displayIndex = 1

    LEFT JOIN mobiledoc.dbo.insurance ins
        ON  ins.insId = eic.insId

    LEFT JOIN mobiledoc.dbo.edi_facilities ef
        ON  ef.Id                  = e.facilityId
        AND ISNULL(ef.DeleteFlag, 0) = 0

    LEFT JOIN mobiledoc.dbo.visitcodes vc
        ON  vc.CodeId = e.encType

WHERE e.encounterID = @encounterId;
