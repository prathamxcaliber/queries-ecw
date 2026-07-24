-- ============================================================
-- Digital Imaging Query
-- Returns fields matching the EHR Digital Imaging API payload shape.
-- Same labdata table as LabOrders/LabReports, different Type + facility source.
-- ============================================================
-- EHR shape: [ { LabAttributeNamesTotalCount,
--                AssessmentsJSONArray,
--                LabDataDetailJSONArray,
--                LabDataJSON: { labdate, ProviderId, reason, PatientTel,
--                   notes, collUnits, collSource, collTime, InterfaceStatus,
--                   PatientId, enctype, facilityCode, futureOrderDate,
--                   received, PatientName, priority, collDescription,
--                   itemId, AQRejectionReason, PatientSex, enclock, name,
--                   cancelled, ignoreProcedureValidations, orderinstructions,
--                   futureflag, DocumentStructuredResults, status, ResultDate,
--                   exceptionReasonComment, lddelflag, fromLabId, prevEncId,
--                   assignedToName, fasting, encounterId, exceptionReasonId,
--                   assignedTo, result, bodySiteCode, clinicalInfo,
--                   facilityName, showPathologyDetail, approvalStatus,
--                   facilityId, ActualFasting, collVolume, PatientDob,
--                   InternalNotes, billable, ProviderName, assigneeActiveStatus,
--                   publish, ordEncId, snomedCodeSpecimen, bodySiteName,
--                   collDate, ... } } ]
-- ============================================================
-- Tables joined:
--   labdata          : core record (ReportId, EncounterId, ItemId, Type)
--                      labdata.Type distinguishes imaging from lab orders
--   enc              : encounter context (patientID, facilityId, encType, encLock)
--   patients         : ControlNo, state, textenabled, vfc
--   users (patient)  : name, dob, sex, phone, webenabled, EligibilityStatus
--   users (asgn)     : assignedToName, assigneeActiveStatus via labdata.assignedToId
--   items            : procedure name via labdata.ItemId
--   edi_facilities   : facilityName + facilityCode via enc.facilityId
--                      (imaging uses enc facility, NOT labdata.tolabid)
--   labdataex        : extended data (InterfaceStatus, bodySiteCode, etc.)
--   bodysites        : bodySiteName via labdataex.bodysitecode
--   billablelab      : ignoreProcedureValidations, DocumentStructuredResults
--   assessment_lab_history : AssessmentsJSONArray (linked diagnoses)
--   labdatadetail    : LabDataDetailJSONArray (sparse for imaging)
-- ============================================================
-- Column mappings vs laborders:
--   facilityId   -> CAST(e.facilityId AS varchar)  [enc.facilityId, NOT ld.tolabid]
--   facilityName -> edi_facilities.Name via e.facilityId
--   facilityCode -> edi_facilities.code via e.facilityId
--   ResultDate   -> labdata.ResultDate              [included; excluded in laborders]
--   LabDataDetailJSONArray -> labdatadetail.Id + empty properties
--   LabAttributeNamesTotalCount -> child item count from items WHERE parentID=ItemId
-- ============================================================
-- Fields hardcoded (no DB column):
--   isDisableCollDateForIHStructResultedLab, bEnableIHLabResultDocumentation,
--   sexParam, CCStatus, reportDate, assignedToType, DisableChkPublish,
--   isPAMAActionRequired, orderFormBanner, formLoadTime, snomedCodeSpecimen
-- ============================================================

-- Lookup: find an encounterId/itemId with imaging records
--
--   SELECT TOP 10 ld.ReportId, ld.EncounterId, ld.ItemId, ld.Type,
--                 i.itemName, ld.status, ld.collDate
--   FROM mobiledoc.dbo.labdata ld WITH (NOLOCK)
--   LEFT JOIN mobiledoc.dbo.items i ON i.itemID = ld.ItemId
--   WHERE ld.Type = 1   -- verify imaging Type value here
--   ORDER BY ld.ReportId DESC;

DECLARE @encounterId INT = 3257308;
DECLARE @itemId      INT = 195024;

SELECT

    -- LabAttributeNamesTotalCount: count of child test items for this procedure
    (
        SELECT COUNT(*)
        FROM   mobiledoc.dbo.items it_cnt
        WHERE  it_cnt.parentID              = ld.ItemId
          AND  ISNULL(it_cnt.deleteFlag, 0) = 0
    )                                                                      AS LabAttributeNamesTotalCount,

    -- ============================================================
    -- LabDataJSON scalar fields
    -- ============================================================

    CASE WHEN ld.transDate IS NULL OR YEAR(ld.transDate) < 2000
         THEN CONVERT(varchar(10), CAST(e.date AS date), 23)
         ELSE CONVERT(varchar(10), CAST(ld.transDate AS date), 23)
    END                                                                    AS labdate,
    CAST(ISNULL(ld.ordPhyId, 0) AS varchar)                                AS ProviderId,
    ISNULL(CAST(ld.reason AS varchar(MAX)), '')                             AS reason,
    ISNULL(NULLIF(u.umobileno, ''), ISNULL(NULLIF(u.upPhone, ''), ''))     AS PatientTel,
    ISNULL(CAST(ld.Notes AS varchar(MAX)), '')                              AS notes,
    ISNULL(ld.collUnits, '')                                                AS collUnits,
    'false'                                                                AS isDisableCollDateForIHStructResultedLab,
    'no'                                                                   AS bEnableIHLabResultDocumentation,
    ISNULL(ld.collSource, '')                                               AS collSource,
    '0'                                                                    AS sexParam,
    '0'                                                                    AS CCStatus,
    NULL                                                                   AS formLoadTime,
    ISNULL(ldex.interfacestatus, '')                                        AS InterfaceStatus,
    CASE WHEN ld.collTime IS NULL
         THEN '00:00:00'
         ELSE CONVERT(varchar(8), CAST(ld.collTime AS time), 108)
    END                                                                    AS collTime,
    ''                                                                     AS reportDate,
    '1'                                                                    AS assignedToType,
    CAST(e.patientID AS varchar)                                            AS PatientId,
    CAST(ISNULL(e.encType, 0) AS varchar)                                   AS enctype,
    -- facilityCode from enc.facilityId -> edi_facilities (not ld.tolabid)
    ISNULL(ef.code, '')                                                     AS facilityCode,
    CASE WHEN ld.FutureOrderDate IS NULL
         THEN '' ELSE CONVERT(varchar(10), ld.FutureOrderDate, 23)
    END                                                                    AS futureOrderDate,
    CAST(ISNULL(ld.received, 0) AS varchar)                                AS received,
    CONCAT(u.ulname, ', ', u.ufname, CASE WHEN ISNULL(u.suffix,'')='' THEN '' ELSE ' '+u.suffix END) AS PatientName,
    CAST(ISNULL(ld.priority, 0) AS varchar)                                AS priority,
    ISNULL(ld.collDescription, '')                                         AS collDescription,
    CAST(ISNULL(ld.ItemId, 0) AS varchar)                                  AS itemId,
    ISNULL(ldex.AQRejectionReason, '')                                     AS AQRejectionReason,
    LOWER(ISNULL(u.sex, ''))                                               AS PatientSex,
    CAST(ISNULL(e.encLock, 0) AS varchar)                                  AS enclock,
    ISNULL(it_parent.itemName, '')                                         AS [name],
    CAST(ISNULL(ld.cancelled, 0) AS varchar)                               AS cancelled,
    CAST(ISNULL(bl.ignoreprocedurevalidations, 0) AS varchar)              AS ignoreProcedureValidations,
    ISNULL(CAST(ld.OrderInstructions AS varchar(MAX)), '')                  AS orderinstructions,
    CAST(ISNULL(ld.futureflag, 0) AS varchar)                              AS futureflag,
    CAST(ISNULL(bl.documentStructuredResults, 0) AS varchar)               AS DocumentStructuredResults,
    CAST(ISNULL(ld.status, 0) AS varchar)                                  AS [status],
    -- ResultDate: included for imaging (excluded in laborders)
    CASE WHEN ld.ResultDate IS NULL OR YEAR(ld.ResultDate) < 2000
         THEN '' ELSE CONVERT(varchar(10), ld.ResultDate, 23)
    END                                                                    AS ResultDate,
    ISNULL(ldex.exceptionReasonComment, '')                                AS exceptionReasonComment,
    CAST(ISNULL(ld.deleteFlag, 0) AS varchar)                              AS lddelflag,
    CAST(ISNULL(ld.fromLabId, 0) AS varchar)                               AS fromLabId,
    CAST(ISNULL(ld.prevencounterid, 0) AS varchar)                         AS prevEncId,
    NULL                                                                   AS orderFormBanner,
    ISNULL(asgn.ulname + ', ' + asgn.ufname, '')                           AS assignedToName,
    '0'                                                                    AS DisableChkPublish,
    CAST(ISNULL(ld.fasting, 0) AS varchar)                                 AS fasting,
    CAST(ld.EncounterId AS varchar)                                        AS encounterId,
    ISNULL(CAST(ldex.exceptionReasonId AS varchar), '')                    AS exceptionReasonId,
    CAST(ISNULL(ld.assignedToId, 0) AS varchar)                            AS assignedTo,
    ISNULL(CAST(ld.result AS varchar(MAX)), '')                             AS result,
    ISNULL(ldex.bodysitecode, '')                                          AS bodySiteCode,
    ISNULL(CAST(ld.clinicalInfo AS nvarchar(MAX)), '')                      AS clinicalInfo,
    -- facilityName from enc.facilityId -> edi_facilities (not ld.tolabid)
    ISNULL(ef.Name, '')                                                    AS facilityName,
    CAST(ISNULL(it_parent.showPathologyDetail, 0) AS varchar)              AS showPathologyDetail,
    CAST(ISNULL(ld.approvalstatus, 0) AS varchar)                          AS approvalStatus,
    -- facilityId from enc.facilityId (not ld.tolabid)
    CAST(ISNULL(e.facilityId, 0) AS varchar)                               AS facilityId,
    CAST(ISNULL(ld.ActualFasting, 0) AS varchar)                           AS ActualFasting,
    ISNULL(ld.collVolume, '')                                              AS collVolume,
    FORMAT(CONVERT(date, u.dob, 101), 'MM/dd/yyyy')                        AS PatientDob,
    ISNULL(CAST(ld.IntNotes AS varchar(MAX)), '')                           AS InternalNotes,
    CAST(ISNULL(ld.Billable, 0) AS varchar)                                AS billable,
    'false'                                                                AS isPAMAActionRequired,
    ISNULL(ld.ordPhyName, '')                                              AS ProviderName,
    CASE WHEN ISNULL(asgn.status, 0) = 0 THEN 'true' ELSE 'false' END     AS assigneeActiveStatus,
    CAST(ISNULL(ld.publishToPortal, 0) AS varchar)                         AS publish,
    CAST(ISNULL(ld.ordencounterid, 0) AS varchar)                          AS ordEncId,
    ''                                                                     AS snomedCodeSpecimen,
    ISNULL(bs.bodysitename, '')                                            AS bodySiteName,
    CASE WHEN ld.collDate IS NULL OR YEAR(ld.collDate) < 2000
         THEN '0000-00-00'
         ELSE CONVERT(varchar(10), ld.collDate, 23)
    END                                                                    AS collDate,

    -- ============================================================
    -- AssessmentsJSONArray
    -- ============================================================
    (
        SELECT
            CAST(alh.AsmtId AS varchar)                                    AS AsmtId,
            ISNULL(alh.icdCode, '')                                        AS Code,
            ISNULL(it_a.itemName, '')                                      AS [Name],
            NULL                                                           AS snowMedCode,
            ISNULL(alh.icdGroup, '')                                       AS Specify,
            CAST(ISNULL(alh.FavouriteHistoryItem, 1) AS varchar)           AS [Check]
        FROM mobiledoc.dbo.assessment_lab_history alh
        LEFT JOIN mobiledoc.dbo.items it_a
            ON  it_a.itemID              = alh.AsmtId
            AND ISNULL(it_a.deleteFlag, 0) = 0
        WHERE alh.LabId       = ld.ReportId
          AND alh.encounterId = ld.EncounterId
          AND ISNULL(alh.delFlag, 0) = 0
        FOR JSON PATH
    )                                                                      AS AssessmentsJSONArray,

    -- ============================================================
    -- LabDataDetailJSONArray: imaging returns [{id: ReportId, properties:[]}]
    -- No labdatadetail rows exist for imaging records; EHR echoes the ReportId.
    -- ============================================================
    JSON_QUERY('[{"id":' + CAST(ld.ReportId AS varchar) + ',"properties":[]}]') AS LabDataDetailJSONArray,

    -- ============================================================
    -- LabAttributeNamesJSONArray (child procedure items)
    -- ============================================================
    (
        SELECT
            it.itemID                                                      AS id,
            ISNULL(it.itemName, '')                                        AS [name],
            ISNULL(it.itemType, '')                                        AS [type]
        FROM mobiledoc.dbo.items it
        WHERE it.parentID              = ld.ItemId
          AND ISNULL(it.deleteFlag, 0) = 0
        ORDER BY it.displayIndex, it.itemID
        FOR JSON PATH
    )                                                                      AS LabAttributeNamesJSONArray

FROM mobiledoc.dbo.labdata ld

    JOIN  mobiledoc.dbo.enc e
        ON  e.encounterID = ld.EncounterId
        AND ISNULL(e.deleteFlag, 0) = 0

    LEFT JOIN mobiledoc.dbo.patients p
        ON  p.pid = e.patientID

    LEFT JOIN mobiledoc.dbo.users u
        ON  u.uid = e.patientID

    LEFT JOIN mobiledoc.dbo.users asgn
        ON  asgn.uid = ld.assignedToId

    LEFT JOIN mobiledoc.dbo.items it_parent
        ON  it_parent.itemID              = ld.ItemId
        AND ISNULL(it_parent.deleteFlag, 0) = 0

    -- Imaging uses enc.facilityId (not ld.tolabid) for facility name/code
    LEFT JOIN mobiledoc.dbo.edi_facilities ef
        ON  ef.Id = e.facilityId
        AND ISNULL(ef.DeleteFlag, 0) = 0

    LEFT JOIN mobiledoc.dbo.labdataex ldex
        ON  ldex.reportId = ld.ReportId

    LEFT JOIN mobiledoc.dbo.bodysites bs
        ON  bs.bodysitecode = ldex.bodysitecode
        AND ISNULL(bs.deleteflag, 0) = 0

    LEFT JOIN mobiledoc.dbo.billablelab bl
        ON  bl.code = ld.ItemId

WHERE ld.EncounterId = @encounterId
  AND ld.ItemId      = @itemId
  AND ISNULL(ld.deleteFlag, 0) = 0;
