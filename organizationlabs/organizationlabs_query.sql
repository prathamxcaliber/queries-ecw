-- ============================================================
-- Organization Labs Query
-- Returns fields matching the EHR Organization Labs API payload shape.
-- Lab/procedure catalog items with billing/ordering attributes.
-- ============================================================
-- EHR shape: { CommunityId, LabInstructionExist, LinkedLocalItems,
--              alias, approvalRequired, billable, documentStructuredResults,
--              exceptionReasonComment, exceptionReasonId, id, inactive,
--              ignoreProcedureValidations, lab, labCode, labName, nFavId,
--              name, orderItemType, pocflag, publishportal, result,
--              showPathologyDetail, sortOverride, supplierID, tooltip,
--              type }
-- ============================================================
-- Tables joined:
--   items        : core item record (itemID PK, itemName, itemType, inactive,
--                  showPathologyDetail, supplierId, deleteFlag)
--   billablelab  : billing/ordering config (code = itemID) — billable,
--                  publishportal, approvalrequired, documentStructuredResults,
--                  ignoreprocedurevalidations, orderItemType, pocflag,
--                  exceptionReasonId, exceptionReasonComment
-- ============================================================
-- Column mappings:
--   id                        -> items.itemID
--   name                      -> items.itemName
--   type                      -> items.itemType (char, e.g. 'C')
--   inactive                  -> items.inactive (0 if NULL)
--   showPathologyDetail        -> items.showPathologyDetail (0 if NULL)
--   supplierID                -> items.supplierId (0 if NULL)
--   documentStructuredResults  -> billablelab.documentStructuredResults (0 if NULL)
--   ignoreProcedureValidations -> billablelab.ignoreprocedurevalidations (0 if NULL)
--   orderItemType             -> billablelab.orderItemType (0 if NULL)
--   pocflag                   -> billablelab.pocflag (0 if NULL)
--   billable                  -> billablelab.billable ('' if NULL — nullable smallint)
--   publishportal             -> billablelab.publishportal ('' if NULL)
--   approvalRequired          -> billablelab.approvalrequired ('' if NULL)
--   exceptionReasonId         -> billablelab.exceptionReasonId ('' if NULL)
--   exceptionReasonComment    -> billablelab.exceptionReasonComment ('' if NULL)
-- ============================================================
-- Fields hardcoded (no DB column in filtered CSV):
--   CommunityId, LinkedLocalItems, alias, lab, labCode, labName,
--   nFavId, tooltip, sortOverride, result, LabInstructionExist
-- ============================================================

DECLARE @itemId INT = 224611;

SELECT

    -- Item core
    i.itemID                                                               AS id,
    ISNULL(i.itemName, '')                                                 AS [name],
    ISNULL(RTRIM(i.itemType), '')                                          AS [type],
    ISNULL(i.inactive, 0)                                                  AS inactive,
    ISNULL(i.showPathologyDetail, 0)                                       AS showPathologyDetail,
    ISNULL(i.supplierId, 0)                                                AS supplierID,

    -- Billing / ordering flags from billablelab (int types — 0 when no row)
    ISNULL(bl.documentStructuredResults, 0)                                AS documentStructuredResults,
    ISNULL(bl.ignoreprocedurevalidations, 0)                               AS ignoreProcedureValidations,
    ISNULL(bl.orderItemType, 0)                                            AS orderItemType,
    ISNULL(bl.pocflag, 0)                                                  AS pocflag,

    -- Nullable varchar/smallint fields — return '' when NULL (EHR shows "")
    ISNULL(CAST(bl.billable AS varchar), '')                               AS billable,
    ISNULL(CAST(bl.publishportal AS varchar), '')                          AS publishportal,
    ISNULL(CAST(bl.approvalrequired AS varchar), '')                       AS approvalRequired,
    ISNULL(CAST(bl.exceptionReasonId AS varchar), '')                      AS exceptionReasonId,
    ISNULL(bl.exceptionReasonComment, '')                                  AS exceptionReasonComment,

    -- Fields with no DB column (all empty/default in EHR sample)
    ''                                                                     AS CommunityId,
    'no'                                                                   AS LabInstructionExist,
    ''                                                                     AS LinkedLocalItems,
    ''                                                                     AS alias,
    ''                                                                     AS lab,
    ''                                                                     AS labCode,
    ''                                                                     AS labName,
    0                                                                      AS nFavId,
    ''                                                                     AS tooltip,
    ''                                                                     AS sortOverride,
    ''                                                                     AS result

FROM mobiledoc.dbo.items i

    LEFT JOIN mobiledoc.dbo.billablelab bl
        ON  bl.code = i.itemID

WHERE i.itemID             = @itemId
  AND ISNULL(i.deleteFlag, 0) = 0;
