-- ============================================================
-- OB History Query
-- Returns fields matching the EHR OBHistory API payload shape.
-- One row per OB history item per patient.
-- ============================================================
-- EHR shape: { patientId, obHistory: [ { date, symptom, notes }, ... ] }
-- ============================================================
-- Tables joined:
--   obhistory     : core record (encounterId, itemId, Notes)
--   enc           : patient filter + encounter date
--                   JOIN enc.encounterID = obhistory.encounterId
--                   → enc.patientID = @patientId, enc.date → date
--   items         : symptom name via obhistory.itemId = items.itemID
--   obhistoryids  : fallback symptom name (OB-specific label table)
-- ============================================================
-- Column mappings:
--   date          → CONVERT(varchar, enc.date, 101)   (MM/DD/YYYY)
--   symptom       → ISNULL(i.itemName, ohids.NAME)
--   notes         → obhistory.Notes
-- ============================================================

-- ── Lookup: find a patientId with OB history records ────────────────────
--
--   SELECT TOP 10 e.patientID, o.encounterId, o.itemId, o.Notes, e.date
--   FROM mobiledoc.dbo.obhistory o WITH (NOLOCK)
--   JOIN mobiledoc.dbo.enc e WITH (NOLOCK) ON e.encounterID = o.encounterId
--   ORDER BY e.patientID;
--
-- ─────────────────────────────────────────────────────────────────────────

DECLARE @patientId INT = 275734;

SELECT DISTINCT
    CONVERT(varchar, enc.date, 101)                           AS date,
    ISNULL(i.itemName, ISNULL(ohids.NAME, ''))                AS symptom,
    ISNULL(oh.Notes, '')                                      AS notes

FROM mobiledoc.dbo.obhistory oh

    JOIN mobiledoc.dbo.enc enc
        ON  enc.encounterID = oh.encounterId
        AND enc.patientID   = @patientId

    LEFT JOIN mobiledoc.dbo.items i
        ON  i.itemID              = oh.itemId
        AND ISNULL(i.deleteFlag, 0) = 0

    LEFT JOIN mobiledoc.dbo.obhistoryids ohids
        ON  ohids.itemId = oh.itemId

ORDER BY date DESC, symptom;
