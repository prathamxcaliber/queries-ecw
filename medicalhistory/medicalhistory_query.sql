-- ============================================================
-- Medical History Query
-- Returns fields matching the EHR Medical History API payload shape.
-- One row per history entry per patient.
-- ============================================================
-- EHR shape: [{ "histories": [ { "problems": "...", "isStructured": false }, ... ] }]
-- SQL returns flat rows; the outer [{histories:[]}] wrapper is API-layer structural.
-- ============================================================
-- Tables joined:
--   problemlist  : core record (patientId, asmtId, condition, ProblemType,
--                  deleteFlag, displayIndex, SlNo, SNOMED)
--   items        : structured problem name via problemlist.asmtId = items.itemID
--                  (only used when asmtId > 0; unstructured entries use condition column)
-- ============================================================
-- Column mappings:
--   problems      → COALESCE(items.itemName, problemlist.condition)
--                   Structured entries: items.itemName via asmtId
--                   Unstructured entries: problemlist.condition (free text)
--   isStructured  → CASE WHEN asmtId > 0 THEN 1 ELSE 0 END (bit)
--                   asmtId=0 → free-text entry (false); asmtId>0 → linked item (true)
-- ============================================================
-- NOTE on ProblemType filter:
--   problemlist stores both active problems AND medical history.
--   Run this to see what ProblemType values exist for your patient:
--     SELECT DISTINCT ProblemType FROM mobiledoc.dbo.problemlist
--     WHERE patientId = @patientId AND ISNULL(deleteFlag,0) = 0;
--   If medical history uses a specific type (e.g. 'MH'), add:
--     AND pl.ProblemType = 'MH'
-- ============================================================

-- ── Lookup: find a patientId with medical history records ────────────────
--
--   SELECT TOP 10
--       pl.patientId,
--       pl.condition,
--       pl.ProblemType,
--       pl.asmtId,
--       COUNT(*) OVER (PARTITION BY pl.patientId) AS historyCount
--   FROM mobiledoc.dbo.problemlist pl
--   WHERE ISNULL(pl.deleteFlag, 0) = 0
--     AND NULLIF(LTRIM(RTRIM(pl.condition)), '') IS NOT NULL
--   ORDER BY historyCount DESC, pl.patientId;
--
-- ─────────────────────────────────────────────────────────────────────────

DECLARE @patientId INT = 275735;   -- Verified: patient with medical history data

SELECT
    COALESCE(
        NULLIF(LTRIM(RTRIM(i.itemName)), ''),
        ISNULL(LTRIM(RTRIM(pl.condition)), '')
    )                                               AS problems,
    CAST(CASE WHEN ISNULL(pl.asmtId, 0) > 0
              THEN 1 ELSE 0
         END AS bit)                                AS isStructured

FROM mobiledoc.dbo.problemlist pl

    LEFT JOIN mobiledoc.dbo.items i
        ON  i.itemID              = pl.asmtId
        AND ISNULL(pl.asmtId, 0) > 0
        AND ISNULL(i.deleteFlag, 0) = 0

WHERE pl.patientId              = @patientId
  AND ISNULL(pl.deleteFlag, 0)  = 0

ORDER BY ISNULL(pl.displayIndex, 9999), pl.SlNo;
