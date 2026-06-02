-- ============================================================
-- Family Member History Query
-- Returns fields matching the EHR FamilyMemberHistory API payload shape.
-- One row per family history entry per patient.
-- ============================================================
-- EHR shape: { familyHistories: [ { itemValue }, ... ] }
-- ============================================================
-- Tables joined:
--   familydata    : core record (encounterID, itemID, name,
--                   status, age) — one row per family member
--   enc           : patient filter via
--                   JOIN enc.encounterID = familydata.encounterID
--                   → enc.patientID = @patientId
--   family        : condition per member (itemID → condition)
--                   JOIN family.encounterID = familydata.encounterID
--                       AND family.name = familydata.name
--   items         : condition name via family.itemID = items.itemID
-- ============================================================
-- Column mappings:
--   itemValue     → name + ': ' + status + ' ' + age + ' yrs' + ', ' + items.itemName
--                   e.g. "Father: deceased 26 yrs, arthritis"
--                   age stored as plain number in familydata.age; ' yrs' appended
-- ============================================================
-- NOTE: itemValue is constructed by concatenating familydata columns.
--       All parts are null-guarded; empty parts are omitted from the
--       string to avoid trailing separators.
-- ============================================================

-- ── Lookup: find a patientId with family history records ────────────────
--
--   SELECT TOP 10 e.patientID, fd.encounterID, fd.name, fd.status,
--                 fd.age, fd.itemID
--   FROM mobiledoc.dbo.familydata fd WITH (NOLOCK)
--   JOIN mobiledoc.dbo.enc e WITH (NOLOCK) ON e.encounterID = fd.encounterID
--   ORDER BY e.patientID;
--
-- ─────────────────────────────────────────────────────────────────────────

DECLARE @patientId INT = 275734;

SELECT DISTINCT
    ISNULL(fd.name, '')
        + CASE WHEN ISNULL(fd.status, '') <> '' THEN ': ' + fd.status ELSE '' END
        + CASE WHEN ISNULL(fd.age,    '') <> '' THEN ' '  + fd.age + ' yrs' ELSE '' END
        + CASE WHEN ISNULL(i.itemName, '') <> '' THEN ', ' + i.itemName ELSE '' END
                                                          AS itemValue

FROM mobiledoc.dbo.familydata fd

    JOIN mobiledoc.dbo.enc enc
        ON  enc.encounterID = fd.encounterID
        AND enc.patientID   = @patientId

    -- family links the condition (itemID → items) to the member via name + encounterID
    LEFT JOIN mobiledoc.dbo.family f
        ON  f.encounterID = fd.encounterID
        AND f.name        = fd.name

    LEFT JOIN mobiledoc.dbo.items i
        ON  i.itemID              = f.itemID
        AND ISNULL(i.deleteFlag, 0) = 0

ORDER BY itemValue;
