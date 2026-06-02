-- ============================================================
-- Social History Query
-- Returns fields matching the EHR Social History API payload shape.
-- One row per social history item per patient.
-- ============================================================
-- EHR shape: [{ "socials": [ { "socialName": "Pets:", "socialValue": "..." }, ... ] }]
-- SQL returns flat rows; the outer [{socials:[]}] wrapper is API-layer structural.
-- ============================================================
-- Tables joined:
--   social  : core record (encounterID, catID, itemID, propID, value, displayIndex)
--             Each item has two propID rows (83 = text value, 91 = status/flag).
--             Pivoted and collapsed to one row per item.
--   enc     : resolves patientID from social.encounterID
--   items   : socialName label via social.itemID = items.itemID
--             (items.itemName stores the name; ':' appended to match EHR format)
-- ============================================================
-- Column mappings:
--   socialName  → items.itemName         (stored as-is; already includes ':' in DB)
--   socialValue → COALESCE(val_83, val_91) (propID 83 = text answer; 91 = status flag;
--                 prefer text answer, fall back to status flag)
-- ============================================================
-- Notes:
--   • Multiple encounters per patient → latest enc.date wins (ROW_NUMBER per itemID).
--   • Only items with at least one non-empty value are returned.
--   • items.itemName already stores the trailing colon — do NOT append ':' again.
-- ============================================================

-- ── Get patientId from the known encounterIDs ────────────────────────────
--
-- CHECK 1 — do those encounterIDs exist in enc (ignore deleteFlag)?
--   SELECT encounterID, patientID, deleteFlag
--   FROM mobiledoc.dbo.enc
--   WHERE encounterID IN (14523, 21590, 16442);
--
-- CHECK 2 — if CHECK 1 returns rows, use that patientID here.
--   If deleteFlag=1 for those rows, the enc JOIN is filtering them out.
--   Test without the deleteFlag filter:
--   SELECT DISTINCT e.patientID
--   FROM mobiledoc.dbo.social s
--   JOIN mobiledoc.dbo.enc e ON e.encounterID = s.encounterID
--   WHERE s.value IS NOT NULL AND s.value <> '';
--
-- CHECK 3 — confirm items.itemName exists for those itemIDs:
--   SELECT itemID, itemName FROM mobiledoc.dbo.items
--   WHERE itemID IN (10889,10620,10621,10622,10626,72640,72495,72492,72493);
--
-- ─────────────────────────────────────────────────────────────────────────

DECLARE @patientId INT = 275734;   -- Verified: patient with social history data

;WITH social_pivot AS (
    -- Collapse propID 83 and 91 into one row per (encounterID, itemID)
    SELECT
        s.encounterID,
        s.itemID,
        s.displayIndex,
        MAX(CASE WHEN s.propID = 83 THEN NULLIF(LTRIM(RTRIM(s.value)), '') END) AS val_83,
        MAX(CASE WHEN s.propID = 91 THEN NULLIF(LTRIM(RTRIM(s.value)), '') END) AS val_91
    FROM mobiledoc.dbo.social s
    GROUP BY s.encounterID, s.itemID, s.displayIndex
),
ranked AS (
    -- For each item, pick the most recent encounter's value
    SELECT
        sp.itemID,
        sp.displayIndex,
        COALESCE(sp.val_83, sp.val_91, '')  AS socialValue,
        ROW_NUMBER() OVER (
            PARTITION BY sp.itemID
            ORDER BY e.date DESC, sp.encounterID DESC
        )                                    AS rn
    FROM social_pivot sp
    JOIN mobiledoc.dbo.enc e
        ON  e.encounterID          = sp.encounterID
        AND ISNULL(e.deleteFlag, 0) = 0
    WHERE e.patientID = @patientId
      AND COALESCE(sp.val_83, sp.val_91, '') <> ''
)
SELECT
    ISNULL(i.itemName, '')                  AS socialName,
    r.socialValue

FROM ranked r

    LEFT JOIN mobiledoc.dbo.items i
        ON  i.itemID              = r.itemID
        AND ISNULL(i.deleteFlag, 0) = 0

WHERE r.rn = 1

ORDER BY ISNULL(r.displayIndex, 9999), r.itemID;

