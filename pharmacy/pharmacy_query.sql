-- ============================================================
-- Pharmacy Query
-- Returns fields matching the EHR Pharmacy API payload shape.
-- Single SELECT -- one row per pharmacy.
-- ============================================================
-- Tables joined:
--   pharmacy : core pharmacy record (pmcid PK)
-- ============================================================
-- Column mappings:
--   Id                  → pharmacy.pmcid
--   Name                → pharmacy.pharmacyname
--   Addr1               → pharmacy.pharmacyaddress
--   Addr2               → pharmacy.pharmacyaddress2
--   City                → pharmacy.pharmacycity
--   State               → pharmacy.pharmacystate
--   Zip                 → pharmacy.pharmacyzip  (varchar in DB; EHR returns numeric)
--   Tel                 → pharmacy.pharmacyphone
--   Fax                 → pharmacy.pharmacyfax
--   faxDialingCountryId → pharmacy.faxDialingCountryId (int → varchar; '' when NULL)
--   EMail               → pharmacy.pharmacyemail
--   FaxPrefix           → pharmacy.pharmacyfaxprefix
--   NCPDPID             → pharmacy.NCPDPID  (varchar in DB; EHR returns numeric)
--   MailOrderPharmacy   → pharmacy.MailOrderPharmacy  (tinyint)
--   pharmacyPhoneExt    → pharmacy.pharmacyPhoneExt
--   ServiceLevel        → pharmacy.ServiceLevel
--   EPrescribeEnabled   → pharmacy.EPrescribeEnabled  (tinyint)
--   EPCSEnabled         → pharmacy.EPCSEnabled  (tinyint)
--   EPrescribeEnabledBy → pharmacy.EPrescribeEnabledBy
--   PillPassLocation    → pharmacy.PillPassLocation  (tinyint)
--   CrossStreet         → pharmacy.CrossStreet
-- ============================================================

DECLARE @pharmacyId INT = 2312;   -- Replace with target pmcid

SELECT
    ph.pmcid                                                               AS Id,
    ISNULL(ph.pharmacyname, '')                                            AS [Name],
    ISNULL(ph.pharmacyaddress, '')                                         AS Addr1,
    ISNULL(ph.pharmacyaddress2, '')                                        AS Addr2,
    ISNULL(ph.pharmacycity, '')                                            AS City,
    ISNULL(ph.pharmacystate, '')                                           AS [State],
    ISNULL(ph.pharmacyzip, '')                                             AS Zip,
    ISNULL(ph.pharmacyphone, '')                                           AS Tel,
    ISNULL(ph.pharmacyfax, '')                                             AS Fax,
    ISNULL(CAST(ph.faxDialingCountryId AS varchar), '')                    AS faxDialingCountryId,
    ISNULL(ph.pharmacyemail, '')                                           AS EMail,
    ISNULL(ph.pharmacyfaxprefix, '')                                       AS FaxPrefix,
    TRY_CAST(NULLIF(ph.NCPDPID, '') AS bigint)                             AS NCPDPID,
    ISNULL(ph.MailOrderPharmacy, 0)                                        AS MailOrderPharmacy,
    ISNULL(ph.pharmacyPhoneExt, '')                                        AS pharmacyPhoneExt,
    ISNULL(ph.ServiceLevel, '')                                            AS ServiceLevel,
    ISNULL(ph.EPrescribeEnabled, 0)                                        AS EPrescribeEnabled,
    ISNULL(ph.EPCSEnabled, 0)                                              AS EPCSEnabled,
    ISNULL(ph.EPrescribeEnabledBy, '')                                     AS EPrescribeEnabledBy,
    ISNULL(ph.PillPassLocation, 0)                                         AS PillPassLocation,
    ISNULL(ph.CrossStreet, '')                                             AS CrossStreet

FROM mobiledoc.dbo.pharmacy ph

WHERE ph.pmcid = @pharmacyId
  AND ISNULL(ph.delFlag, 0) = 0;
