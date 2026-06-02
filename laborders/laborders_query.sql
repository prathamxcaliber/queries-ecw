-- ============================================================
-- Lab Orders Query
-- Returns fields matching the EHR Lab Orders API payload shape.
-- Same as Lab Reports but WITHOUT result data:
--   - result (labdata.result) excluded
--   - ResultDate (labdata.ResultDate) excluded
--   - LabDataDetailJSONArray excluded
-- Single SELECT -- one row per lab order.
-- ============================================================
-- Tables joined:
--   labdata                : core lab order (ReportId PK, EncounterId, ItemId)
--   items (parent)         : lab panel name        via labdata.ItemId
--   enc                    : encounter date, encType, patientID, encLock
--   patients               : ControlNo, state, textenabled, vfc
--   users (patient)        : name, dob, sex, phone, suffix, webenabled, EligibilityStatus
--   users (assignedTo)     : assignedToName, assigneeActiveStatus via labdata.assignedToId
--   edi_facilities         : external lab facilityName + facilityCode via labdata.tolabid
--   assessment_lab_history : linked diagnoses (AsmtId, icdCode)
--   labdataex              : extended lab data (InterfaceStatus, bodySiteCode, AQRejectionReason, exceptionReasonId/Comment)
--   config                 : system key-value settings (ItemKeysJSONArray)
-- ============================================================
-- Column mappings:
--   labdate                → labdata.transDate (order creation date)
--   InternalNotes          → labdata.IntNotes
--   notes                  → labdata.Notes
--   facilityId/facilityName→ labdata.tolabid → edi_facilities
--   facilityCode           → edi_facilities.code
--   name (panel)           → items.itemName via labdata.ItemId
--   assignedToName         → users via labdata.assignedToId
--   assigneeActiveStatus   → users.status (0/NULL=active→'true', else 'false')
--   suffix                 → users.suffix
--   WebEnabled             → users.webenabled (1→'true', else 'false')
--   Eligibility            → users.EligibilityStatus
--   Vfc                    → patients.vfc
--   AssessmentsJSONArray   → assessment_lab_history.icdCode + items.itemName
--   LabAttributeNamesJSONArray → items where parentID = labdata.ItemId
--   ItemKeysJSONArray      → config table (name, value)
-- ============================================================
-- Fields returned as NULL (not storable -- dynamic or not in any schema table):
--   LabDataJSON            : formLoadTime (server-generated timestamp),
--                            orderFormBanner (computed by EHR from clinicalInfo presence),
--                            snomedCodeSpecimen (SNOMED lookup not in DB)
-- Fields hardcoded (no DB column -- defaults matching EHR):
--   LabDataJSON            : isDisableCollDateForIHStructResultedLab='false', bEnableIHLabResultDocumentation='no',
--                            sexParam='0', CCStatus='0', reportDate='', assignedToType='1',
--                            ignoreProcedureValidations='0', DocumentStructuredResults='0',
--                            DisableChkPublish='0', isPAMAActionRequired='false', bodySiteName=''
--   LabAttributeNamesJSONArray: defaultImmunization='', favouriteid='N', DoseUnits='', PPDStatus=0, dose='', VISCount=1
-- ============================================================

DECLARE @encounterId INT = 3256798;   -- Replace with target encounterId
DECLARE @itemId      INT = 465612;    -- Parent lab panel itemId

SELECT

    -- ══════════════════════════════════════════════════════
    -- LabDataJSON scalar fields
    -- ══════════════════════════════════════════════════════

    -- labdate: use enc.date when transDate is sentinel (1901-01-01 or pre-2000)
    CASE WHEN ld.transDate IS NULL OR YEAR(ld.transDate) < 2000
         THEN CONVERT(varchar(10), CAST(e.date AS date), 23)
         ELSE CONVERT(varchar(10), CAST(ld.transDate AS date), 23)
    END                                                                    AS labdate,
    CAST(ISNULL(ld.ordPhyId, 0) AS varchar)                                AS ProviderId,
    ISNULL(CAST(ld.reason AS varchar(MAX)), '')                             AS reason,
    ISNULL(NULLIF(u.umobileno, ''), ISNULL(NULLIF(u.upPhone, ''), ''))     AS PatientTel,
    ISNULL(CAST(ld.Notes AS varchar(MAX)), '')                              AS notes,
    ISNULL(ld.collUnits, '')                                                AS collUnits,
    NULL                                                                   AS isDisableCollDateForIHStructResultedLab,
    NULL                                                                   AS bEnableIHLabResultDocumentation,
    ISNULL(ld.collSource, '')                                               AS collSource,
    NULL                                                                   AS sexParam,
    NULL                                                                   AS CCStatus,
    ISNULL(ldex.interfacestatus, '')                                        AS InterfaceStatus,
    -- formLoadTime: server-generated timestamp at request time, not stored in DB
    NULL                                                                   AS formLoadTime,
    -- collTime: '00:00:00' format
    CASE WHEN ld.collTime IS NULL
         THEN '00:00:00'
         ELSE CONVERT(varchar(8), CAST(ld.collTime AS time), 108)
    END                                                                    AS collTime,
    NULL                                                                   AS reportDate,
    NULL                                                                   AS assignedToType,
    CAST(e.patientID AS varchar)                                            AS PatientId,
    CAST(ISNULL(e.encType, 0) AS varchar)                                   AS enctype,
    ISNULL(ef.code, '')                                                     AS facilityCode,
    CASE WHEN ld.FutureOrderDate IS NULL
         THEN '' ELSE CONVERT(varchar(10), ld.FutureOrderDate, 23)
    END                                                                    AS futureOrderDate,
    CAST(ISNULL(ld.received, 0) AS varchar)                                AS received,
    CONCAT(u.ulname, ', ', u.ufname)                                       AS PatientName,
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
    ISNULL(ldex.exceptionReasonComment, '')                                AS exceptionReasonComment,
    CAST(ISNULL(ld.deleteFlag, 0) AS varchar)                              AS lddelflag,
    CAST(ISNULL(ld.fromLabId, 0) AS varchar)                               AS fromLabId,
    CAST(ISNULL(ld.prevencounterid, 0) AS varchar)                         AS prevEncId,
    NULL                                                                   AS orderFormBanner,
    ISNULL(asgn.ulname + ', ' + asgn.ufname, '')                           AS assignedToName,
    NULL                                                                   AS DisableChkPublish,
    CAST(ISNULL(ld.fasting, 0) AS varchar)                                 AS fasting,
    CAST(ld.EncounterId AS varchar)                                        AS encounterId,
    ISNULL(CAST(ldex.exceptionReasonId AS varchar), '')                    AS exceptionReasonId,
    CAST(ISNULL(ld.assignedToId, 0) AS varchar)                            AS assignedTo,
    ISNULL(ldex.bodysitecode, '')                                          AS bodySiteCode,
    ISNULL(CAST(ld.clinicalInfo AS nvarchar(MAX)), '')                      AS clinicalInfo,
    ISNULL(ef.Name, '')                                                    AS facilityName,
    CAST(ISNULL(it_parent.showPathologyDetail, 0) AS varchar)              AS showPathologyDetail,
    CAST(ISNULL(ld.approvalstatus, 0) AS varchar)                          AS approvalStatus,
    CAST(ISNULL(ld.tolabid, 0) AS varchar)                                 AS facilityId,
    CAST(ISNULL(ld.ActualFasting, 0) AS varchar)                           AS ActualFasting,
    ISNULL(ld.collVolume, '')                                              AS collVolume,
    FORMAT(CONVERT(date, u.dob, 101), 'MM/dd/yyyy')                        AS PatientDob,
    ISNULL(CAST(ld.IntNotes AS varchar(MAX)), '')                           AS InternalNotes,
    CAST(ISNULL(ld.Billable, 0) AS varchar)                                AS billable,
    NULL                                                                   AS isPAMAActionRequired,
    ISNULL(ld.ordPhyName, '')                                              AS ProviderName,
    CASE WHEN ISNULL(asgn.status, 0) = 0 THEN 'true' ELSE 'false' END     AS assigneeActiveStatus,
    CAST(ISNULL(ld.publishToPortal, 0) AS varchar)                         AS publish,
    CAST(ISNULL(ld.ordencounterid, 0) AS varchar)                          AS ordEncId,
    NULL                                                                   AS snomedCodeSpecimen,
    ISNULL(bs.bodysitename, '')                                            AS bodySiteName,
    CASE WHEN ld.collDate IS NULL OR YEAR(ld.collDate) < 2000
         THEN '0000-00-00'
         ELSE CONVERT(varchar(10), ld.collDate, 23)
    END                                                                    AS collDate,

    -- ══════════════════════════════════════════════════════
    -- PatientDataJSON scalar fields
    -- ══════════════════════════════════════════════════════

    ISNULL(ld.reason, '')                                                  AS patdata_reason,
    ISNULL(u.ulname, '')                                                   AS lastName,
    CAST(ISNULL(p.textenabled, 0) AS varchar)                              AS LabEnabled,
    RTRIM(ISNULL(u.EligibilityStatus, ''))                                 AS Eligibility,
    CONCAT(u.ulname, ', ', u.ufname)                                       AS PatientNamewithsuffix,
    -- Sex in PatientDataJSON: EHR returns single uppercase letter ('F'/'M')
    UPPER(LEFT(ISNULL(u.sex, ''), 1))                                      AS Sex,
    CONCAT(u.ulname, ', ', u.ufname, ' ', ISNULL(u.suffix, ''))            AS patdata_PatientName,
    ISNULL(u.suffix, '')                                                   AS suffix,
    CONCAT(u.ulname, ', ', u.ufname, ' ', ISNULL(u.suffix, ''))            AS patdata_Name,
    ISNULL(u.ufname, '')                                                   AS firstName,
    ISNULL(p.vfc, '')                                                      AS Vfc,
    ISNULL(u.uminitial, '')                                                AS middleInitial,
    FORMAT(CONVERT(date, u.dob, 101), 'MM/dd/yyyy')                        AS Dob,
    ISNULL(NULLIF(u.umobileno, ''), ISNULL(NULLIF(u.upPhone, ''), ''))     AS Phone,
    CAST(e.patientID AS varchar)                                           AS [Id],
    p.ControlNo,
    ISNULL(p.state, '')                                                    AS [state],
    CASE WHEN ISNULL(u.webenabled, 0) = 1 THEN 'true' ELSE 'false' END    AS WebEnabled,
    CAST(
        DATEDIFF(year, CAST(u.dob AS date), CAST(GETDATE() AS date))
        - CASE WHEN FORMAT(GETDATE(), 'MMdd') < FORMAT(CAST(u.dob AS date), 'MMdd')
               THEN 1 ELSE 0
          END
    AS varchar) + ' Y'                                                    AS Age,
    NULL                                                                   AS patdata_status,

    -- ══════════════════════════════════════════════════════
    -- AssessmentsJSONArray  (FOR JSON PATH correlated subquery)
    -- Diagnoses linked to this lab order via assessment_lab_history.
    -- ══════════════════════════════════════════════════════
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

    -- ══════════════════════════════════════════════════════
    -- LabAttributeNamesJSONArray  (FOR JSON PATH correlated subquery)
    -- Child test items that belong to this lab panel.
    -- ══════════════════════════════════════════════════════
    (
        SELECT
            it.itemID                                                      AS id,
            ISNULL(it.itemName, '')                                        AS [name],
            CASE WHEN LEFT(ISNULL(it.xmlPath, ''), 1) = '/'
                 THEN STUFF(it.xmlPath, 1, 1, '')
                 ELSE ISNULL(it.xmlPath, '')
            END                                                            AS xmlPath,
            ISNULL(it.itemType, '')                                        AS [type],
            ISNULL(it.gender, '')                                          AS gender,
            ISNULL(it.supplierId, 0)                                       AS supplierID,
            it.parentID                                                    AS parentId,
            CAST(it.parentID AS varchar) + '_' + CAST(it.itemID AS varchar) AS parentIdItemId,
            CASE WHEN ISNULL(it.vmsgexclude, 0) = 0 THEN 1 ELSE 0 END     AS Export,
            NULL                                                           AS defaultImmunization,
            NULL                                                           AS favouriteid,
            NULL                                                           AS DoseUnits,
            CAST(ISNULL(ip.PPDCheckSt, 0) AS int)                          AS PPDStatus,
            ISNULL(ip.dose, '')                                            AS dose,
            CAST(ISNULL(ip.VISCount, 0) AS int)                            AS VISCount
        FROM mobiledoc.dbo.items it
        LEFT JOIN mobiledoc.dbo.itemparam ip
            ON ip.itemId = it.itemID
        WHERE it.parentID              = ld.ItemId
          AND ISNULL(it.deleteFlag, 0) = 0
        ORDER BY it.displayIndex, it.itemID
        FOR JSON PATH
    )                                                                      AS LabAttributeNamesJSONArray,

    -- ══════════════════════════════════════════════════════
    -- ItemKeysJSONArray  (FOR JSON PATH subquery, not correlated)
    -- System key-value config settings.
    -- ══════════════════════════════════════════════════════
    (
        SELECT
            ISNULL(c.value, '')                                            AS [Value],
            NULL                                                           AS [Id],
            c.name                                                         AS [Name]
        FROM mobiledoc.dbo.config c
        WHERE c.name IN (
            'EnableWebPortal',
            'LockTimeStamp',
            'EnableCorrectionalFeatures',
            'SortLabByOrderDate',
            'ReportDateOnResultReport',
            'CustomDisabledPACSButton',
            'EnableStudyPACSButton',
            'DefaultDoNotPublishDImaging',
            'lab_proc_doc',
            'QuestBiDir',
            'ShowReviewandPublishtoProgressNoteForLab',
            'DefaultDoNotPublishProcedures',
            'Administrator',
            'MigrateReasonToInterfaceStatus',
            'DefaultDoNotPublishLabs',
            'AllowOnlySelectionSrcDesc',
            'PessimisticSecurity',
            'EnableVoiceInterface',
            'NewDocumentFolders'
        )
        FOR JSON PATH
    )                                                                      AS ItemKeysJSONArray

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

    LEFT JOIN mobiledoc.dbo.edi_facilities ef
        ON  ef.Id = ld.tolabid
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
