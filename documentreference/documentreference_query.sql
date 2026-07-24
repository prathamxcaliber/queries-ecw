-- ============================================================
-- Document Reference Query
-- Returns fields matching the EHR Document Reference API payload shape.
-- Same document table as Documents resource; different endpoint wrapper
-- and minor type/format differences.
-- ============================================================
-- EHR shape: [ { "document": { PatientId, PatientName, dob, doc_Type,
--                  CatId, encId, refId, fileName, customName, ScannedDate,
--                  ScannedBy, Description, Review, ReviewerId, ReviewerName,
--                  refType, FacilityId, FacilityName, Priority, AttachTo,
--                  DirPath, FtpServer, PublishToEHX, pnCatId, pnItemId,
--                  injuryId, expirydate, servicedate, scanById,
--                  ReviewStatusChange, PublishToEmployerPortal,
--                  PublishToEmployerId, hasDocumentFolderAccess,
--                  documentFolder, PublishToPortal, publishonhealowdrive,
--                  Tags, VBTagsElement, attachToFolderCatId, PtEmployers,
--                  isMigrated } } ]
-- ============================================================
-- Tables joined:
--   document         : core record (docID PK, PatientId, encId, refId,
--                      fileName, customName, doc_Type, scanDate, ScannedBy,
--                      Description, Review, ReviewerId, ReviewerName, Priority,
--                      attachto, FacilityId, publishToEHX, dirpath, ftpserver,
--                      pnCatId, pnItemId, injuryId, expirydate, servicedate,
--                      scanbyid, publishToEmployerPortal, publishToEmployerId,
--                      publishonhealowdrive, migrateflag, refType, portalboxUpload,
--                      folderName, delFlag)
--   users (patient)  : PatientName, dob via document.PatientId
--   documentfolders  : CatId, documentFolder, FacilityName via doc_Type
-- ============================================================
-- Key differences vs Documents endpoint:
--   PatientId/doc_Type/encId/refId : returned as INT (not varchar)
--   ScannedBy/scanById             : varchar in DB, returned as INT
--   ScannedDate                    : date only (yyyy-MM-dd), no time component
--   PatientName                    : "Lastname, Firstname" with space after comma
--   ReviewStatusChange             : hardcoded 1 (true); computed at API layer
--   hasDocumentFolderAccess        : hardcoded 1; permission check at API layer
--   PtEmployers                    : '[]' string (empty JSON array)
-- ============================================================
-- Fields hardcoded (no DB column):
--   ReviewStatusChange, hasDocumentFolderAccess, Tags, VBTagsElement,
--   attachToFolderCatId, PtEmployers
-- ============================================================

DECLARE @patientId INT = 279587;

SELECT

    -- Patient identity
    d.PatientId                                                            AS PatientId,
    ISNULL(u.ulname, '') + ', ' + ISNULL(u.ufname, '')                     AS PatientName,
    ISNULL(FORMAT(CONVERT(date, u.dob, 101), 'MM/dd/yyyy'), '')            AS dob,

    -- Document classification
    d.doc_Type                                                             AS doc_Type,
    ISNULL(df.CatID, '')                                                   AS CatId,

    -- Core document fields
    ISNULL(d.encId, 0)                                                     AS encId,
    ISNULL(d.refId, 0)                                                     AS refId,
    ISNULL(d.fileName, '')                                                 AS fileName,
    ISNULL(d.customName, '')                                               AS customName,
    -- ScannedDate: date only (no time component in this endpoint)
    ISNULL(CONVERT(varchar(10), d.scanDate, 23), '')                       AS ScannedDate,
    CAST(ISNULL(d.ScannedBy, '0') AS int)                                  AS ScannedBy,
    ISNULL(d.Description, '')                                              AS Description,
    ISNULL(d.Review, 0)                                                    AS Review,
    ISNULL(d.ReviewerId, 0)                                                AS ReviewerId,
    ISNULL(RTRIM(d.ReviewerName), '')                                      AS ReviewerName,

    -- refType: int 0 = no type (return ''); any other value return as string
    CASE WHEN ISNULL(d.refType, 0) = 0 THEN '' ELSE CAST(d.refType AS varchar) END
                                                                           AS refType,

    -- Facility
    ISNULL(d.FacilityId, 0)                                                AS FacilityId,
    ISNULL(df.FacilityName, '')                                            AS FacilityName,

    -- Routing / storage
    ISNULL(d.Priority, 0)                                                  AS Priority,
    ISNULL(d.attachto, '')                                                 AS AttachTo,
    ISNULL(d.dirpath, '')                                                  AS DirPath,
    ISNULL(d.ftpserver, '')                                                AS FtpServer,

    -- Publish flags
    ISNULL(d.publishToEHX, 0)                                              AS PublishToEHX,
    ISNULL(d.pnCatId, 0)                                                   AS pnCatId,
    ISNULL(d.pnItemId, 0)                                                  AS pnItemId,
    ISNULL(d.injuryId, '')                                                 AS injuryId,
    ISNULL(FORMAT(d.expirydate, 'yyyy-MM-dd HH:mm:ss'), '')                AS expirydate,
    ISNULL(FORMAT(d.servicedate, 'yyyy-MM-dd HH:mm:ss'), '')               AS servicedate,
    ISNULL(d.scanbyid, 0)                                                  AS scanById,

    -- ReviewStatusChange: always 1 (true) — computed at API layer
    1                                                                      AS ReviewStatusChange,
    ISNULL(d.publishToEmployerPortal, 0)                                   AS PublishToEmployerPortal,
    ISNULL(d.publishToEmployerId, 0)                                       AS PublishToEmployerId,

    -- hasDocumentFolderAccess: permission check at API layer; hardcoded 1
    1                                                                      AS hasDocumentFolderAccess,

    -- Folder / portal
    ISNULL(df.Name, '')                                                    AS documentFolder,
    ISNULL(d.portalboxUpload, 0)                                           AS PublishToPortal,
    ISNULL(d.publishonhealowdrive, 0)                                      AS publishonhealowdrive,

    -- Tags / extras
    ''                                                                     AS Tags,
    ''                                                                     AS VBTagsElement,
    ''                                                                     AS attachToFolderCatId,
    '[]'                                                                   AS PtEmployers,
    ISNULL(d.migrateflag, 0)                                               AS isMigrated

FROM mobiledoc.dbo.document d

    LEFT JOIN mobiledoc.dbo.users u
        ON  u.uid = d.PatientId

    LEFT JOIN mobiledoc.dbo.documentfolders df
        ON  df.ID                 = d.doc_Type
        AND ISNULL(df.DelFlag, 0) = 0

WHERE d.PatientId          = @patientId
  AND ISNULL(d.delFlag, 0) = 0
ORDER BY d.scanDate DESC;
