-- ============================================================
-- Lab Reports Query
-- Returns fields matching the EHR Lab Reports API payload shape
-- Single SELECT â€” one row per lab order (same pattern as patients query).
-- Array sections (LabDataDetailJSONArray, AssessmentsJSONArray,
--   LabAttributeNamesJSONArray, ItemKeysJSONArray) are returned as
--   JSON strings via FOR JSON PATH correlated subqueries.
-- ============================================================
-- Tables joined:
--   labdata                : core lab order (ReportId PK, EncounterId, ItemId)
--   labdatadetail          : individual test result rows (FK: ReportId)
--   items (parent)         : lab panel name        via labdata.ItemId
--   items (child)          : individual test name  via items.parentID + labdatadetail
--   items (asmt)           : ICD description       via assessment_lab_history.AsmtId
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
--   labdate                â†’ labdata.transDate (order creation date)
--   InternalNotes          â†’ labdata.IntNotes
--   notes                  â†’ labdata.Notes
--   facilityId/facilityNameâ†’ labdata.tolabid â†’ edi_facilities
--   facilityCode           â†’ edi_facilities.code
--   name (panel)           â†’ items.itemName via labdata.ItemId
--   assignedToName         â†’ users via labdata.assignedToId
--   assigneeActiveStatus   â†’ users.status (0/NULL=activeâ†’'true', else 'false')
--   suffix                 â†’ users.suffix
--   WebEnabled             â†’ users.webenabled (1â†’'true', else 'false')
--   Eligibility            â†’ users.EligibilityStatus
--   Vfc                    â†’ patients.vfc
--   AssessmentsJSONArray   â†’ assessment_lab_history.icdCode + items.itemName
--   LabAttributeNamesJSONArray â†’ items where parentID = labdata.ItemId
--   LabDataDetailJSONArray â†’ labdatadetail joined to items (child)
--   ItemKeysJSONArray      â†’ config table (name, value)
-- ============================================================
-- Fields returned as NULL (not storable — dynamic or not in any schema table):
--   LabDataJSON            : formLoadTime (server-generated timestamp),
--                            orderFormBanner (computed by EHR from clinicalInfo presence),
--                            snomedCodeSpecimen (SNOMED lookup not in DB)
-- Fields returned as NULL (confirmed absent from mobiledoc schema):
--   Scalar: isDisableCollDateForIHStructResultedLab, bEnableIHLabResultDocumentation,
--           sexParam, CCStatus, reportDate, assignedToType, DisableChkPublish,
--           isPAMAActionRequired, patdata_status
--   LabDataDetailJSONArray: referenceRangeConfigured, withinViewPort, paramNotes, units
--   LabAttributeNamesJSONArray: defaultImmunization, favouriteid, DoseUnits
-- DB-mapped (previously unlisted):
--   bodySiteName           -> bodysites.bodysitename via labdataex.bodysitecode
--   ignoreProcedureValidations -> billablelab.ignoreprocedurevalidations
--   DocumentStructuredResults  -> billablelab.documentStructuredResults
--   patdata_reason         -> labdata.reason
--   range (LabDataDetail)  -> labdatadetailrefrange.range
--   dose/VISCount/PPDStatus -> itemparam.dose / VISCount / PPDCheckSt
-- ============================================================

DECLARE @encounterId INT = 3256798;   -- Replace with target encounterId
DECLARE @itemId      INT = 465612;    -- Parent lab panel itemId

SELECT

    -- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    -- LabDataJSON scalar fields
    -- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

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
    ISNULL(CONVERT(varchar(10), ld.ResultDate, 23), '')                    AS ResultDate,
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
    ISNULL(ld.result, '')                                                  AS result,
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

    -- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    -- PatientDataJSON scalar fields
    -- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

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

    -- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    -- LabDataDetailJSONArray  (FOR JSON PATH correlated subquery)
    -- One entry per child item (items.parentID = labdata.ItemId).
    -- LEFT JOINs labdatadetail for actual result values when resulted.
    -- id = labdata.ReportId (not labdatadetail.Id).
    -- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    (
        SELECT
            CONVERT(varchar(10), CAST(e.date AS date), 23)                 AS [date],
            CAST(ISNULL(ld.status, 0) AS int)                              AS [Status],
            CAST(ISNULL(ld.fromLabId, 0) AS int)                           AS fromLabId,
            CAST(ld.EncounterId AS int)                                    AS encounterId,
            CAST(ISNULL(ld.Type, 0) AS int)                                AS [type],
            NULL                                                           AS referenceRangeConfigured,
            ISNULL(ldd_i.Value, '')                                        AS Result,
            -- collTime: EHR returns '' in detail array when null or midnight (00:00:00)
            CASE WHEN ld.collTime IS NULL
                      OR CONVERT(varchar(8), CAST(ld.collTime AS time), 108) = '00:00:00'
                 THEN ''
                 ELSE CONVERT(varchar(8), CAST(ld.collTime AS time), 108)
            END                                                            AS collTime,
            NULL                                                           AS withinViewPort,
            ld.ReportId                                                    AS id,
            ISNULL(CAST(ld.Notes AS varchar(MAX)), '')                      AS Notes,
            it_c.itemID                                                    AS [properties.property.itemId],
            ISNULL(it_c.itemName, '')                                      AS [properties.property.itemName],
            ISNULL(ldd_i.flag, '')                                         AS [properties.property.flag],
            NULL                                                           AS [properties.property.paramNotes],
            ISNULL(ldrr.range, '')                                         AS [properties.property.range],
            NULL                                                           AS [properties.property.units],
            ISNULL(ldd_i.Value, '')                                        AS [properties.property.value],
            CASE WHEN ld.collDate IS NULL OR YEAR(ld.collDate) < 2000
                 THEN ''
                 ELSE CONVERT(varchar(10), ld.collDate, 23)
            END                                                            AS collDate
        FROM mobiledoc.dbo.items it_c
        LEFT JOIN mobiledoc.dbo.labdatadetail ldd_i
            ON  ldd_i.ReportId = ld.ReportId
            AND ldd_i.PropId   = it_c.itemID
        LEFT JOIN mobiledoc.dbo.labdatadetailrefrange ldrr
            ON  ldrr.reportid = ld.ReportId
            AND ldrr.itemid   = it_c.itemID
        WHERE it_c.parentID              = ld.ItemId
          AND ISNULL(it_c.deleteFlag, 0) = 0
        ORDER BY it_c.displayIndex, it_c.itemID
        FOR JSON PATH
    )                                                                      AS LabDataDetailJSONArray,

    -- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    -- AssessmentsJSONArray  (FOR JSON PATH correlated subquery)
    -- Diagnoses linked to this lab order via assessment_lab_history.
    -- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

    -- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    -- LabAttributeNamesJSONArray  (FOR JSON PATH correlated subquery)
    -- Child test items that belong to this lab panel.
    -- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

    -- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    -- ItemKeysJSONArray  (FOR JSON PATH subquery, not correlated)
    -- System key-value config settings.
    -- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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
