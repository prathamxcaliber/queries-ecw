-- ============================================================
-- Problems (Active Problem List) Query
-- Returns fields matching the EHR Problems API payload shape.
-- One row per problem per patient.
-- ============================================================
-- EHR shape: one object per problem with fields:
--   notes, snowMedCode, problemtype, userid, icdversion, itemid,
--   AddedDate, onsetdate, overdue, logdate, inactiveFlag, hccFlag,
--   PrimServiceLoc, isICDValid, severity, strHccDig, wustatus,
--   itemname, specify, encounterid, condition, itemcode, risk,
--   hcc_com_flag, convFlag, username, resolvedon
-- ============================================================
-- Tables joined:
--   problemlist  : core record (patientId, asmtId, condition,
--                  ProblemType, SNOMED, WUStatus, Risk, etc.)
--   items        : problem display name via problemlist.asmtId = items.itemID
--                  (items.itemName = ECW display label)
--   users        : username via problemlist.userid = users.uid
--
-- NOTE: ICD code (itemcode / strHccDig / icdversion / hccFlag /
--       hcc_com_flag / snowMedCode) and PrimServiceLoc cannot be
--       resolved from accessible tables — returned as NULL (data_gap).
--       items.keyName = "Assessments" (category marker, not ICD),
--       items.vmid = internal GUID, items.parentID chain leads to
--       category containers, icd table IDs do not match asmtId/parentID,
--       and problemlist has no ICD code column.
-- ============================================================
-- Column mappings:
--   notes         → CAST(problemlist.notes AS varchar)
--   snowMedCode   → NULL (data_gap: ICD code source not found)
--   problemtype   → problemlist.ProblemType
--   userid        → problemlist.userid
--   icdversion    → NULL (data_gap: ICD code source not found)
--   itemid        → problemlist.asmtId
--   AddedDate     → problemlist.AddedDate
--   onsetdate     → problemlist.onsetdate
--   overdue       → NULL (data_gap: derived/calculated, no DB column)
--   logdate       → problemlist.logdate
--   inactiveFlag  → problemlist.inactiveFlag
--   hccFlag       → NULL (data_gap: ICD code source not found)
--   PrimServiceLoc→ NULL (data_gap: specialityId is NULL for test data)
--   isICDValid    → NULL (data_gap: derived from ICD validation logic)
--   severity      → NULL (data_gap: no DB column identified)
--   strHccDig     → NULL (data_gap: ICD code source not found)
--   wustatus      → problemlist.WUStatus
--   itemname      → items.itemName (ECW display name)
--   specify       → problemlist.specify
--   encounterid   → problemlist.encounterId
--   condition     → problemlist.condition
--   itemcode      → NULL (data_gap: ICD code source not found)
--   risk          → problemlist.Risk
--   hcc_com_flag  → NULL (data_gap: ICD code source not found)
--   convFlag      → problemlist.newlyadded
--   username      → users.ulname + ', ' + users.ufname
--   resolvedon    → problemlist.resolvedon
-- ============================================================

-- ── Lookup: find a patientId with problem list records ───────────────────
--
--   SELECT TOP 10 patientId, condition, ProblemType, asmtId
--   FROM mobiledoc.dbo.problemlist WITH (NOLOCK)
--   WHERE ISNULL(deleteFlag, 0) = 0
--     AND asmtId > 0
--   ORDER BY patientId;
--
-- ─────────────────────────────────────────────────────────────────────────

DECLARE @patientId INT = 275735;   -- Verified: has problem list entries with asmtId

SELECT
    CAST(ISNULL(pl.notes, '') AS varchar(max))                  AS notes,
    NULL                                                        AS snowMedCode,
    ISNULL(pl.ProblemType, '')                                  AS problemtype,
    CAST(pl.userid AS varchar)                                  AS userid,
    NULL                                                        AS icdversion,
    CAST(pl.asmtId AS varchar)                                  AS itemid,
    ISNULL(pl.AddedDate, '')                                    AS AddedDate,
    ISNULL(pl.onsetdate, '')                                    AS onsetdate,
    NULL                                                        AS overdue,
    ISNULL(pl.logdate, '')                                      AS logdate,
    CAST(ISNULL(pl.inactiveFlag, 0) AS varchar)                 AS inactiveFlag,
    NULL                                                        AS hccFlag,
    NULL                                                        AS PrimServiceLoc,
    NULL                                                        AS isICDValid,
    NULL                                                        AS severity,
    NULL                                                        AS strHccDig,
    ISNULL(pl.WUStatus, '')                                     AS wustatus,
    ISNULL(i.itemName, '')                                      AS itemname,
    ISNULL(pl.specify, '')                                      AS specify,
    CAST(pl.encounterId AS varchar)                             AS encounterid,
    ISNULL(pl.condition, '')                                    AS condition,
    NULL                                                        AS itemcode,
    ISNULL(pl.Risk, '')                                         AS risk,
    NULL                                                        AS hcc_com_flag,
    CAST(ISNULL(pl.newlyadded, 0) AS varchar)                   AS convFlag,
    ISNULL(u.ulname, '') + ', ' + ISNULL(u.ufname, '')          AS username,
    ISNULL(pl.resolvedon, '')                                   AS resolvedon

FROM mobiledoc.dbo.problemlist pl

    LEFT JOIN mobiledoc.dbo.items i
        ON  i.itemID              = pl.asmtId
        AND ISNULL(pl.asmtId, 0) > 0
        AND ISNULL(i.deleteFlag, 0) = 0

    LEFT JOIN mobiledoc.dbo.users u
        ON  u.uid                 = pl.userid

WHERE pl.patientId              = @patientId
  AND ISNULL(pl.deleteFlag, 0)  = 0

ORDER BY ISNULL(pl.displayIndex, 9999), pl.SlNo;
