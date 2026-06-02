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
        orm.disconorstopnotes,
        orm.rxSource,
        orm.rxSourceId,
        orm.StopDate
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
        -- Formulation: primary arh pick first; fall back to any arh row that has one recorded
        ISNULL(NULLIF(a.RxFormulationId, 0),         af.RxFormulationId)      AS RxFormulationId,
        ISNULL(NULLIF(a.RxFormulationValue, ''), af.RxFormulationValue)        AS RxFormulationValue
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
    -- Fallback: best arh row that actually has a formulation (handles records where the
    -- assessment-matched row is missing formulation but another arh row for the same Rx has it)
    OUTER APPLY (
        SELECT TOP 1 arh.RxFormulationId, arh.RxFormulationValue
        FROM mobiledoc.dbo.assessment_rx_history arh
        WHERE arh.OldRxId = t.OldRxId
          AND ISNULL(arh.delFlag, 0) = 0
          AND ISNULL(arh.RxFormulationId, 0) != 0
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
    ) af
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
        -- edi_dfr_cptdiagnosismap.diagnosisCode is the billing-verified ICD-10 path
        -- items.vmid stores the external identifier (ICD code for diagnosis items)
        -- icd.Code stores internal ECW GUIDs, NOT human-readable ICD-10 codes
        -- items.keyName stores the PARENT category name (e.g. "Assessments"), not the code
        COALESCE(md.code, md_by_name.code, NULLIF(dfr.diagnosisCode, ''), NULLIF(it.vmid, ''), '') AS DxCodeOnly
    FROM target_rx t
    OUTER APPLY (
        SELECT TOP 1 d.ItemId
        FROM mobiledoc.dbo.diagnosis d
        WHERE d.EncounterId = t.encounterId
        ORDER BY ISNULL(d.displayIndex, 9999), d.SlNo
    ) d1
    LEFT JOIN mobiledoc.dbo.items it
        ON it.itemID = d1.ItemId
    OUTER APPLY (
        SELECT TOP 1 dfr.diagnosisCode
        FROM mobiledoc.dbo.edi_dfr_cptdiagnosismap dfr
        WHERE dfr.encounterId = t.encounterId
          AND dfr.diagnosisItemId = d1.ItemId
          AND ISNULL(dfr.deleteFlag, 0) = 0
          AND NULLIF(dfr.diagnosisCode, '') IS NOT NULL
        ORDER BY dfr.Id DESC
    ) dfr
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
    NULL AS medValue,
    CONVERT(varchar(20), t.ItemId) AS itemid,
    ISNULL(NULLIF(t.MedicineName, ''), ISNULL(i.itemName, '')) AS itemname,
    NULL AS GenericName,
    ISNULL(t.ndc_code, '') AS NDC_Code,

    COALESCE(a.RxStrengthValue, d.StrengthValue, '') AS strengthvalue,
    CONVERT(varchar(20), COALESCE(a.RxStrengthId, d.StrengthID, 0)) AS strengthid,

    COALESCE(
        NULLIF(a.RxFormulationValue, ''),
        NULLIF(d.FormulationValue, ''),
        CASE WHEN LOWER(COALESCE(i.itemName, i.itemDesc, t.MedicineName, '')) LIKE '%tablet%' THEN 'Tablet' END,
        ''
    ) AS formulationvalue,
    CONVERT(varchar(20), COALESCE(
        NULLIF(a.RxFormulationId, 0),
        NULLIF(d.FormulationID, 0),
        CASE WHEN LOWER(COALESCE(i.itemName, i.itemDesc, t.MedicineName, '')) LIKE '%tablet%' THEN 10613 END,
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
    ISNULL(CONVERT(varchar(10), t.StartDate, 101), '') AS startDate,
    ISNULL(CONVERT(varchar(10), t.StopDate, 101), '') AS stopDate,
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

    ISNULL(t.rxSource, '') AS RxSource,
    ISNULL(t.rxSourceId, 0) AS RxSourceID,
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
                CASE WHEN LOWER(COALESCE(i.itemName, i.itemDesc, t.MedicineName, '')) LIKE '%tablet%' THEN 'tablet' END,
                ''
            ) <> ''
                THEN ' ' + LOWER(COALESCE(
                    NULLIF(a.RxFormulationValue, ''),
                    NULLIF(d.FormulationValue, ''),
                    CASE WHEN LOWER(COALESCE(i.itemName, i.itemDesc, t.MedicineName, '')) LIKE '%tablet%' THEN 'tablet' END,
                    ''
                ))
            ELSE ''
        END AS medName,

    -- documentedUserId on oldrxmain_addlinfo = doctor who signed/prescribed the Rx
    -- arh.doctorId and enc.doctorID as fallbacks (both may resolve to a different doctor)
    ISNULL(doc_omai.docCodeInitials, ISNULL(doc_arh.docCodeInitials, ISNULL(doc_enc.docCodeInitials, ''))) AS docCodeInitials,

    ISNULL(omai.AdditionalInstructions, '') AS sAdditionalInstructions,
    CASE WHEN ISNULL(omai.DAW, 0) = 0 THEN '' ELSE CONVERT(varchar(10), omai.DAW) END AS daw,

    CAST(0 AS bit) AS isCompound,
    NULL AS compoundSignature,
    ISNULL(t.FillStatus, '') AS fillStatus,
    NULL AS crsimages,

    CASE
        WHEN t.DoctorsFlag = -1 AND t.PatientsFlag = 1 THEN 'Taking'
        WHEN t.DoctorsFlag = 1 AND t.PatientsFlag = -1 THEN 'Prescribed'
        ELSE ''
    END AS doctorFlagValue,

    ISNULL(rxlog.RxChannel, '') AS RxChannel,

    ISNULL(dx.DxNameOnly, '') AS DxNameOnly,
    CASE
        WHEN ISNULL(dx.DxCodeOnly, '') <> '' AND ISNULL(dx.DxNameOnly, '') <> ''
            THEN dx.DxCodeOnly + ' ' + dx.DxNameOnly
        ELSE ISNULL(dx.DxNameOnly, '')
    END AS DxName,
    ISNULL(dx.DxCodeOnly, '') AS DxCodeOnly,

    CONVERT(varchar(20), t.AssessId) AS assessmentId,
    CAST(CASE WHEN rs.rx_cnt > 1 THEN 1 ELSE 0 END AS bit) AS IsContinuedNextPage,
    ISNULL(rxlog.CSASchedule, '') AS CSASchedule,

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
                CASE WHEN LOWER(COALESCE(i.itemName, i.itemDesc, t.MedicineName, '')) LIKE '%tablet%' THEN 'tablet' END,
                ''
            ) <> ''
                THEN ' ' + LOWER(COALESCE(
                    NULLIF(a.RxFormulationValue, ''),
                    NULLIF(d.FormulationValue, ''),
                    CASE WHEN LOWER(COALESCE(i.itemName, i.itemDesc, t.MedicineName, '')) LIKE '%tablet%' THEN 'tablet' END,
                    ''
                ))
            ELSE ''
        END AS completeRxName,

    NULL AS stDtWo,

    CONVERT(varchar(10), e.date, 101) + ' ' +
    COALESCE(CONVERT(varchar(8), CAST(e.startTime AS time), 108), NULLIF(LEFT(e.time, 8), ''), '00:00:00') +
    CASE WHEN rs.rx_cnt > 1 THEN '  (continued..)' ELSE '' END AS medHeading,

    COALESCE(a.RxDurationValue, d.DurationValue, '') AS duration,

    NULL AS AllChannelPharmacy,
    ISNULL(NULLIF(ph.pharmacyname, ''), ISNULL(rxlog.PharmacyName, '')) AS PharmacyName,

    CONVERT(varchar(10), e.date, 101) + ' ' +
    COALESCE(CONVERT(varchar(8), CAST(e.startTime AS time), 108), NULLIF(LEFT(e.time, 8), ''), '00:00:00') AS EncounterDate,

    ISNULL(rxlog.TransactionTime, '') AS TransactionTime,
    CAST(0 AS bit) AS hasAlert,
    ISNULL(CONVERT(varchar(10), t.LastTaken, 101), '') AS lastTaken,
    NULL AS homemedstatus,

    CASE
        WHEN ISNULL(NULLIF(t.PreparedBy, ''), '') <> '' THEN 'Zz' + t.PreparedBy
        WHEN ISNULL(pu.prepName, '') <> '' THEN 'Zz' + pu.prepName
        ELSE ''
    END AS preparedBy,

    NULL AS startDateWO,
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
   AND omai.Rxorderno = t.RxOrderNo
LEFT JOIN mobiledoc.dbo.pharmacy ph
    ON  ph.pmcid               = omai.PharmacyId
    AND ISNULL(ph.delFlag, 0)  = 0
OUTER APPLY (
    SELECT TOP 1
        rsl.RxChannel,
        rsl.CSASchedule,
        rsl.TransactionTime,
        rsl.PharmacyName
    FROM mobiledoc.dbo.rxhub_scriptlog rsl
    WHERE rsl.EncounterId = t.encounterId
      AND rsl.ItemId      = t.ItemId
    ORDER BY rsl.ID DESC
) rxlog
LEFT JOIN doc_user doc_omai
    ON doc_omai.uid = omai.documentedUserId;
