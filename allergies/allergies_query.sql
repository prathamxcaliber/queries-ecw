-- ============================================================
-- Allergies Query
-- Returns fields matching the EHR Allergies API payload shape.
-- One row per allergy per patient.
-- ============================================================
-- Tables joined:
--   allergies          : core record (patientID, drug, allergy, itemID,
--                        SMDamConceptID, ndc_code, allergytype, type,
--                        status, criticality, onsetdate, displayIndex)
--   allergytypes       : AllergyType string via allergies.allergytype = allergytypes.id
--   allergycriticality : criticality string  via allergies.criticality = allergycriticality.id
-- ============================================================
-- Column mappings:
--   AllergyType        → allergytypes.type       (lookup: allergies.allergytype → allergytypes.id)
--   SMDamConceptID     → allergies.SMDamConceptID (int; 0 when NULL)
--   Type               → allergies.type           (char → int cast)
--   allergyDesc        → allergies.allergy        (column name differs from API field name)
--   criticality        → allergycriticality.TYPE  (lookup: allergies.criticality → allergycriticality.id)
--   drug               → allergies.drug
--   ndc_code           → allergies.ndc_code
--   onsetdate          → allergies.onsetdate      (varchar; already stored as MM/dd/yyyy)
--   rxId               → allergies.itemID         (int → varchar)
--   rxImgName          → ''                       (no DB column; EHR returns '' — API layer)
--   rxImgTitle         → ''                       (no DB column; EHR returns '' — API layer)
--   status             → allergies.status
-- ============================================================

-- ── Lookup: find patientId from a known allergy record ──────────────────
-- Run this block first to identify the correct patientId:
--
--   SELECT TOP 20 patientID, drug, allergy, itemID, ndc_code, status
--   FROM mobiledoc.dbo.allergies
--   WHERE itemID = 217922                          -- rxId from EHR sample
--      OR ndc_code = '00225-0440-34'               -- ndc_code from EHR sample
--      OR drug LIKE '%Pen-Kera%';                  -- drug name from EHR sample
--
-- Then replace @patientId below with the patientID returned.
-- ─────────────────────────────────────────────────────────────────────────

DECLARE @patientId INT = 327910;   -- Replace with target patientId

SELECT
    ISNULL(at2.type, '')                           AS AllergyType,
    ISNULL(a.SMDamConceptID, 0)                    AS SMDamConceptID,
    CAST(ISNULL(NULLIF(RTRIM(a.type), ''), '0') AS int)  AS Type,
    ISNULL(a.allergy, '')                          AS allergyDesc,
    ISNULL(ac.TYPE, '')                            AS criticality,
    ISNULL(a.drug, '')                             AS drug,
    ISNULL(a.ndc_code, '')                         AS ndc_code,
    ISNULL(a.onsetdate, '')                        AS onsetdate,
    CAST(ISNULL(a.itemID, 0) AS varchar)           AS rxId,
    ''                                             AS rxImgName,
    ''                                             AS rxImgTitle,
    ISNULL(a.status, '')                           AS [status]

FROM mobiledoc.dbo.allergies a

    LEFT JOIN mobiledoc.dbo.allergytypes at2
        ON  at2.id = a.allergytype

    LEFT JOIN mobiledoc.dbo.allergycriticality ac
        ON  ac.id = a.criticality

WHERE a.patientID = @patientId

ORDER BY ISNULL(a.displayIndex, 9999), a.itemID;
