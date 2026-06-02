-- ============================================================
-- Documents Query
-- Returns fields matching the EHR Documents API payload shape.
-- One row per document per patient.
-- ============================================================
-- Tables joined:
--   document               : core document record (docID PK, PatientId, encId, refId,
--                            fileName, customName, doc_Type, scanDate, ScannedBy, Description,
--                            Review, ReviewerId, ReviewerName, Priority, attachto, FacilityId,
--                            publishToEHX, dirpath, ftpserver, pnCatId, pnItemId, injuryId,
--                            expirydate, servicedate, scanbyid, publishToEmployerPortal,
--                            publishToEmployerId, publishonhealowdrive, migrateflag,
--                            refType, portalboxUpload, folderName, delFlag)
--   users (patient)        : PatientName, dob via document.PatientId
--   documentfolders        : CatId, documentFolder, FacilityName via document.doc_Type
--                            (join on df.ID = d.doc_Type -- folderName is empty; doc_Type IS the folder ID)
-- ============================================================
-- Column mappings:
--   PatientId              -> document.PatientId
--   PatientName            -> ISNULL(users.ulname,'') + ',' + ISNULL(users.ufname,'') (null-safe concat)
--   dob                    -> users.dob as MM/dd/yyyy ('' if NULL)
--   doc_Type               -> document.doc_Type
--   CatId                  -> documentfolders.CatID (joined on df.ID = d.doc_Type)
--   encId                  -> document.encId (0 if NULL)
--   refId                  -> document.refId (0 if NULL)
--   fileName               -> document.fileName
--   customName             -> document.customName
--   ScannedDate            -> document.scanDate as 'yyyy-MM-dd HH:mm:ss'
--   ScannedBy              -> document.ScannedBy
--   Description            -> document.Description
--   Review                 -> document.Review (0 if NULL)
--   ReviewerId             -> document.ReviewerId (0 if NULL)
--   ReviewerName           -> RTRIM(document.ReviewerName) -- DB stores trailing space
--   refType                -> document.refType: 0 -> '' else cast to varchar
--   FacilityId             -> document.FacilityId (0 if NULL)
--   FacilityName           -> documentfolders.FacilityName
--   Priority               -> document.Priority (0 if NULL)
--   AttachTo               -> document.attachto
--   DirPath                -> document.dirpath
--   FtpServer              -> document.ftpserver
--   PublishToEHX           -> document.publishToEHX (0 if NULL)
--   pnCatId                -> document.pnCatId (0 if NULL)
--   pnItemId               -> document.pnItemId (0 if NULL)
--   injuryId               -> document.injuryId
--   expirydate             -> document.expirydate as 'yyyy-MM-dd HH:mm:ss' ('' if NULL)
--   servicedate            -> document.servicedate as 'yyyy-MM-dd HH:mm:ss' ('' if NULL)
--   scanById               -> document.scanbyid (0 if NULL)
--   ReviewStatusChange     -> NULL (computed at API layer -- no DB column)
--   PublishToEmployerPortal -> document.publishToEmployerPortal (0 if NULL)
--   PublishToEmployerId    -> document.publishToEmployerId (0 if NULL)
--   hasDocumentFolderAccess -> NULL (permission check at API layer -- no DB column)
--   documentFolder         -> documentfolders.Name (joined on df.ID = d.doc_Type)
--   PublishToPortal        -> document.portalboxUpload (0 if NULL)
--   publishonhealowdrive   -> document.publishonhealowdrive (0 if NULL)
--   Tags                   -> '' (no document-specific tags column found in schema)
--   VBTagsElement          -> '' (no column found in schema)
--   attachToFolderCatId    -> '' (unclear source; empty in sample)
--   PtEmployers            -> NULL (JSON array built at API layer; no direct DB column)
--   isMigrated             -> document.migrateflag (0 if NULL)
-- ============================================================

DECLARE @patientId INT = 327910;   -- Replace with target patientId

SELECT

    -- ══════════════════════════════════════════════════════
    -- Patient identity
    -- ══════════════════════════════════════════════════════
    CAST(d.PatientId AS varchar)                                           AS PatientId,
    ISNULL(u.ulname, '') + ',' + ISNULL(u.ufname, '')                      AS PatientName,
    ISNULL(FORMAT(CONVERT(date, u.dob, 101), 'MM/dd/yyyy'), '')            AS dob,

    -- ══════════════════════════════════════════════════════
    -- Document classification
    -- ══════════════════════════════════════════════════════
    CAST(d.doc_Type AS varchar)                                            AS doc_Type,
    ISNULL(df.CatID, '')                                                   AS CatId,

    -- ══════════════════════════════════════════════════════
    -- Core document fields
    -- ══════════════════════════════════════════════════════
    CAST(ISNULL(d.encId, 0) AS varchar)                                    AS encId,
    CAST(ISNULL(d.refId, 0) AS varchar)                                    AS refId,
    ISNULL(d.fileName, '')                                                 AS fileName,
    ISNULL(d.customName, '')                                               AS customName,
    ISNULL(FORMAT(d.scanDate, 'yyyy-MM-dd HH:mm:ss'), '')                  AS ScannedDate,
    ISNULL(d.ScannedBy, '')                                                AS ScannedBy,
    ISNULL(d.Description, '')                                              AS Description,
    CAST(ISNULL(d.Review, 0) AS int)                                       AS Review,
    CAST(ISNULL(d.ReviewerId, 0) AS int)                                   AS ReviewerId,
    ISNULL(RTRIM(d.ReviewerName), '')                                      AS ReviewerName,

    -- refType: int 0 = no type (return ''); any other value return as string
    CASE WHEN ISNULL(d.refType, 0) = 0 THEN '' ELSE CAST(d.refType AS varchar) END
                                                                           AS refType,

    -- ══════════════════════════════════════════════════════
    -- Facility
    -- ══════════════════════════════════════════════════════
    CAST(ISNULL(d.FacilityId, 0) AS int)                                   AS FacilityId,
    ISNULL(df.FacilityName, '')                                            AS FacilityName,

    -- ══════════════════════════════════════════════════════
    -- Routing / storage
    -- ══════════════════════════════════════════════════════
    CAST(ISNULL(d.Priority, 0) AS int)                                     AS Priority,
    ISNULL(d.attachto, '')                                                 AS AttachTo,
    ISNULL(d.dirpath, '')                                                  AS DirPath,
    ISNULL(d.ftpserver, '')                                                AS FtpServer,

    -- ══════════════════════════════════════════════════════
    -- Publish flags
    -- ══════════════════════════════════════════════════════
    CAST(ISNULL(d.publishToEHX, 0) AS int)                                 AS PublishToEHX,
    CAST(ISNULL(d.pnCatId, 0) AS int)                                      AS pnCatId,
    CAST(ISNULL(d.pnItemId, 0) AS int)                                     AS pnItemId,
    ISNULL(d.injuryId, '')                                                 AS injuryId,
    ISNULL(FORMAT(d.expirydate, 'yyyy-MM-dd HH:mm:ss'), '')                AS expirydate,
    ISNULL(FORMAT(d.servicedate, 'yyyy-MM-dd HH:mm:ss'), '')               AS servicedate,
    CAST(ISNULL(d.scanbyid, 0) AS int)                                     AS scanById,

    NULL                                                                   AS ReviewStatusChange,    -- computed at API layer
    CAST(ISNULL(d.publishToEmployerPortal, 0) AS int)                      AS PublishToEmployerPortal,
    CAST(ISNULL(d.publishToEmployerId, 0) AS int)                          AS PublishToEmployerId,
    NULL                                                                   AS hasDocumentFolderAccess, -- permission check at API layer

    -- ══════════════════════════════════════════════════════
    -- Folder / portal
    -- ══════════════════════════════════════════════════════
    ISNULL(df.Name, '')                                                    AS documentFolder,
    CAST(ISNULL(d.portalboxUpload, 0) AS int)                              AS PublishToPortal,
    CAST(ISNULL(d.publishonhealowdrive, 0) AS int)                         AS publishonhealowdrive,

    -- ══════════════════════════════════════════════════════
    -- Tags / extras (no DB columns found)
    -- ══════════════════════════════════════════════════════
    ''                                                                     AS Tags,              -- no document tags column in schema
    ''                                                                     AS VBTagsElement,     -- no column found
    ''                                                                     AS attachToFolderCatId, -- unclear source; empty in sample
    NULL                                                                   AS PtEmployers,       -- JSON array built at API layer
    CAST(ISNULL(d.migrateflag, 0) AS int)                                  AS isMigrated

FROM mobiledoc.dbo.document d

    LEFT JOIN mobiledoc.dbo.users u
        ON  u.uid = d.PatientId

    LEFT JOIN mobiledoc.dbo.documentfolders df
        ON  df.ID                 = d.doc_Type
        AND ISNULL(df.DelFlag, 0) = 0

WHERE d.PatientId          = @patientId
  AND ISNULL(d.delFlag, 0) = 0
ORDER BY d.scanDate DESC;
