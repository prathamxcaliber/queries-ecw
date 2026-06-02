-- Extended ECW Appointments Query
-- Returns all 34 fields matching the EHR API payload

SELECT
    -- Basic encounter fields (from enc table)
    e.encounterID AS encounterId,
    CONVERT(varchar(8), CAST(e.startTime AS time), 108) AS time,
    CONVERT(varchar(8), CAST(e.endTime AS time), 108) AS endTime,
    CONVERT(varchar(10), e.date, 23) AS date,
    e.STATUS AS status,
    
    -- Patient identification
    e.patientID AS patientId,
    p.ControlNo,
    
    -- Patient demographics (from users table)
    CONCAT(
        u.ulname,
        CASE WHEN u.suffix IS NOT NULL AND u.suffix != '' 
             THEN ' ' + u.suffix 
             ELSE '' 
        END,
        ', ', 
        u.ufname, 
        ', ', 
        ISNULL(u.uminitial, '')
    ) AS name,
    CONVERT(varchar(10), CAST(u.dob AS datetime), 101) AS dob,
    u.sex,
    
    -- Contact information (from users table)
    u.umobileno AS cellphoneNo,
    u.upPhone,
    u.uemail,
    p.employerPhone AS empPhone,
    
    -- Appointment details
    e.reason,
    e.VisitType AS visitType,
    CASE 
        WHEN e.VisitType = 'NP' THEN 'New Patient'
        WHEN e.VisitType = 'EP' THEN 'Established Patient'
        WHEN e.VisitType = 'FU' THEN 'Follow Up'
        WHEN e.VisitType = 'CON' THEN 'Consultation'
        ELSE e.VisitType
    END AS visitTypeDetails,
    CASE 
        WHEN e.Notes IS NULL OR CAST(e.Notes AS varchar(MAX)) = '' 
        THEN e.generalNotes 
        ELSE CAST(e.Notes AS varchar(MAX))
    END AS notes,
    e.generalNotes,
    ISNULL(eb.claimnote, '') AS billing,  -- Billing notes from enc_billingdata table
    
    -- Facility and practice information
    e.facilityId,
    ISNULL(ef.Name, '') AS facilityName,
    NULL AS facilityCode,  -- Note: No facility code field found in edi_facilities
    e.practiceId,
    
    -- Clinical information
    e.Dx,
    e.POS,
    e.encType,
    e.doctorID AS doctorid,
    e.ResourceId,
    
    -- Financial information
    e.ClaimReq,
    p.SelfPay AS selfPay,
    
    -- Timing information
    CONVERT(varchar(10), e.waitTime, 23) AS waitTime,
    CONVERT(varchar(10), e.arrivedTime, 23) AS arrivedTime,
    CONVERT(varchar(10), e.depTime, 23) AS depTime
    
FROM mobiledoc.dbo.enc e
    LEFT JOIN mobiledoc.dbo.patients p ON p.pid = e.patientID
    LEFT JOIN mobiledoc.dbo.users u ON u.uid = e.patientID
    LEFT JOIN mobiledoc.dbo.edi_facilities ef ON ef.Id = e.facilityId AND ef.DeleteFlag = 0
    LEFT JOIN mobiledoc.dbo.enc_billingdata eb ON eb.encounterid = e.encounterID
WHERE e.encounterID = 3256292;