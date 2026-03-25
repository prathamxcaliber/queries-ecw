SELECT
    Id AS id,
    pid AS patientId,
    insid AS insuranceId,
    AssignBenefits AS assignBenefits,
    CAST(CAST(copays AS DECIMAL(10,2)) AS INT) AS coPay,
    copayType,
    RTRIM(EncEligibilityStatus) AS encEligibilityStatus,
    CONVERT(varchar(10), endDate, 101) AS endDate,
    groupName,
    CAST(groupNo AS INT) AS groupNo,
    GrId AS guarantorId,
    GrRel AS guarantorRelation,
    InsType AS insType,
    InsuranceClass AS insuranceClass,
    IsGrPt AS isGuarantorPatient,
    PaymentSource AS paymentSource,
    PtSigSource AS ptSigSource,
    SeqNo AS seqNo,
    CONVERT(varchar(10), startDate, 101) AS startDate,
    CAST(subscriberNo AS INT) AS subscriberNo
FROM mobiledoc.dbo.insurancedetail
WHERE Id = 327968;