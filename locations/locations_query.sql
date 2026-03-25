SELECT
    Id AS id,
    Name AS name,
    
    -- Address (combine line1 + line2 safely)
    LTRIM(RTRIM(
        ISNULL(AddressLine1, '') + 
        CASE 
            WHEN AddressLine2 IS NOT NULL AND AddressLine2 <> '' 
            THEN ' ' + AddressLine2 
            ELSE '' 
        END
    )) AS address,

    City AS city,
    State AS state,
    Zip AS zip,
    POS AS pos

FROM mobiledoc.dbo.edi_facilities
WHERE DeleteFlag = 0  
ORDER BY Name;