DECLARE @DoctorId INT = 35712;
DECLARE @StartDate DATE = '2026-04-08';
DECLARE @EndDate   DATE = '2026-10-08';

SET DATEFIRST 1;

WITH DateRange AS (
    SELECT @StartDate AS SlotDate
    UNION ALL
    SELECT DATEADD(DAY, 1, SlotDate)
    FROM DateRange
    WHERE SlotDate < @EndDate
),

-- Pull schedule rules; includes facilityId from workhours for WorkHour.facilityId
Schedule_Raw AS (
    SELECT
        ws.UserId                            AS doctorID,
        w.Weekday,
        LTRIM(RTRIM(v.VisitTypeId))          AS VisitTypeId,
        CAST(v.StartTime AS TIME)            AS StartTime,
        CAST(v.EndTime   AS TIME)            AS EndTime,
        v.TotalVisits,
        ws.StartDate                         AS schedStart,
        ws.EndDate                           AS schedEnd,
        ISNULL(w.facilityId, 0)              AS facilityId   -- WorkHour.facilityId source
    FROM mobiledoc.dbo.workinghourssets ws
    JOIN mobiledoc.dbo.workhours w       ON ws.SetId = w.SetId
    JOIN mobiledoc.dbo.visittyperules v  ON w.Id = v.SetId
    WHERE ws.UserId = @DoctorId
      AND ws.DeleteFlag = 0
      AND ws.StartDate <= @EndDate
      AND (ws.EndDate IS NULL OR ws.EndDate >= @StartDate)
),

Slots AS (
    SELECT DISTINCT
        sr.doctorID,
        dr.SlotDate,
        sr.VisitTypeId,
        sr.StartTime     AS SlotTime,
        sr.EndTime,
        sr.TotalVisits,
        sr.facilityId    AS schedFacilityId   -- fallback when enc has no facilityId
    FROM Schedule_Raw sr
    CROSS JOIN DateRange dr
    WHERE sr.Weekday = DATEPART(WEEKDAY, dr.SlotDate)
      AND dr.SlotDate >= sr.schedStart
      AND (sr.schedEnd IS NULL OR dr.SlotDate <= sr.schedEnd)
),

-- Replaces the old GROUP-BY Booked CTE:
--   bookedCount  → COUNT(*) OVER per slot (no aggregation loss)
--   rn = 1       → picks the primary encounter for patient-detail fields
BookedDetail AS (
    SELECT
        e.doctorID,
        CAST(e.date AS DATE)                   AS SlotDate,
        CAST(e.startTime AS TIME)              AS SlotTime,
        LTRIM(RTRIM(e.VisitType))              AS VisitTypeId,
        COUNT(*) OVER (
            PARTITION BY e.doctorID,
                         CAST(e.date AS DATE),
                         CAST(e.startTime AS TIME),
                         LTRIM(RTRIM(e.VisitType))
        )                                      AS bookedCount,
        e.encounterID,
        e.patientID,
        e.STATUS,
        CAST(e.reason       AS VARCHAR(MAX))   AS reason,
        e.POS,
        ISNULL(e.facilityId, 0)                AS encFacilityId,
        e.deptid,
        CAST(e.generalNotes AS VARCHAR(MAX))   AS generalNotes,
        e.encType,
        e.newPt,
        e.ResourceId,
        ROW_NUMBER() OVER (
            PARTITION BY e.doctorID,
                         CAST(e.date AS DATE),
                         CAST(e.startTime AS TIME),
                         LTRIM(RTRIM(e.VisitType))
            ORDER BY e.encounterID
        )                                      AS rn
    FROM mobiledoc.dbo.enc e
    WHERE e.deleteFlag = 0
      AND e.doctorID = @DoctorId
      AND CAST(e.date AS DATE) BETWEEN @StartDate AND @EndDate
      AND e.STATUS NOT LIKE 'CANC%'
)

SELECT
    -- ── Encounter identity ────────────────────────────────────────────────────
    ISNULL('ENC-' + CAST(b.encounterID AS VARCHAR(20)), '')    AS encounterId,
    ISNULL(CAST(b.encounterID AS VARCHAR(20)), '')             AS id,

    -- ── Patient fields (empty for free slots) ────────────────────────────────
    ISNULL(CAST(b.patientID AS VARCHAR(20)), '')               AS patId,
    CASE WHEN up.uid IS NOT NULL
         THEN LTRIM(RTRIM(ISNULL(up.ulname, '')))
              + CASE WHEN up.suffix IS NOT NULL AND up.suffix != ''
                     THEN ' ' + LTRIM(RTRIM(up.suffix)) ELSE '' END
              + ', '
              + LTRIM(RTRIM(ISNULL(up.ufname, '')))
              + CASE WHEN up.uminitial IS NOT NULL AND up.uminitial != ''
                     THEN ', ' + LTRIM(RTRIM(up.uminitial)) ELSE '' END
         ELSE ''
    END                                                        AS patName,
    ISNULL(CONVERT(varchar(10), CAST(up.dob AS datetime), 101), '') AS dob,
    ISNULL(up.uemail,    '')                                   AS email,
    ISNULL(up.umobileno, '')                                   AS cellphoneNo,
    ISNULL(up.upPhone,   '')                                   AS upPhone,

    -- ── Doctor fields ─────────────────────────────────────────────────────────
    CAST(s.doctorID AS VARCHAR(20))                            AS doctorId,
    ISNULL(d.PrintName, '')                                    AS doctorName,

    -- ── Facility (enc facility takes priority; falls back to schedule facility)
    CAST(
        ISNULL(NULLIF(b.encFacilityId, 0), NULLIF(s.schedFacilityId, 0))
    AS VARCHAR(20))                                            AS facilityId,
    ISNULL(f.Name, '')                                         AS facilityName,

    -- ── Slot datetime — yyyy-MM-dd HH:mm:ss ──────────────────────────────────
    FORMAT(
        CAST(CONVERT(varchar(10), s.SlotDate, 23)
             + ' ' + CONVERT(varchar(8), s.SlotTime, 108) AS DATETIME),
        'yyyy-MM-dd HH:mm:ss'
    )                                                          AS start,
    FORMAT(
        CAST(CONVERT(varchar(10), s.SlotDate, 23)
             + ' ' + CONVERT(varchar(8), s.EndTime, 108) AS DATETIME),
        'yyyy-MM-dd HH:mm:ss'
    )                                                          AS [end],

    -- ── Visit type ────────────────────────────────────────────────────────────
    ISNULL(s.VisitTypeId, '')                                  AS visitId,
    ISNULL(s.VisitTypeId, '')                                  AS visitTypeId,

    -- ── Encounter detail ──────────────────────────────────────────────────────
    ISNULL(b.reason, '')                                       AS reason,
    ISNULL(b.STATUS, '')                                       AS [status],
    ISNULL(b.STATUS, '')                                       AS pStatus,       -- ECW uses STATUS as pStatus fallback
    ISNULL(CAST(b.ResourceId AS VARCHAR(20)),
           CAST(s.doctorID   AS VARCHAR(20)))                  AS resources,
    ISNULL(CAST(b.POS AS VARCHAR(10)), '0')                    AS POS,
    ISNULL(b.generalNotes, '')                                 AS generalNotes,
    ISNULL(CAST(b.encType AS VARCHAR(10)), '')                 AS encType,
    CASE WHEN b.encounterID IS NULL THEN ''
         WHEN b.newPt = 1 THEN 'Y'
         ELSE 'N'
    END                                                        AS newPt,
    ISNULL(CAST(b.deptid AS VARCHAR(10)), '0')                 AS deptId,

    -- ── Capacity ──────────────────────────────────────────────────────────────
    s.TotalVisits,
    ISNULL(b.bookedCount, 0)                                   AS bookedCount,
    (s.TotalVisits - ISNULL(b.bookedCount, 0))                 AS totalVisit,    -- remaining capacity (API: totalVisit)

    -- ── WorkHour metadata ─────────────────────────────────────────────────────
    CAST(s.doctorID AS VARCHAR(20))                            AS resourceId,
    s.doctorID                                                 AS userId,
    CASE WHEN ISNULL(b.bookedCount, 0) = 0 THEN 1 ELSE 0 END  AS free,          -- 1=available, 0=booked
    DATEPART(WEEKDAY, s.SlotDate) % 7                          AS nWeekDay,      -- 0=Sun … 6=Sat
    DATEDIFF(MINUTE, s.SlotTime, s.EndTime)                    AS size,          -- slot duration in minutes
    ''                                                         AS background,    -- no background column in mobiledoc schema

    -- ── Internal diagnostic columns (not in API) ──────────────────────────────
    CASE
        WHEN ISNULL(b.bookedCount, 0) = 0             THEN 'FREE'
        WHEN ISNULL(b.bookedCount, 0) < s.TotalVisits THEN 'PARTIAL'
        ELSE                                               'BOOKED'
    END                                                        AS slotStatus

FROM Slots s

-- Primary encounter for patient-detail fields (rn=1 picks earliest encounterID per slot)
LEFT JOIN BookedDetail b
    ON  s.doctorID                = b.doctorID
    AND s.SlotDate                = b.SlotDate
    AND s.SlotTime                = b.SlotTime
    AND ISNULL(s.VisitTypeId, '') = ISNULL(b.VisitTypeId, '')
    AND b.rn                      = 1

-- Doctor display name
LEFT JOIN mobiledoc.dbo.doctors d
    ON  d.doctorID = s.doctorID

-- Facility name (resolve facilityId from enc first, then schedule)
LEFT JOIN mobiledoc.dbo.edi_facilities f
    ON  f.Id        = ISNULL(NULLIF(b.encFacilityId, 0), NULLIF(s.schedFacilityId, 0))
    AND f.DeleteFlag = 0

-- Patient demographics (join directly on patientID — users.uid = patients.pid in ECW)
LEFT JOIN mobiledoc.dbo.users up
    ON  up.uid = b.patientID

ORDER BY
    s.SlotDate,
    s.SlotTime,
    s.VisitTypeId
OFFSET 0 ROWS
FETCH NEXT 100 ROWS ONLY
OPTION (MAXRECURSION 200);