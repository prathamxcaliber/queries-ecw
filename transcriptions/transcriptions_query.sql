-- ============================================================
-- Transcriptions Query
-- Returns fields matching the EHR Transcriptions API payload shape.
-- Single SELECT -- one row per transcription record.
-- ============================================================
-- Tables joined:
--   transcriptions         : core record (transcriptionid PK, encounterid, status, assignedtoid,
--                            reviewedbyid, TYPE, readstatus, deleteflag)
--   enc                    : encounter date, time, patientID, doctorID
--   users (patient)        : patient name via enc.patientID
--   users (assignedTo)     : assignedTo name via transcriptions.assignedtoid
--   users (reviewedBy)     : reviewedby name via transcriptions.reviewedbyid
--   users (doctor)         : doctorInitial via enc.doctorID
-- ============================================================
-- Column mappings:
--   encounterId            → transcriptions.encounterid
--   name                   → users.ulname + ',' + users.ufname (patient)
--   patientId              → enc.patientID
--   time                   → enc.startTime formatted as 'h:mm tt' (e.g. '2:00 PM')
--   datetime               → enc.date (MM/dd/yyyy) + ' ' + enc.startTime time part ('h:mm tt')
--   assignedTo             → users.ulname + ', ' + users.ufname via assignedtoid ('' if NULL)
--   reviewedby             → users.ulname + ', ' + users.ufname via reviewedbyid ('' if NULL)
--   status                 → transcriptions.status
--   transReadStatus        → transcriptions.readstatus
--   transType              → transcriptions.TYPE
--   transId                → transcriptions.transcriptionid
--   doctorInitial          → users.ulname + ', ' + users.ufname via enc.doctorID
-- ============================================================

DECLARE @encounterId INT = 1740665;   -- Replace with target encounterId

SELECT

    CAST(t.encounterid AS varchar)                               AS encounterId,
    u.ulname + ',' + u.ufname                                   AS [name],
    CAST(e.patientID AS varchar)                                 AS patientId,
    ISNULL(FORMAT(e.startTime, 'h:mm tt'), '')                   AS [time],
    ISNULL(FORMAT(CAST(e.[date] AS date), 'MM/dd/yyyy') + ' ' + FORMAT(e.startTime, 'h:mm tt'), '') AS [datetime],    ISNULL(asgn.ulname + ', ' + asgn.ufname, '')                AS assignedTo,
    ISNULL(rev.ulname  + ', ' + rev.ufname,  '')                AS reviewedby,
    CAST(ISNULL(t.status, 0)     AS varchar)                    AS [status],
    CAST(ISNULL(t.readstatus, 0) AS varchar)                    AS transReadStatus,
    CAST(ISNULL(t.[TYPE], 0)     AS varchar)                    AS transType,
    CAST(t.transcriptionid       AS varchar)                    AS transId,
    ISNULL(doc.ulname + ', ' + doc.ufname, '')                  AS doctorInitial

FROM mobiledoc.dbo.transcriptions t

    JOIN  mobiledoc.dbo.enc e
        ON  e.encounterID          = t.encounterid
        AND ISNULL(e.deleteFlag, 0) = 0

    LEFT JOIN mobiledoc.dbo.users u
        ON  u.uid = e.patientID

    LEFT JOIN mobiledoc.dbo.users asgn
        ON  asgn.uid = t.assignedtoid

    LEFT JOIN mobiledoc.dbo.users rev
        ON  rev.uid = t.reviewedbyid

    LEFT JOIN mobiledoc.dbo.users doc
        ON  doc.uid = e.doctorID

WHERE t.encounterid         = @encounterId
  AND ISNULL(t.deleteflag, 0) = 0;
