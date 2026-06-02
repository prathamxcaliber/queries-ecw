-- ============================================================
-- Encounters Query
-- Returns fields matching the EHR Encounters API payload shape
-- ============================================================
-- Tables joined:
--   enc                 : core encounter record (date, time, visitType, encType, reason, doctorID, facilityId)
--   patients            : insname (primary insurance), pharmacyname, textenabled
--   users (patient)     : name, dob, sex, phone, email
--   users (doctor)      : doctorName, providerName
--   edi_facilities      : facilityName
--   telenc              : ticketId, uid, caller, message, actiontaken (notes),
--                         priority, virtualflag, assignedTo, pmcid
--   users (telenc user) : userFullName
--   pharmacy            : pharmacyName (via telenc.pmcid)
-- ============================================================
-- NOTE: assignedTo and ticketId appear in both encounter{} and
--       responseSummary{} sections of the EHR response. They map
--       to the same source columns (telenc.assignedTo, telenc.TicketID).
-- ============================================================

DECLARE @encounterId INT = 3256805;   -- Replace with target encounterId

SELECT

    -- ── Root ────────────────────────────────────────────────────────
    CAST(e.encounterID AS varchar)                                  AS encounterId,

    -- ── patient.* ───────────────────────────────────────────────────
    CAST(e.patientID AS varchar)                                    AS patientId,
    CONCAT(u.ulname, ', ', u.ufname)                                AS [name],
    FORMAT(CONVERT(date, u.dob, 101), 'MM/dd/yyyy')                AS dob,
    LOWER(ISNULL(u.sex, ''))                                        AS sex,
    CAST(
        DATEDIFF(year, CAST(u.dob AS date), CAST(GETDATE() AS date))
        - CASE
            WHEN FORMAT(GETDATE(), 'MMdd') < FORMAT(CAST(u.dob AS date), 'MMdd')
            THEN 1 ELSE 0
          END
    AS varchar) + ' Y'                                             AS age,

    -- ── encounter.* ─────────────────────────────────────────────────
    CONVERT(varchar(10), CAST(e.date AS date), 23)                  AS [date],
    -- time: enc.date stores midnight; enc.startTime holds the actual encounter time
    CONVERT(varchar(8),  CAST(ISNULL(e.startTime, e.date) AS time), 108)  AS [time],
    ISNULL(e.VisitType, '')                                         AS visitType,
    CAST(ISNULL(e.encType, 0) AS varchar)                           AS encType,
    ISNULL(CAST(e.reason AS varchar(MAX)), '')                      AS reason,
    -- doctorName: "Lastname, Firstname" (no initials)
    ISNULL(doc.ulname + ', ' + doc.ufname, '')                      AS doctorName,
    -- assignedTo: same value repeated in responseSummary
    ISNULL(t.assignedTo, '')                                        AS assignedTo,
    -- ticketId: same value repeated in responseSummary
    CAST(ISNULL(t.TicketID, 0) AS varchar)                         AS ticketId,
    ISNULL(ef.Name, '')                                             AS facilityName,

    -- ── contact.* ───────────────────────────────────────────────────
    -- phone: prefer mobile, fall back to home phone
    ISNULL(NULLIF(u.umobileno, ''), ISNULL(NULLIF(u.upPhone, ''), ''))  AS phone,
    ISNULL(u.uemail, '')                                            AS email,
    CAST(ISNULL(p.textenabled, 0) AS varchar)                      AS textEnabled,

    -- ── insurance.* ─────────────────────────────────────────────────
    -- primaryInsurance: patients.insname is often empty; authoritative source is
    -- insurancedetail (SeqNo=1 = primary) joined to insurance master
    ISNULL(pri_ins.insuranceName, ISNULL(NULLIF(p.insname, ''), ''))  AS primaryInsurance,

    -- ── pharmacy.* ──────────────────────────────────────────────────
    -- prefer pharmacy master name (via telenc.pmcid), fall back to denormalized patients.pharmacyname
    ISNULL(ph.pharmacyname, ISNULL(p.pharmacyname, ''))             AS pharmacyName,

    -- ── responseSummary.* ───────────────────────────────────────────
    CAST(ISNULL(t.uid, 0) AS varchar)                              AS uid,
    -- userFullName: the user who handled the telephone encounter
    ISNULL(tuser.ulname + ', ' + tuser.ufname, '')                  AS userFullName,
    -- providerName: "Lastname, Firstname I" (with middle initial)
    ISNULL(
        doc.ulname + ', ' + doc.ufname +
        CASE WHEN doc.uminitial IS NOT NULL AND doc.uminitial != ''
             THEN ' ' + doc.uminitial ELSE ''
        END,
    '')                                                             AS providerName,
    ISNULL(CAST(t.Caller AS varchar(MAX)), '')                      AS caller,
    ISNULL(CAST(t.message AS varchar(MAX)), '')                     AS [message],
    -- notes: telenc.actiontaken is the primary source; fall back to enc.generalNotes
    ISNULL(
        NULLIF(CAST(t.actiontaken AS varchar(MAX)), ''),
        ISNULL(CAST(e.generalNotes AS varchar(MAX)), '')
    )                                                              AS notes,
    CAST(ISNULL(t.priority, 0) AS varchar)                         AS priority,
    CAST(ISNULL(t.virtualflag, 0) AS varchar)                      AS virtualFlag,
    -- pharmacyId: from telenc.pmcid (pharmacy master id)
    CAST(ISNULL(t.pmcid, 0) AS varchar)                            AS pharmacyId

FROM mobiledoc.dbo.enc e

    LEFT JOIN mobiledoc.dbo.patients p
        ON p.pid = e.patientID

    LEFT JOIN mobiledoc.dbo.users u
        ON u.uid = e.patientID

    LEFT JOIN mobiledoc.dbo.users doc
        ON doc.uid = e.doctorID

    LEFT JOIN mobiledoc.dbo.edi_facilities ef
        ON ef.Id = e.facilityId
        AND ISNULL(ef.DeleteFlag, 0) = 0

    -- Get the most recent telephone encounter record linked to this enc
    OUTER APPLY (
        SELECT TOP 1
            t2.TicketID,
            t2.uid,
            t2.Caller,
            t2.message,
            t2.actiontaken,
            t2.priority,
            t2.assignedTo,
            t2.assignedToId,
            t2.virtualflag,
            t2.pmcid
        FROM mobiledoc.dbo.telenc t2
        WHERE t2.encounterId = e.encounterID
          AND ISNULL(t2.teldeleteflag, 0) = 0
        ORDER BY t2.TicketID DESC
    ) t

    LEFT JOIN mobiledoc.dbo.users tuser
        ON tuser.uid = t.uid

    LEFT JOIN mobiledoc.dbo.pharmacy ph
        ON ph.pmcid = t.pmcid
        AND ISNULL(ph.delFlag, 0) = 0

    -- Primary insurance: SeqNo=1 in insurancedetail
    OUTER APPLY (
        SELECT TOP 1 ins.insuranceName
        FROM mobiledoc.dbo.insurancedetail idr
        JOIN  mobiledoc.dbo.insurance      ins ON ins.insId = idr.insid
        WHERE idr.pid        = e.patientID
          AND idr.DeleteFlag = 0
          AND idr.SeqNo      = 1
    ) pri_ins

WHERE e.encounterID = @encounterId
  AND ISNULL(e.deleteFlag, 0) = 0;
