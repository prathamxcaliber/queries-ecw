-- ============================================================
-- Clinical Notes Query
-- Returns fields matching the EHR Clinical Notes API payload shape.
-- One row per note per patient.
-- ============================================================
-- EHR shape: [ { notes: [ { id, loginUserId, loginUserName, date, time,
--                            message, subject, deleteFlag, arrStatus,
--                            tags, screenName, createdById, createdByName,
--                            updatedOn, createdOn, isDeviceAvailable,
--                            isRPMNotes } ], total } ]
-- ============================================================
-- Tables joined:
--   additionalnotes      : core record (Id, patientId, LoggedInUid, date,
--                          time, Message, deleteFlag, moduleName,
--                          subjectData, createdOn, createdBy)
--   users (u1)           : loginUserName via LoggedInUid -> users.uid
--   users (u2)           : createdByName via createdBy -> users.uid
--   additionalnotes_logs : updatedOn via most recent modifiedOn per notesId
-- ============================================================
-- Column mappings:
--   id              -> additionalnotes.Id
--   loginUserId     -> additionalnotes.LoggedInUid
--   loginUserName   -> CONCAT(u1.ulname, ', ', u1.ufname)
--   date            -> CONVERT(varchar, additionalnotes.date, 23)   (YYYY-MM-DD)
--   time            -> CONVERT(varchar, additionalnotes.time, 108)  (HH:MM:SS)
--   message         -> additionalnotes.Message
--   subject         -> additionalnotes.subjectData
--   deleteFlag      -> additionalnotes.deleteFlag
--   arrStatus       -> NULL (data_gap: confirmed absent from additionalnotes;
--                            JSON built at API layer from notes_tag lookup)
--   tags            -> '0' (data_gap: confirmed absent from additionalnotes;
--                            value hardcoded at API layer)
--   screenName      -> additionalnotes.moduleName
--   createdById     -> additionalnotes.createdBy
--   createdByName   -> CONCAT(u2.ulname, ', ', u2.ufname)
--   updatedOn       -> FORMAT(most recent additionalnotes_logs.modifiedOn,
--                             'MMM dd,yyyy hh:mm:ss tt')
--                      fallback: FORMAT(additionalnotes.createdOn, ...)
--   createdOn       -> FORMAT(additionalnotes.createdOn, 'MMM dd,yyyy hh:mm:ss tt')
--   isDeviceAvailable -> 'false' (data_gap: confirmed absent from additionalnotes)
--   isRPMNotes      -> 'false' (data_gap: confirmed absent from additionalnotes)
--   total           -> COUNT(*) OVER ()
-- ============================================================

-- Lookup: find a patientId with additionalnotes records
--
--   SELECT TOP 10 an.Id, an.patientId, an.date, an.Message, an.moduleName
--   FROM mobiledoc.dbo.additionalnotes an WITH (NOLOCK)
--   WHERE ISNULL(an.deleteFlag, 0) = 0
--   ORDER BY an.Id DESC;

-- DIAGNOSTIC: look up the note by Id to find the correct patientId
--
--   SELECT Id, patientId, LoggedInUid, date, Message, moduleName, createdOn
--   FROM mobiledoc.dbo.additionalnotes
--   WHERE Id = 13573;
--
-- Also try browsing recent notes:
--
--   SELECT TOP 20 Id, patientId, LoggedInUid, date, Message, moduleName
--   FROM mobiledoc.dbo.additionalnotes WITH (NOLOCK)
--   ORDER BY Id DESC;

DECLARE @patientId INT = 270001;

SELECT
    CAST(an.Id AS varchar)                                                          AS id,
    CAST(an.LoggedInUid AS varchar)                                                 AS loginUserId,
    ISNULL(CONCAT(u1.ulname, ', ', u1.ufname), '')                                  AS loginUserName,
    CONVERT(varchar, an.date, 23)                                                   AS date,
    CONVERT(varchar, an.time, 108)                                                  AS time,
    ISNULL(CAST(an.Message AS varchar(max)), '')                                    AS message,
    ISNULL(an.subjectData, '')                                                      AS subject,
    CAST(an.deleteFlag AS varchar)                                                  AS deleteFlag,
    NULL                                                                            AS arrStatus,
    '0'                                                                             AS tags,
    ISNULL(an.moduleName, '')                                                       AS screenName,
    CAST(ISNULL(an.createdBy, 0) AS varchar)                                        AS createdById,
    ISNULL(CONCAT(u2.ulname, ', ', u2.ufname), '')                                  AS createdByName,
    FORMAT(ISNULL(anl.latestModifiedOn, an.createdOn), 'MMM dd,yyyy hh:mm:ss tt')  AS updatedOn,
    FORMAT(an.createdOn, 'MMM dd,yyyy hh:mm:ss tt')                                AS createdOn,
    'false'                                                                         AS isDeviceAvailable,
    'false'                                                                         AS isRPMNotes,
    COUNT(*) OVER ()                                                                AS total

FROM mobiledoc.dbo.additionalnotes an

    LEFT JOIN mobiledoc.dbo.users u1
        ON  u1.uid = an.LoggedInUid

    LEFT JOIN mobiledoc.dbo.users u2
        ON  u2.uid = an.createdBy

    LEFT JOIN (
        SELECT   notesId,
                 MAX(modifiedOn) AS latestModifiedOn
        FROM     mobiledoc.dbo.additionalnotes_logs
        GROUP BY notesId
    ) anl ON anl.notesId = an.Id

WHERE an.patientId  = @patientId
  AND ISNULL(an.deleteFlag, 0) = 0

ORDER BY an.date DESC, an.time DESC;
