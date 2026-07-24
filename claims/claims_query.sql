-- ============================================================
-- Claims Query
-- Returns fields matching the EHR Claims API payload shape.
-- ============================================================
-- EHR shape: { InvId, EncounterId, PatientId, InvoiceAmount, balance,
--   payment, copay, PtBalance, PtUnCovAmt, ClaimDate, ServiceDt,
--   encType, encLock, Hl7Id, notes, visittype, visitname,
--   FacilityId, FacilityName, FacilityCode, FacilityPhone, FacilityTaxID,
--   FacilityBillingAdd1, FacilityBillingAdd2, FacilityBillingAdd3,
--   StmtBillingFacilityId, StmtBillingFacilityName,
--   ResourceId, ResourceName, ApptProviderId, ApptProviderName,
--   PayToProviderId, PayToProviderName, RenProviderId, RenProviderName,
--   SupervisorId, SupervisorName, SuprPrvdrName,
--   AddlProvider1, AddlProvider1Name, AddlProvider2, AddlProvider2Name,
--   FeeSchId, FeeSchName, FeeSchDisplayName,
--   ChargeFeeSchId, ChargeFeeSchDisplayName,
--   PayerInsId, PayerInsSeqNo, KenPAC, ClaimStatus, statusDesc,
--   ClaimPayerMedicaidNC, pos, AssignedToId, assignedTo, assignmentType,
--   queueId, queueName, DeleteFlag, Type, ClaimLock, VoidFlag,
--   AnesthesiaFlag, FinChrgFlag, IncidentTo, GivenToCollection,
--   CollectionCode, CollStatus, CollAgencyStatus, SplitClaimId,
--   LineItemPayersEnabled, LineItemTransitionStage, PayRejectStat,
--   IsGrPt, episode_id, ExcludeFromStmt, isopticalclaim, miscRevenueFlag,
--   miscRevenueType, ClosingId, PracticeId, InvRespPartyId, InvRespPartyRel,
--   BilledToId, BilledToIdType, DeptId, DeptName,
--   SplitEncId, SplitEncType, ParentencType,
--   ClaimExists, IsBHISClaim, IsERClaim, isEmployer,
--   HoldReason, PrescriptionNumber, DueFrom }
-- ============================================================
-- Tables joined:
--   edi_invoice           : core claim record (Id PK)
--   enc                   : encType, encLock, Hl7Id, notes, VisitType
--   edi_facilities (inv)  : FacilityName/Code/Phone/TaxID/BillingAdd
--                           via edi_invoice.InvFacilityId
--   edi_facilities (stmt) : StmtBillingFacilityName
--                           via edi_invoice.StmtBillingFacilityId
--   users (u_res)         : ResourceName / ApptProviderName
--                           via edi_invoice.InvResourceId
--   users (u_pay)         : PayToProviderName
--   users (u_ren)         : RenProviderName
--   users (u_sup)         : SupervisorName / SuprPrvdrName
--   users (u_add1/add2)   : AddlProvider1Name / AddlProvider2Name
--   edi_inv_insurance     : PayerInsId, PayerInsSeqNo, KenPAC, ClaimPayerMedicaidNC
--                           (row where InvoiceId = ei.Id, SeqNo derived from BilledToId)
--   departments           : DeptName via invoicedeptid
-- ============================================================
-- Fields hardcoded (no DB column or computed at API layer):
--   FeeSchName, FeeSchDisplayName, ChargeFeeSchDisplayName
--     (fee schedule table absent from filtered CSV)
--   DueFrom     (derived from payer type / fee schedule name; complex API logic)
--   CollAgencyStatus, miscRevenueType, visitname, PrescriptionNumber
--     (no source column found)
--   SplitEncId, SplitEncType, ParentencType (not in edi_invoice/enc; default 0/-1)
--   ClaimExists ('yes'), IsBHISClaim ('NO'), IsERClaim ('NO'), isEmployer (0)
--   HoldReason  (from edi_invoice.stmtholdtype — complex lookup; defaulted '')
-- ============================================================

DECLARE @invId INT = 1144939;

SELECT

    -- ============================================================
    -- Invoice core
    -- ============================================================
    CAST(ei.Id AS varchar)                                                 AS InvId,
    CAST(ei.EncounterId AS varchar)                                        AS EncounterId,
    CAST(ei.PatientId AS varchar)                                          AS PatientId,
    FORMAT(ei.InvoiceAmount, 'N2')                                         AS InvoiceAmount,
    FORMAT(ei.Balance, 'N2')                                               AS balance,
    FORMAT(ei.Payment, 'N2')                                               AS payment,
    FORMAT(ei.copay, 'N2')                                                 AS copay,
    FORMAT(ei.PtBalance, 'N2')                                             AS PtBalance,
    FORMAT(ei.uncoveredAmount, 'N2')                                       AS PtUnCovAmt,

    -- ============================================================
    -- Dates (InvoiceDt -> ClaimDate, ServiceDt -> ServiceDt)
    -- ============================================================
    CONVERT(varchar(10), CAST(ei.InvoiceDt AS date), 23)                   AS ClaimDate,
    CONVERT(varchar(10), CAST(ei.ServiceDt AS date), 23)                   AS ServiceDt,

    -- ============================================================
    -- Encounter context
    -- ============================================================
    CAST(ISNULL(e.encType, 0) AS varchar)                                  AS encType,
    CAST(ISNULL(e.encLock, 0) AS varchar)                                  AS encLock,
    CAST(ISNULL(e.HL7Id, 0) AS varchar)                                    AS Hl7Id,
    ISNULL(CAST(e.Notes AS varchar(MAX)), '')                               AS notes,
    ISNULL(e.VisitType, '')                                                AS visittype,
    ''                                                                     AS visitname,

    -- ============================================================
    -- Facility (via edi_invoice.InvFacilityId)
    -- ============================================================
    CAST(ISNULL(ei.InvFacilityId, 0) AS varchar)                           AS FacilityId,
    ISNULL(ef.Name, '')                                                    AS FacilityName,
    ISNULL(ef.code, '')                                                    AS FacilityCode,
    ISNULL(ef.Tel, '')                                                     AS FacilityPhone,
    ISNULL(ef.FederalTaxID, '')                                            AS FacilityTaxID,
    ISNULL(ef.BillingAddressLine1, '')                                     AS FacilityBillingAdd1,
    ISNULL(ef.BillingAddressLine2, '')                                     AS FacilityBillingAdd2,
    -- FacilityBillingAdd3: "City, State, Zip"
    CASE WHEN ISNULL(ef.BillingCity,'')='' AND ISNULL(ef.BillingState,'')='' AND ISNULL(ef.BillingZip,'')=''
         THEN ''
         ELSE ISNULL(ef.BillingCity,'') + ', ' + ISNULL(ef.BillingState,'') + ', ' + ISNULL(ef.BillingZip,'')
    END                                                                    AS FacilityBillingAdd3,

    -- ============================================================
    -- Statement billing facility
    -- ============================================================
    CAST(ISNULL(ei.StmtBillingFacilityId, 0) AS varchar)                   AS StmtBillingFacilityId,
    ISNULL(ef_stmt.Name, '')                                               AS StmtBillingFacilityName,

    -- ============================================================
    -- Providers
    -- ============================================================
    CAST(ISNULL(ei.InvResourceId, 0) AS varchar)                           AS ResourceId,
    ISNULL(u_res.ulname + ', ' + u_res.ufname, '')                         AS ResourceName,
    CAST(ISNULL(ei.InvResourceId, 0) AS varchar)                           AS ApptProviderId,
    ISNULL(u_res.ulname + ', ' + u_res.ufname, '')                         AS ApptProviderName,
    CAST(ISNULL(ei.PayToProviderId, 0) AS varchar)                         AS PayToProviderId,
    ISNULL(u_pay.ulname + ', ' + u_pay.ufname, '')                         AS PayToProviderName,
    CAST(ISNULL(ei.RenProviderId, 0) AS varchar)                           AS RenProviderId,
    ISNULL(u_ren.ulname + ', ' + u_ren.ufname, '')                         AS RenProviderName,
    CAST(ISNULL(ei.SupervisorId, 0) AS varchar)                            AS SupervisorId,
    ISNULL(u_sup.ulname + ', ' + u_sup.ufname, '')                         AS SupervisorName,
    ISNULL(u_sup.ulname + ', ' + u_sup.ufname, '')                         AS SuprPrvdrName,
    CAST(ISNULL(ei.AddlProvider1, 0) AS varchar)                           AS AddlProvider1,
    ISNULL(u_add1.ulname + ', ' + u_add1.ufname, '')                       AS AddlProvider1Name,
    CAST(ISNULL(ei.AddlProvider2, 0) AS varchar)                           AS AddlProvider2,
    ISNULL(u_add2.ulname + ', ' + u_add2.ufname, '')                       AS AddlProvider2Name,

    -- ============================================================
    -- Fee schedule (table not in filtered CSV -- IDs from edi_invoice)
    -- ============================================================
    CAST(ei.FeeSchId AS varchar)                                           AS FeeSchId,
    NULL                                                                   AS FeeSchName,
    NULL                                                                   AS FeeSchDisplayName,
    CAST(ei.ChargeFeeSchId AS varchar)                                     AS ChargeFeeSchId,
    -- ChargeFeeSchDisplayName: '' when ChargeFeeSchId=0; fee schedule table absent from CSV
    ''                                                                     AS ChargeFeeSchDisplayName,

    -- ============================================================
    -- Payer / insurance (from edi_inv_insurance current payer row)
    -- ============================================================
    CAST(ISNULL(eii.InsId, 0) AS varchar)                                  AS PayerInsId,
    -- PayerInsSeqNo: derive from which tier matches BilledToId
    CAST(
        CASE
            WHEN ei.BilledToId = ei.PrimaryInsId   THEN 1
            WHEN ei.BilledToId = ei.SecondaryInsId  THEN 2
            WHEN ei.BilledToId = ei.TertiaryInsId   THEN 3
            ELSE 1
        END AS varchar)                                                    AS PayerInsSeqNo,
    CAST(ISNULL(eii.KenPAC, 0) AS varchar)                                AS KenPAC,
    -- ClaimStatus: overall claim FileStatus from edi_invoice
    ISNULL(ei.FileStatus, '')                                              AS ClaimStatus,
    -- statusDesc: human-readable label derived from FileStatus
    CASE ISNULL(ei.FileStatus, '')
        WHEN 'PEN' THEN 'Pending'
        WHEN 'BLD' THEN 'Billed'
        WHEN 'HLD' THEN 'Hold'
        WHEN 'ERA' THEN 'ERA Received'
        WHEN 'DEN' THEN 'Denied'
        WHEN 'PAD' THEN 'Paid'
        WHEN 'NCA' THEN 'No Charge'
        WHEN 'RVW' THEN 'Review'
        WHEN 'CLM' THEN 'Claim Submitted'
        WHEN 'PRE' THEN 'Pre-Billed'
        WHEN 'ADJ' THEN 'Adjusted'
        WHEN 'WAR' THEN 'Write Off AR'
        ELSE ISNULL(ei.FileStatus, '')
    END                                                                    AS statusDesc,
    -- ClaimPayerMedicaidNC: MedicaidId may be empty string (not NULL); treat empty as '0'
    ISNULL(NULLIF(eii.MedicaidId, ''), '0')                                AS ClaimPayerMedicaidNC,

    -- ============================================================
    -- POS, assignment, queue
    -- ============================================================
    CAST(ei.InvPOS AS varchar)                                             AS pos,
    CAST(ISNULL(ei.assignedToId, 0) AS varchar)                            AS AssignedToId,
    ISNULL(ei.assignedTo, '')                                              AS assignedTo,
    ISNULL(RTRIM(ei.AssignmentType), '')                                   AS assignmentType,
    CAST(ei.queueId AS varchar)                                            AS queueId,
    ISNULL(ei.queueName, '')                                               AS queueName,

    -- ============================================================
    -- Billing / payer IDs
    -- ============================================================
    CAST(ei.BilledToId AS varchar)                                         AS BilledToId,
    CAST(ei.BilledToIdType AS varchar)                                     AS BilledToIdType,
    NULL                                                                   AS DueFrom,   -- derived from payer type; complex API logic

    -- ============================================================
    -- Flags and counters
    -- ============================================================
    CAST(ei.DeleteFlag AS varchar)                                         AS DeleteFlag,
    CAST(ei.Type AS varchar)                                               AS Type,
    ISNULL(ei.ClaimLock, '')                                               AS ClaimLock,
    CAST(ei.VoidFlag AS varchar)                                           AS VoidFlag,
    CAST(ei.AnesthesiaFlag AS varchar)                                     AS AnesthesiaFlag,
    CAST(ei.FinanceChrgFlag AS varchar)                                    AS FinChrgFlag,
    CAST(ei.IncidentTo AS varchar)                                         AS IncidentTo,
    CAST(ei.GivenToCollection AS varchar)                                  AS GivenToCollection,
    ISNULL(ei.CollectionCode, '')                                          AS CollectionCode,
    ISNULL(ei.collectionstatus, '')                                        AS CollStatus,
    ''                                                                     AS CollAgencyStatus,  -- no source column
    CAST(ei.SplitClaimId AS varchar)                                       AS SplitClaimId,
    CAST(ei.LineItemPayersEnabled AS varchar)                              AS LineItemPayersEnabled,
    CAST(ei.LineItemTransitionStage AS varchar)                            AS LineItemTransitionStage,
    CAST(ISNULL(ei.payrejectionstatus, 0) AS varchar)                      AS PayRejectStat,
    CAST(ei.IsGrPt AS varchar)                                             AS IsGrPt,
    CAST(ei.episode_id AS varchar)                                         AS episode_id,
    CAST(ei.ExcludeFromStmt AS varchar)                                    AS ExcludeFromStmt,
    CAST(ei.isopticalclaim AS varchar)                                     AS isopticalclaim,
    CAST(ei.miscRevenueFlag AS varchar)                                    AS miscRevenueFlag,
    ''                                                                     AS miscRevenueType,   -- no column found
    CAST(ei.closingId AS varchar)                                          AS ClosingId,
    CAST(ei.PracticeId AS varchar)                                         AS PracticeId,
    CAST(ei.InvRespPartyId AS varchar)                                     AS InvRespPartyId,
    CAST(ei.InvRespPartyRel AS varchar)                                    AS InvRespPartyRel,

    -- ============================================================
    -- Department
    -- ============================================================
    CAST(ISNULL(ei.invoicedeptid, 0) AS varchar)                           AS DeptId,
    ISNULL(dpt.name, '')                                                   AS DeptName,

    -- ============================================================
    -- Split encounter (not stored in edi_invoice; default 0 / -1)
    -- ============================================================
    '0'                                                                    AS SplitEncId,
    '0'                                                                    AS SplitEncType,
    '-1'                                                                   AS ParentencType,

    -- ============================================================
    -- API-layer / computed fields
    -- ============================================================
    'yes'                                                                  AS ClaimExists,
    -- CapitationPlan: not in edi_invoice or edi_inv_insurance in filtered CSV
    '0'                                                                    AS CapitationPlan,
    'NO'                                                                   AS IsBHISClaim,
    'NO'                                                                   AS IsERClaim,
    0                                                                      AS isEmployer,
    ISNULL(ei.stmtholdtype, '')                                            AS HoldReason,
    ''                                                                     AS PrescriptionNumber  -- not in claim tables

FROM mobiledoc.dbo.edi_invoice ei

    JOIN  mobiledoc.dbo.enc e
        ON  e.encounterID          = ei.EncounterId
        AND ISNULL(e.deleteFlag, 0) = 0

    LEFT JOIN mobiledoc.dbo.edi_facilities ef
        ON  ef.Id                  = ei.InvFacilityId
        AND ISNULL(ef.DeleteFlag, 0) = 0

    LEFT JOIN mobiledoc.dbo.edi_facilities ef_stmt
        ON  ef_stmt.Id             = ei.StmtBillingFacilityId
        AND ISNULL(ef_stmt.DeleteFlag, 0) = 0

    LEFT JOIN mobiledoc.dbo.users u_res
        ON  u_res.uid              = ei.InvResourceId

    LEFT JOIN mobiledoc.dbo.users u_pay
        ON  u_pay.uid              = ei.PayToProviderId

    LEFT JOIN mobiledoc.dbo.users u_ren
        ON  u_ren.uid              = ei.RenProviderId

    LEFT JOIN mobiledoc.dbo.users u_sup
        ON  u_sup.uid              = ei.SupervisorId

    LEFT JOIN mobiledoc.dbo.users u_add1
        ON  u_add1.uid             = ei.AddlProvider1

    LEFT JOIN mobiledoc.dbo.users u_add2
        ON  u_add2.uid             = ei.AddlProvider2

    -- Current payer row: match InsId to BilledToId for active billing insurance
    LEFT JOIN mobiledoc.dbo.edi_inv_insurance eii
        ON  eii.InvoiceId          = ei.Id
        AND eii.InsId              = ei.BilledToId
        AND ISNULL(eii.deleteFlag, 0) = 0

    LEFT JOIN mobiledoc.dbo.departments dpt
        ON  dpt.DeptId             = ei.invoicedeptid

WHERE ei.Id                        = @invId
  AND ISNULL(ei.DeleteFlag, 0)     = 0;
