-- ============================================================
-- Immunization Query
-- Returns fields matching the EHR Immunization API payload shape.
-- One row per immunization record per patient.
-- ============================================================
-- EHR shape: [ { Name, givenDate, ImmStatus, ImmunizationId,
--                givenById, DoseNumber, ImmInjName }, ... ]
-- ============================================================
-- Tables joined:
--   immunizations  : core record (ImmunizationId, patientId, ItemId,
--                    givenDate, immstatus, GivenById, DoseNumber,
--                    vaccinename, deleteFlag, ...)
--   items          : vaccine display name via immunizations.ItemId = items.itemID
--                    (used as fallback if vaccinename is empty)
-- ============================================================
-- Column mappings:
--   Name           → ISNULL(imz.vaccinename, i.itemName)
--   givenDate      → CONVERT(varchar, imz.givenDate, 101)  (MM/DD/YYYY)
--   ImmStatus      → CAST(imz.immstatus AS varchar)
--   ImmunizationId → CAST(imz.ImmunizationId AS varchar)
--   givenById      → CAST(ISNULL(imz.GivenById, 0) AS varchar)
--   DoseNumber     → ISNULL(imz.DoseNumber, '0')
--   ImmInjName     → ISNULL(imz.vaccinename, i.itemName)  (same source as Name)
-- ============================================================

-- ── Lookup: find a patientId with immunization records ───────────────────
--
--   SELECT TOP 10 patientId, ImmunizationId, vaccinename, givenDate, immstatus
--   FROM mobiledoc.dbo.immunizations WITH (NOLOCK)
--   WHERE ISNULL(deleteFlag, 0) = 0
--   ORDER BY patientId;
--
-- ─────────────────────────────────────────────────────────────────────────

DECLARE @patientId INT = 275734;

SELECT
    ISNULL(imz.vaccinename, ISNULL(i.itemName, ''))         AS Name,
    ISNULL(CONVERT(varchar, imz.givenDate, 101), '')         AS givenDate,
    CAST(imz.immstatus AS varchar)                           AS ImmStatus,
    CAST(imz.ImmunizationId AS varchar)                      AS ImmunizationId,
    CAST(ISNULL(imz.GivenById, 0) AS varchar)                AS givenById,
    ISNULL(imz.DoseNumber, '0')                              AS DoseNumber,
    ISNULL(imz.vaccinename, ISNULL(i.itemName, ''))         AS ImmInjName

FROM mobiledoc.dbo.immunizations imz

    LEFT JOIN mobiledoc.dbo.items i
        ON  i.itemID              = imz.ItemId
        AND ISNULL(imz.ItemId, 0) > 0
        AND ISNULL(i.deleteFlag, 0) = 0

WHERE imz.patientId             = @patientId
  AND ISNULL(imz.deleteFlag, 0) = 0

ORDER BY imz.givenDate DESC, imz.ImmunizationId;
