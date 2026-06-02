
SELECT
    d.doctorID AS id,
    CASE 
        WHEN u.ulname IS NOT NULL AND u.ufname IS NOT NULL AND u.uminitial IS NOT NULL AND u.uminitial <> ''
        THEN CONCAT(LTRIM(RTRIM(u.ulname)), ',', LTRIM(RTRIM(u.ufname)), ' ', LTRIM(RTRIM(u.uminitial)))
        WHEN u.ulname IS NOT NULL AND u.ufname IS NOT NULL 
        THEN CONCAT(LTRIM(RTRIM(u.ulname)), ',', LTRIM(RTRIM(u.ufname)))
        WHEN u.ulname IS NOT NULL 
        THEN LTRIM(RTRIM(u.ulname))
        ELSE ISNULL(d.PrintName, '')
    END AS fullname,
    ISNULL(u.sex, '') AS sex,
    ISNULL(u.LANGUAGE, '') AS languages,
    ISNULL(d.providerCode, '') AS providerCode,
    ISNULL(d.inactive, 0) AS inactive,
    ISNULL(d.providerStatus, 0) AS status,
    ISNULL(u.uname, '') AS userName,
    -- Fixed: Changed from doctors.FacilityId to users.primaryservicelocation
    ISNULL(u.primaryservicelocation, 0) AS primarylocation,
    ISNULL(d.PrintName, '') AS dbprintname,
    NULL AS timezone,
    CAST(d.NPI AS BIGINT) AS NPI,
    ISNULL(d.regp2pnpi, 0) AS P2PNPI,
    -- Fixed: Try suffix field first, then degreeCredentials
    ISNULL(NULLIF(u.suffix, ''), ISNULL(u.degreeCredentials, '')) AS Credentials,
    ISNULL(d.speciality, '') AS Specialty
FROM 
    mobiledoc.dbo.doctors AS d
    LEFT JOIN mobiledoc.dbo.users AS u ON d.doctorID = u.uid
WHERE 
    d.PrintName IS NOT NULL
    AND d.PrintName <> ''
    AND d.providerCode IS NOT NULL
    AND d.providerCode <> ''
    AND ISNULL(d.inactive, 0) = 0
    AND (u.delFlag IS NULL OR u.delFlag = 0);
   