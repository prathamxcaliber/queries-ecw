-- ============================================================
-- Hospital History Query
-- Returns fields matching the EHR HospitalHistory API payload shape.
-- One row per hospitalization entry per patient.
-- ============================================================
-- EHR shape: { hospitalizations: [ { reason, hospDate }, ... ] }
-- ============================================================
-- Tables joined:
--   hospitalization  : core record (encounterID, reason, date, displayIndex)
--   enc              : patient link via hospitalization.encounterID = enc.encounterID
-- ============================================================
-- Column mappings:
--   reason    → hospitalization.reason
--   hospDate  → hospitalization.date  (varchar, stored as MM/YY e.g. '05/22')
-- ============================================================

-- ── Lookup: find a patientId with hospitalization records ────────────────
--
--   SELECT TOP 10 e.patientID, h.reason, h.date
--   FROM mobiledoc.dbo.hospitalization h WITH (NOLOCK)
--   JOIN mobiledoc.dbo.enc e WITH (NOLOCK)
--     ON e.encounterID = h.encounterID
--   WHERE ISNULL(h.reason, '') <> ''
--   ORDER BY e.patientID;
--
-- ─────────────────────────────────────────────────────────────────────────

DECLARE @patientId INT = 275735;

SELECT
    ISNULL(h.reason, '')    AS reason,
    ISNULL(h.date,   '')    AS hospDate

FROM mobiledoc.dbo.hospitalization h

    JOIN mobiledoc.dbo.enc e
        ON  e.encounterID   = h.encounterID

WHERE e.patientID           = @patientId

ORDER BY ISNULL(h.displayIndex, 9999), h.date;
