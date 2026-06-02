-- ============================================================
-- Referrals Query
-- Returns fields matching the EHR Referral API payload shape.
-- Single SELECT -- one row per referral.
-- ============================================================
-- Tables joined:
--   referral               : core referral record (ReferralId PK, patientID, refFrom, RefTo,
--                            status, date, reason, insId, refStDate, refEnddate, apptDate,
--                            refEncId, extNHXRefTxId, p2pDeliveryStatus, modifiedDate,
--                            visitsAllowed, visitsUsed, cptunitsallowed, cptunitsused,
--                            priority, referralType, fromfacility, ToFacility, speciality,
--                            refReqId, refFromName, refFromP2pNPI, refToName, refToP2pNPI,
--                            referral360id, deleteFlag)
--   users (patient)        : ptFullName, dob, mobile, age, gender via referral.patientID
--   users (refFrom)        : refFromFullName via referral.refFrom (doctor userId)
--   users (refTo)          : refToFullName via referral.RefTo (doctor userId)
--   insurance              : insuranceName via referral.insId
--   edi_facilities (from)  : FromFacility name via referral.fromfacility
--   edi_facilities (to)    : ToFacility name via referral.ToFacility
--   edi_speciality         : refToSpeciality name via referral.speciality
--   nhxreferral            : nhxMsgTxId via nhxreferral.apuId = referral.ReferralId
--                            (NOTE: verify join key -- apuId may map differently)
-- ============================================================
-- Column mappings:
--   referralId             -> referral.ReferralId
--   patientId              -> referral.patientID
--   requestStatus          -> referralstatus.id (joined on referralstatus.status = referral.status)
--   date                   -> referral.date as MM/dd/yyyy
--   reason                 -> referral.reason
--   insuranceName          -> insurance.insuranceName
--   refStDate              -> referral.refStDate as MM/dd/yyyy
--   refEnddate             -> referral.refEnddate as MM/dd/yyyy
--   ApptDate               -> referral.apptDate as MM/dd/yyyy ('' if NULL or sentinel 01/01/1901)
--   refEncId               -> referral.refEncId (0 if NULL)
--   extNHXRefTxId          -> referral.extNHXRefTxId (0 if NULL)
--   p2pDeliveryStatus      -> referral.p2pDeliveryStatus (0 if NULL)
--   updateTime             -> referral.modifiedDate as 'MMM-dd hh:mm tt'
--   visitsAllowed          -> referral.visitsAllowed (0 if NULL)
--   visitsUsed             -> referral.visitsUsed (0 if NULL)
--   cptunitsallowed        -> referral.cptunitsallowed (0 if NULL)
--   cptunitsused           -> referral.cptunitsused (0 if NULL)
--   priority               -> referral.priority (0 if NULL)
--   recType                -> referral.authtype (stores 'REF'; referralType stores 'O' which is wrong)
--   refFromFullName        -> users.ulname + ', ' + ufname + ', ' + uminitial (refFrom user)
--   refToFullName          -> users.ulname + ', ' + ufname + ', ' + uminitial (refTo user)
--   ptFullName             -> users.ulname + ',' + ufname (no space -- matches EHR format)
--   userId                 -> referral.patientID (same value as patientId)
--   userName               -> users.ulname + ',' + ufname (same as ptFullName)
--   dob                    -> users.dob as MM/dd/yyyy
--   mobile                 -> users.umobileno
--   age                    -> computed from users.dob
--   gender                 -> UPPER(LEFT(users.sex,1)) -- DB stores 'male'/'female'; EHR expects 'M'/'F'
--   FromFacility           -> edi_facilities.Name via referral.fromfacility
--   ToFacility             -> edi_facilities.Name via referral.ToFacility
--   refToSpeciality        -> edi_speciality.Speciality via referral.speciality
--   refReqId               -> referral.refReqId (0 if NULL)
--   refFromName            -> referral.refFromName (stored name string)
--   refFromP2PNPI          -> referral.refFromP2pNPI ('0' if NULL)
--   encryptedRefFromP2PNPI -> NULL (encrypted value computed at API layer; not in DB)
--   encodedEncryptionKey   -> NULL (encryption key not stored in DB)
--   refTo                  -> referral.RefTo (doctor userId)
--   refToName              -> referral.refToName (stored name string)
--   refToP2PNPI            -> referral.refToP2pNPI ('0' if NULL)
--   referral360id          -> referral.referral360id ('' if NULL)
--   nhxMsgTxId             -> nhxreferral.nhxMsgTxId (0 if NULL)
--   decline_reason         -> '' (no DB column; EHR returns '' so return empty string)
-- ============================================================

DECLARE @referralId INT = 166837;   -- Replace with target referralId

SELECT

    -- ══════════════════════════════════════════════════════
    -- Core referral fields
    -- ══════════════════════════════════════════════════════
    CAST(r.ReferralId AS varchar)                                          AS referralId,
    CAST(r.patientID AS varchar)                                           AS patientId,
    ISNULL(CAST(rs.id AS varchar), '')                                       AS requestStatus,
    ISNULL(CONVERT(varchar(10), r.[date], 101), '')                        AS [date],
    ISNULL(CAST(r.reason AS varchar(MAX)), '')                             AS reason,
    ISNULL(ins.insuranceName, '')                                          AS insuranceName,
    ISNULL(CONVERT(varchar(10), r.refStDate, 101), '')                     AS refStDate,
    ISNULL(CONVERT(varchar(10), r.refEnddate, 101), '')                    AS refEnddate,
    CASE WHEN r.apptDate IS NULL OR YEAR(r.apptDate) = 1901
         THEN ''
         ELSE CONVERT(varchar(10), r.apptDate, 101)
    END                                                                        AS ApptDate,
    CAST(ISNULL(r.refEncId, 0) AS varchar)                                 AS refEncId,
    CAST(ISNULL(r.extNHXRefTxId, 0) AS varchar)                           AS extNHXRefTxId,
    CAST(ISNULL(r.p2pDeliveryStatus, 0) AS varchar)                       AS p2pDeliveryStatus,

    -- updateTime: 'Apr-06 04:12 AM' format
    ISNULL(FORMAT(r.modifiedDate, 'MMM-dd hh:mm tt'), '')                  AS updateTime,

    CAST(ISNULL(r.visitsAllowed, 0) AS varchar)                            AS visitsAllowed,
    CAST(ISNULL(r.visitsUsed, 0) AS varchar)                              AS visitsUsed,
    CAST(ISNULL(r.cptunitsallowed, 0) AS varchar)                         AS cptunitsallowed,
    CAST(ISNULL(r.cptunitsused, 0) AS varchar)                            AS cptunitsused,
    CAST(ISNULL(r.priority, 0) AS varchar)                                AS priority,
    ISNULL(r.authtype, '')                                                    AS recType,

    -- ══════════════════════════════════════════════════════
    -- Doctor names (from users table; falls back to stored referral name if no user row)
    -- ══════════════════════════════════════════════════════
    ISNULL(
        ufrom.ulname + ', ' + ufrom.ufname
        + CASE WHEN ISNULL(ufrom.uminitial, '') <> '' THEN ', ' + ufrom.uminitial ELSE '' END,
        ISNULL(r.refFromName, '')
    )                                                                      AS refFromFullName,

    ISNULL(
        uto.ulname + ', ' + uto.ufname
        + CASE WHEN ISNULL(uto.uminitial, '') <> '' THEN ', ' + uto.uminitial ELSE '' END,
        ISNULL(r.refToName, '')
    )                                                                      AS refToFullName,

    -- ══════════════════════════════════════════════════════
    -- Patient fields
    -- ══════════════════════════════════════════════════════
    ISNULL(u.ulname + ',' + u.ufname, '')                                  AS ptFullName,
    CAST(r.patientID AS varchar)                                           AS userId,
    ISNULL(u.ulname + ',' + u.ufname, '')                                  AS userName,
    ISNULL(FORMAT(CONVERT(date, u.dob, 101), 'MM/dd/yyyy'), '')           AS dob,
    ISNULL(u.umobileno, '')                                                AS mobile,
    CAST(
        DATEDIFF(year, CONVERT(date, u.dob, 101), CAST(GETDATE() AS date))
        - CASE WHEN FORMAT(GETDATE(), 'MMdd') < FORMAT(CONVERT(date, u.dob, 101), 'MMdd')
               THEN 1 ELSE 0
          END
    AS varchar) + ' Y'                                                     AS age,
    ISNULL(UPPER(LEFT(u.sex, 1)), '')                                        AS gender,

    -- ══════════════════════════════════════════════════════
    -- Facility names
    -- ══════════════════════════════════════════════════════
    ISNULL(ef_from.Name, '')                                               AS FromFacility,
    ISNULL(ef_to.Name, '')                                                 AS ToFacility,

    -- ══════════════════════════════════════════════════════
    -- Speciality
    -- ══════════════════════════════════════════════════════
    ISNULL(es.Speciality, '')                                              AS refToSpeciality,

    -- ══════════════════════════════════════════════════════
    -- Referral routing / P2P fields
    -- ══════════════════════════════════════════════════════
    CAST(ISNULL(r.refReqId, 0) AS varchar)                                 AS refReqId,
    ISNULL(r.refFromName, '')                                              AS refFromName,
    ISNULL(r.refFromP2pNPI, '0')                                           AS refFromP2PNPI,
    NULL                                                                   AS encryptedRefFromP2PNPI,  -- API-layer encryption; not in DB
    NULL                                                                   AS encodedEncryptionKey,    -- Encryption key not in DB
    CAST(ISNULL(r.RefTo, 0) AS varchar)                                    AS refTo,
    ISNULL(r.refToName, '')                                                AS refToName,
    ISNULL(r.refToP2pNPI, '0')                                             AS refToP2PNPI,
    ISNULL(r.referral360id, '')                                            AS referral360id,
    CAST(ISNULL(nhx.nhxMsgTxId, 0) AS varchar)                            AS nhxMsgTxId,
    ''                                                                     AS decline_reason           -- No DB column; EHR returns '' so return empty string

FROM mobiledoc.dbo.referral r

    LEFT JOIN mobiledoc.dbo.users u
        ON  u.uid = r.patientID

    LEFT JOIN mobiledoc.dbo.users ufrom
        ON  ufrom.uid = r.refFrom

    LEFT JOIN mobiledoc.dbo.users uto
        ON  uto.uid = r.RefTo

    LEFT JOIN mobiledoc.dbo.referralstatus rs
        ON  rs.status = r.status

    LEFT JOIN mobiledoc.dbo.insurance ins
        ON  ins.insId = r.insId

    LEFT JOIN mobiledoc.dbo.edi_facilities ef_from
        ON  ef_from.Id                    = r.fromfacility
        AND ISNULL(ef_from.DeleteFlag, 0) = 0

    LEFT JOIN mobiledoc.dbo.edi_facilities ef_to
        ON  ef_to.Id                    = r.ToFacility
        AND ISNULL(ef_to.DeleteFlag, 0) = 0

    LEFT JOIN mobiledoc.dbo.edi_speciality es
        ON  es.Id                    = r.speciality
        AND ISNULL(es.deleteFlag, 0) = 0

    LEFT JOIN mobiledoc.dbo.nhxreferral nhx
        ON  nhx.apuId = r.ReferralId    -- NOTE: verify this join key against actual data

WHERE r.ReferralId        = @referralId
  AND ISNULL(r.deleteFlag, 0) = 0;
