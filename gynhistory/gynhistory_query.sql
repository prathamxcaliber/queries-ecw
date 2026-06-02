-- ============================================================
-- GYN History Query
-- Returns fields matching the EHR GYNHistory API payload shape.
-- One row per GYN history item per patient.
-- ============================================================
-- EHR shape: { patientId, gynHistory: [ { date, symptom, notes,
--               hxFlag, denyFlag }, ... ] }
-- ============================================================
-- Tables joined:
--   gynhistory    : core record (encounterId, itemId, Notes,
--                   hxFlag, denyFlag)
--   enc           : patient filter + encounter date
--                   JOIN enc.encounterID = gynhistory.encounterId
--                   → enc.patientID = @patientId, enc.date → date
--   items         : symptom name via gynhistory.itemId = items.itemID
-- ============================================================
-- Column mappings:
--   date          → CONVERT(varchar, enc.date, 101)   (MM/DD/YYYY)
--   symptom       → items.itemName
--   notes         → gynhistory.Notes
--   hxFlag        → CAST(gynhistory.hxFlag AS varchar)
--   denyFlag      → CAST(gynhistory.denyFlag AS varchar)
-- ============================================================

-- ── Lookup: find a patientId with GYN history records ───────────────────
--
--   SELECT TOP 10 e.patientID, g.encounterId, g.itemId, g.Notes, e.date
--   FROM mobiledoc.dbo.gynhistory g WITH (NOLOCK)
--   JOIN mobiledoc.dbo.enc e WITH (NOLOCK) ON e.encounterID = g.encounterId
--   ORDER BY e.patientID;
--
-- ─────────────────────────────────────────────────────────────────────────

DECLARE @patientId INT = 275734;

SELECT DISTINCT
    CONVERT(varchar, enc.date, 101)                           AS date,
    ISNULL(i.itemName, '')                                    AS symptom,
    ISNULL(gh.Notes, '')                                      AS notes,
    CAST(gh.hxFlag AS varchar)                                AS hxFlag,
    CAST(gh.denyFlag AS varchar)                              AS denyFlag

FROM mobiledoc.dbo.gynhistory gh

    JOIN mobiledoc.dbo.enc enc
        ON  enc.encounterID = gh.encounterId
        AND enc.patientID   = @patientId

    LEFT JOIN mobiledoc.dbo.items i
        ON  i.itemID              = gh.itemId
        AND ISNULL(i.deleteFlag, 0) = 0

ORDER BY date DESC, symptom;
