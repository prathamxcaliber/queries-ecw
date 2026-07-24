-- Source-format medications query (target row)
WITH target_rx AS (
    SELECT TOP 1
        orm.OldRxId,
        orm.RxOrderNo,
        orm.MedicineName,
        orm.ItemId,
        orm.encounterId,
        orm.PatientsFlag,
        orm.DoctorsFlag,
        orm.AssessId,
        orm.ndc_code,
        orm.StartDate,
        orm.StopDate,
        orm.rxNotes,
        orm.PreparedBy,
        orm.PreparedById,
        orm.Refill,
        orm.FillStatus,
        orm.LastTaken,
        orm.rxkop,
        orm.rxDrugSource,
        orm.disconorstopnotes
    FROM mobiledoc.dbo.oldrxmain orm
    WHERE orm.OldRxId = 5293269
      AND orm.RxOrderNo = 'S2623956190329135240'
      AND orm.PatientsFlag = 1
      AND orm.DoctorsFlag = -1
),
rxorderno_stats AS (
    SELECT
        orm.RxOrderNo,
        COUNT(*) AS rx_cnt
    FROM mobiledoc.dbo.oldrxmain orm
    INNER JOIN target_rx t
        ON t.RxOrderNo = orm.RxOrderNo
    GROUP BY orm.RxOrderNo
),
arh_pick AS (
    SELECT
        t.OldRxId,
        a.doctorId AS arh_doctorId,
        a.RxStrengthId,
        a.RxStrengthValue,
        a.RxTakeId,
        a.RxTakeValue,
        a.RxRouteId,
        a.RxRouteValue,
        a.RxFrequencyId,
        a.RxFrequencyValue,
        a.RxDurationId,
        a.RxDurationValue,
        a.RxDispenseId,
        a.RxDispenseValue,
        a.RxRefillsId,
        a.RxRefillsValue,
        a.RxFormulationId,
        a.RxFormulationValue
    FROM target_rx t
    OUTER APPLY (
        SELECT TOP 1 arh.*
        FROM mobiledoc.dbo.assessment_rx_history arh
        WHERE arh.OldRxId = t.OldRxId
          AND ISNULL(arh.delFlag, 0) = 0
        ORDER BY
            CASE
                WHEN arh.AsmtId = t.AssessId THEN 0
                WHEN arh.encounterId = t.encounterId AND arh.RxItemId = t.ItemId THEN 1
                WHEN arh.encounterId = t.encounterId THEN 2
                WHEN arh.RxItemId = t.ItemId THEN 3
                ELSE 4
            END,
            ISNULL(arh.LastHistoryDate, arh.encDate) DESC,
            arh.Id DESC
    ) a
),
detail_rows AS (
    SELECT
        d.OldRxId,
        d.Prop,
        d.value,
        LOWER(ISNULL(p.ItemName, '')) AS prop_name,
        COALESCE(NULLIF(v.ItemName, ''), NULLIF(v.ItemValue, ''), d.value) AS display_value,
        CASE WHEN ISNUMERIC(d.value) = 1 THEN CONVERT(int, d.value) END AS parsed_id
    FROM mobiledoc.dbo.oldrxdetail d
    INNER JOIN target_rx t
        ON t.OldRxId = d.OldRxId
    LEFT JOIN mobiledoc.dbo.definition p
        ON p.DefNum = d.Prop
    LEFT JOIN mobiledoc.dbo.definition v
        ON v.DefNum = CASE WHEN ISNUMERIC(d.value) = 1 THEN CONVERT(bigint, d.value) END
),
detail_pivot AS (
    SELECT
        dr.OldRxId,
        MAX(CASE WHEN dr.Prop = 51 OR dr.prop_name LIKE '%strength%' THEN dr.display_value END) AS StrengthValue,
        MAX(CASE WHEN dr.Prop = 51 OR dr.prop_name LIKE '%strength%' THEN 51 END) AS StrengthID,
        MAX(CASE WHEN dr.Prop = 52 OR dr.prop_name LIKE '%take%' THEN dr.display_value END) AS TakeValue,
        MAX(CASE WHEN dr.Prop = 52 OR dr.prop_name LIKE '%take%' THEN 52 END) AS TakeID,
        MAX(CASE WHEN dr.Prop = 47 OR dr.prop_name LIKE '%route%' THEN dr.display_value END) AS RouteValue,
        MAX(CASE WHEN dr.Prop = 47 OR dr.prop_name LIKE '%route%' THEN 47 END) AS RouteID,
        MAX(CASE WHEN dr.Prop = 46 OR dr.prop_name LIKE '%frequen%' THEN dr.display_value END) AS FrequencyValue,
        MAX(CASE WHEN dr.Prop = 46 OR dr.prop_name LIKE '%frequen%' THEN 46 END) AS FrequencyID,
        MAX(CASE WHEN dr.Prop = 49 OR dr.prop_name LIKE '%duration%' THEN dr.display_value END) AS DurationValue,
        MAX(CASE WHEN dr.Prop = 49 OR dr.prop_name LIKE '%duration%' THEN 49 END) AS DurationID,
        MAX(CASE WHEN dr.Prop = 53 OR dr.prop_name LIKE '%dispense%' OR dr.prop_name LIKE '%quantity%' THEN dr.display_value END) AS DispenseValue,
        MAX(CASE WHEN dr.Prop = 53 OR dr.prop_name LIKE '%dispense%' OR dr.prop_name LIKE '%quantity%' THEN 53 END) AS DispenseID,
        MAX(CASE WHEN dr.Prop = 48 OR dr.prop_name LIKE '%refill%' THEN dr.display_value END) AS RefillsValue,
        MAX(CASE WHEN dr.Prop = 48 OR dr.prop_name LIKE '%refill%' THEN 48 END) AS RefillsID,
        MAX(CASE WHEN dr.prop_name LIKE '%formulation%' OR dr.Prop = 50 THEN dr.display_value END) AS FormulationValue,
        MAX(CASE WHEN dr.prop_name LIKE '%formulation%' OR dr.Prop = 50 THEN dr.parsed_id END) AS FormulationID
    FROM detail_rows dr
    GROUP BY dr.OldRxId
),
dx_pick AS (
    SELECT
        t.OldRxId,
        COALESCE(md.itemName, md_by_name.itemName, it.itemName, '') AS DxNameOnly,
        COALESCE(md.code, md_by_name.code, '') AS DxCodeOnly
    FROM target_rx t
    OUTER APPLY (
        SELECT TOP 1 d.ItemId
        FROM mobiledoc.dbo.diagnosis d
        WHERE d.EncounterId = t.encounterId
        ORDER BY ISNULL(d.displayIndex, 9999), d.SlNo
    ) d1
    LEFT JOIN mobiledoc.dbo.items it
        ON it.itemID = d1.ItemId
    LEFT JOIN mobiledoc.dbo.mcmp_dxcode md
        ON md.itemId = d1.ItemId
    LEFT JOIN mobiledoc.dbo.mcmp_dxcode md_by_name
        ON md_by_name.itemName = it.itemName
),
doc_user AS (
    SELECT
        u.uid,
        LTRIM(RTRIM(
            ISNULL(NULLIF(u.ulname, ''), '')
            + CASE WHEN NULLIF(u.ufname, '') IS NOT NULL THEN ', ' + u.ufname ELSE '' END
            + CASE WHEN NULLIF(u.uminitial, '') IS NOT NULL THEN ' ' + LEFT(u.uminitial, 1) ELSE '' END
        )) AS docCodeInitials
    FROM mobiledoc.dbo.users u
),
prep_user AS (
    SELECT
        u.uid,
        LTRIM(RTRIM(
            ISNULL(NULLIF(u.ulname, ''), '')
            + CASE WHEN NULLIF(u.ufname, '') IS NOT NULL THEN ',' + u.ufname ELSE '' END
        )) AS prepName
    FROM mobiledoc.dbo.users u
)
SELECT
    '' AS medValue,
    CONVERT(varchar(20), t.ItemId) AS itemid,
    ISNULL(NULLIF(t.MedicineName, ''), ISNULL(i.itemName, '')) AS itemname,
    '' AS GenericName,
    ISNULL(t.ndc_code, '') AS NDC_Code,

    COALESCE(a.RxStrengthValue, d.StrengthValue, '') AS strengthvalue,
    CONVERT(varchar(20), COALESCE(a.RxStrengthId, d.StrengthID, 0)) AS strengthid,

    COALESCE(
        NULLIF(a.RxFormulationValue, ''),
        NULLIF(d.FormulationValue, ''),
        CASE WHEN LOWER(COALESCE(i.itemName, t.MedicineName, '')) LIKE '%tablet%' THEN 'Tablet' END,
        ''
    ) AS formulationvalue,
    CONVERT(varchar(20), COALESCE(
        NULLIF(a.RxFormulationId, 0),
        NULLIF(d.FormulationID, 0),
        CASE WHEN LOWER(COALESCE(i.itemName, t.MedicineName, '')) LIKE '%tablet%' THEN 10613 END,
        0
    )) AS formulationid,

    COALESCE(a.RxTakeValue, d.TakeValue, '') AS takevalue,
    CONVERT(varchar(20), COALESCE(a.RxTakeId, d.TakeID, 0)) AS takeid,

    COALESCE(a.RxRouteValue, d.RouteValue, '') AS routevalue,
    CONVERT(varchar(20), COALESCE(a.RxRouteId, d.RouteID, 0)) AS routeid,

    COALESCE(a.RxFrequencyValue, d.FrequencyValue, '') AS frequencyvalue,
    CONVERT(varchar(20), COALESCE(a.RxFrequencyId, d.FrequencyID, 0)) AS frequencyid,

    COALESCE(a.RxDurationValue, d.DurationValue, '') AS durationvalue,
    CONVERT(varchar(20), COALESCE(a.RxDurationId, d.DurationID, 0)) AS durationid,

    COALESCE(a.RxDispenseValue, d.DispenseValue, '') AS dispensevalue,
    CONVERT(varchar(20), COALESCE(a.RxDispenseId, d.DispenseID, 0)) AS dispenseid,

    COALESCE(a.RxRefillsValue, d.RefillsValue, CAST(t.Refill AS varchar(20)), '') AS refillsvalue,
    CONVERT(varchar(20), COALESCE(a.RxRefillsId, d.RefillsID, 0)) AS refillsid,

    ISNULL(t.rxNotes, '') AS notes,
    '' AS startDate,
    '' AS stopDate,
    ISNULL(CONVERT(varchar(10), t.StartDate, 101), '') AS StartDate,

    CASE
        WHEN t.DoctorsFlag = -1 AND t.PatientsFlag = 1 THEN 'Taking'
        WHEN t.DoctorsFlag = 1 AND t.PatientsFlag = -1 THEN 'Prescribed'
        ELSE ''
    END AS doctorsFlag,

    CONVERT(varchar(20), t.encounterId) AS encounterId,
    CONVERT(varchar(10), e.date, 101) AS EncounterDateOnly,
    t.RxOrderNo AS RxOrderNo,
    CONVERT(varchar(20), t.OldRxId) AS OldRxId,

    '' AS RxSource,
    0 AS RxSourceID,
    ISNULL(t.rxNotes, '') AS RxNotes,

    COALESCE(
        NULLIF(i.itemName, ''),
        NULLIF(t.MedicineName, '')
    ) + CASE
            WHEN COALESCE(a.RxStrengthValue, d.StrengthValue, '') <> ''
                THEN ' ' + LOWER(COALESCE(a.RxStrengthValue, d.StrengthValue, ''))
            ELSE ''
        END + CASE
            WHEN COALESCE(
                NULLIF(a.RxFormulationValue, ''),
                NULLIF(d.FormulationValue, ''),
                CASE WHEN LOWER(COALESCE(i.itemName, t.MedicineName, '')) LIKE '%tablet%' THEN 'tablet' END,
                ''
            ) <> ''
                THEN ' ' + LOWER(COALESCE(
                    NULLIF(a.RxFormulationValue, ''),
                    NULLIF(d.FormulationValue, ''),
                    CASE WHEN LOWER(COALESCE(i.itemName, t.MedicineName, '')) LIKE '%tablet%' THEN 'tablet' END,
                    ''
                ))
            ELSE ''
        END AS medName,

    ISNULL(doc_arh.docCodeInitials, ISNULL(doc_enc.docCodeInitials, '')) AS docCodeInitials,

    ISNULL(omai.AdditionalInstructions, '') AS sAdditionalInstructions,
    CASE WHEN ISNULL(omai.DAW, 0) = 0 THEN '' ELSE CONVERT(varchar(10), omai.DAW) END AS daw,

    CAST(0 AS bit) AS isCompound,
    '' AS compoundSignature,
    ISNULL(t.FillStatus, '') AS fillStatus,
    '' AS crsimages,

    CASE
        WHEN t.DoctorsFlag = -1 AND t.PatientsFlag = 1 THEN 'Taking'
        WHEN t.DoctorsFlag = 1 AND t.PatientsFlag = -1 THEN 'Prescribed'
        ELSE ''
    END AS doctorFlagValue,

    '' AS RxChannel,

    ISNULL(dx.DxNameOnly, '') AS DxNameOnly,
    CASE
        WHEN ISNULL(dx.DxCodeOnly, '') <> '' AND ISNULL(dx.DxNameOnly, '') <> ''
            THEN dx.DxCodeOnly + ' ' + dx.DxNameOnly
        ELSE ISNULL(dx.DxNameOnly, '')
    END AS DxName,
    ISNULL(dx.DxCodeOnly, '') AS DxCodeOnly,

    CONVERT(varchar(20), t.AssessId) AS assessmentId,
    CAST(CASE WHEN rs.rx_cnt > 1 THEN 1 ELSE 0 END AS bit) AS IsContinuedNextPage,
    '0' AS CSASchedule,

    COALESCE(
        NULLIF(i.itemName, ''),
        NULLIF(t.MedicineName, '')
    ) + CASE
            WHEN COALESCE(a.RxStrengthValue, d.StrengthValue, '') <> ''
                THEN ' ' + LOWER(COALESCE(a.RxStrengthValue, d.StrengthValue, ''))
            ELSE ''
        END + CASE
            WHEN COALESCE(
                NULLIF(a.RxFormulationValue, ''),
                NULLIF(d.FormulationValue, ''),
                CASE WHEN LOWER(COALESCE(i.itemName, t.MedicineName, '')) LIKE '%tablet%' THEN 'tablet' END,
                ''
            ) <> ''
                THEN ' ' + LOWER(COALESCE(
                    NULLIF(a.RxFormulationValue, ''),
                    NULLIF(d.FormulationValue, ''),
                    CASE WHEN LOWER(COALESCE(i.itemName, t.MedicineName, '')) LIKE '%tablet%' THEN 'tablet' END,
                    ''
                ))
            ELSE ''
        END AS completeRxName,

    '' AS stDtWo,

    CONVERT(varchar(10), e.date, 101) + ' ' +
    COALESCE(CONVERT(varchar(8), CAST(e.startTime AS time), 108), NULLIF(LEFT(e.time, 8), ''), '00:00:00') +
    CASE WHEN rs.rx_cnt > 1 THEN '  (continued..)' ELSE '' END AS medHeading,

    COALESCE(a.RxDurationValue, d.DurationValue, '') AS duration,

    '' AS AllChannelPharmacy,
    '' AS PharmacyName,

    CONVERT(varchar(10), e.date, 101) + ' ' +
    COALESCE(CONVERT(varchar(8), CAST(e.startTime AS time), 108), NULLIF(LEFT(e.time, 8), ''), '00:00:00') AS EncounterDate,

    '' AS TransactionTime,
    CAST(0 AS bit) AS hasAlert,
    ISNULL(CONVERT(varchar(10), t.LastTaken, 101), '') AS lastTaken,
    '' AS homemedstatus,

    CASE
        WHEN ISNULL(NULLIF(t.PreparedBy, ''), '') <> '' THEN 'Zz' + t.PreparedBy
        WHEN ISNULL(pu.prepName, '') <> '' THEN 'Zz' + pu.prepName
        ELSE ''
    END AS preparedBy,

    '' AS startDateWO,
    ISNULL(t.rxkop, '') AS rxKOP,
    ISNULL(t.rxDrugSource, '') AS rxDrugSource,
    ISNULL(t.disconorstopnotes, '') AS disconorstopnotes
FROM target_rx t
LEFT JOIN mobiledoc.dbo.items i
    ON i.itemID = t.ItemId
LEFT JOIN mobiledoc.dbo.enc e
    ON e.encounterID = t.encounterId
LEFT JOIN arh_pick a
    ON a.OldRxId = t.OldRxId
LEFT JOIN detail_pivot d
    ON d.OldRxId = t.OldRxId
LEFT JOIN dx_pick dx
    ON dx.OldRxId = t.OldRxId
LEFT JOIN rxorderno_stats rs
    ON rs.RxOrderNo = t.RxOrderNo
LEFT JOIN doc_user doc_enc
    ON doc_enc.uid = e.doctorID
LEFT JOIN doc_user doc_arh
    ON doc_arh.uid = a.arh_doctorId
LEFT JOIN prep_user pu
    ON pu.uid = t.PreparedById
LEFT JOIN mobiledoc.dbo.oldrxmain_addlinfo omai
    ON omai.OldRxId = t.OldRxId
   AND omai.Rxorderno = t.RxOrderNo;
