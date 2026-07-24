-- ============================================================
-- Vitals Query
-- Returns fields matching the EHR Vitals API payload shape.
-- One row per vital sign reading per encounter.
-- ============================================================
-- EHR shape: { encounterID, patientId,
--               vitals: [ { name, value, unit, isAbnormal }, ... ] }
-- ============================================================
-- Tables joined:
--   vitals   : core record (encounterID, vitalID, value)
--              vitals.vitalID = items.itemID directly
--   enc      : patient context (encounterID -> patientID)
--   items    : vital sign label via items.itemID = vitals.vitalID
--              items.itemName = short code (Temp, BP, HR, Ht, Wt, etc.)
-- ============================================================
-- Column mappings:
--   name       -> items.itemName  (short code -- see mismatches note)
--   value      -> vitals.value
--   unit       -> '' (data_gap: not stored in DB; API-layer config per vitalID)
--   isAbnormal -> NULL (data_gap: requires vitalrange low/high vs patient
--                       age+sex; computed at API layer)
-- ============================================================
-- MISMATCHES (documented in mismatches.json):
--   name: items.itemName stores abbreviations for some vitals:
--     Temp -> "Temperature", BP -> "Blood Pressure", HR -> "Heart Rate",
--     RR -> "Respiratory Rate", Ht -> "Height", Wt -> "Weight",
--     HC -> "Head Circumference", "Oxygen sat %" -> "Oxygen Saturation",
--     "Ht-cm" -> "Height (cm)", "Wt-kg" -> "Weight (kg)",
--     "Wt %" -> "Weight %", "Ht %" -> "Height %"
--     Full names are mapped at EHR API layer; not in DB.
--   unit: no DB column stores unit strings (F, min, mm Hg, lbs, Index, etc.)
--   isAbnormal: computed range comparison; no stored boolean in DB
-- ============================================================

-- Lookup: find an encounterID with vital records
--
--   SELECT TOP 10 v.encounterID, e.patientID, v.vitalID, i.itemName, v.value
--   FROM mobiledoc.dbo.vitals v WITH (NOLOCK)
--   JOIN mobiledoc.dbo.enc e WITH (NOLOCK) ON e.encounterID = v.encounterID
--   LEFT JOIN mobiledoc.dbo.items i WITH (NOLOCK) ON i.itemID = v.vitalID
--   ORDER BY v.encounterID DESC;

DECLARE @encounterID INT = 3257076;
DECLARE @patientId   INT = 278754;

SELECT
    ISNULL(i.itemName, '')                                     AS name,
    ISNULL(v.value, '')                                        AS value,
    ''                                                         AS unit,
    NULL                                                       AS isAbnormal

FROM mobiledoc.dbo.vitals v

    JOIN mobiledoc.dbo.enc enc
        ON  enc.encounterID = v.encounterID
        AND enc.patientID   = @patientId

    LEFT JOIN mobiledoc.dbo.items i
        ON  i.itemID              = v.vitalID
        AND ISNULL(i.deleteFlag, 0) = 0

WHERE v.encounterID = @encounterID

ORDER BY name;
