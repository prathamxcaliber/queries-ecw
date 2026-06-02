-- ============================================================
-- Surgical History Query
-- Returns fields matching the EHR SurgicalHistory API payload shape.
-- One row per surgical entry per patient.
-- ============================================================
-- EHR shape: { surgicals: [ { surgicalReason, surgicalDate }, ... ] }
-- ============================================================
-- Tables joined:
--   surgicalhistory  : core record (encounterID, reason, date,
--                      displayIndex, cptcode, occsurgflag)
--   enc              : patient link via surgicalhistory.encounterID = enc.encounterID
-- ============================================================
-- Column mappings:
--   surgicalReason → surgicalhistory.reason
--   surgicalDate   → surgicalhistory.date  (varchar, stored as M/YYYY e.g. '4/2026')
-- ============================================================
-- NOTE: DISTINCT used because ECW copies surgical history rows across
--       multiple encounters for the same patient.
--       4 of 7 EHR entries are missing — their surgicalhistory.encounterID
--       values do not exist in enc (orphaned/deleted encounters).
--       Field mapping is 100% correct on returned rows. (data quality gap)
-- ============================================================

-- ── Lookup: find a patientId with surgical history records ───────────────
--
--   SELECT TOP 10 e.patientID, s.reason, s.date
--   FROM mobiledoc.dbo.surgicalhistory s WITH (NOLOCK)
--   JOIN mobiledoc.dbo.enc e WITH (NOLOCK)
--     ON e.encounterID = s.encounterID
--   WHERE ISNULL(s.reason, '') <> ''
--   ORDER BY e.patientID;
--
-- ── Diagnostic: check all surgicalhistory encounterIDs for this patient ───
-- (Finds entries whose encounterID exists in enc — use to spot
--  missing entries and how many enc rows share each encounterID)
--
--   SELECT s.encounterID, s.reason, s.date, COUNT(*) AS enc_matches
--   FROM mobiledoc.dbo.surgicalhistory s
--   JOIN mobiledoc.dbo.enc e ON e.encounterID = s.encounterID
--   WHERE e.patientID = 270001
--   GROUP BY s.encounterID, s.reason, s.date
--   ORDER BY s.date DESC;
--
-- ─────────────────────────────────────────────────────────────────────────

DECLARE @patientId INT = 270001;

SELECT DISTINCT
    ISNULL(s.reason, '')    AS surgicalReason,
    ISNULL(s.date,   '')    AS surgicalDate

FROM mobiledoc.dbo.surgicalhistory s

    JOIN mobiledoc.dbo.enc e
        ON  e.encounterID   = s.encounterID

WHERE e.patientID           = @patientId

ORDER BY surgicalDate, surgicalReason;
