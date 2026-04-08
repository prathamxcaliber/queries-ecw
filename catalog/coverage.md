# Coverage Data Catalog

> **Source:** EHR system coverage/insurance detail record  

---

## 1. `InsuranceDetail` Object

| Field | JSON Type | Example | Notes |
|---|---|---|---|
| `id` | `integer` | `327968` | Unique patient-insurance record ID (`ptInsId`) |
| `patientId` | `integer` | `275734` | ID of the patient this coverage belongs to |
| `insuranceId` | `integer` | `894` | ID of the insurance plan/carrier master record |
| `insType` | `string` | `"C1"` | Coverage type code (e.g. `"C1"` = primary commercial, `"M"` = Medicare) |
| `insuranceClass` | `string` | `"MSUP"` | Insurance class code (e.g. `"MSUP"` = Medicare Supplement) |
| `seqNo` | `integer` | `1` | Sequence / priority order — `1` = primary, `2` = secondary, etc. |
| `startDate` | `string` | `"02/01/2026"` | Coverage start date — format `MM/DD/YYYY` |
| `endDate` | `string` | `"02/28/2026"` | Coverage end date — format `MM/DD/YYYY` |
| `groupNo` | `integer` | `54321` | Insurance group number |
| `groupName` | `string` | `"Group Number"` | Display label for the group number |
| `subscriberNo` | `integer` | `123456` | Subscriber / member ID number |
| `coPay` | `integer` | `99` | Copay amount |
| `copayType` | `string` | `"$"` | Code string — `"$"` = flat dollar amount, `"%"` = percentage |
| `paymentSource` | `string` | `"CI"` | Code string — payment source (e.g. `"CI"` = commercial insurance) |
| `assignBenefits` | `string` | `"Y"` | Flag string — `"Y"` = benefits assigned to provider, `"N"` = not assigned |
| `encEligibilityStatus` | `string` | `"V"` | Code string — `"V"` = verified, `"U"` = unverified, `"I"` = inactive |
| `ptSigSource` | `string` | `"B"` | Code string — patient signature source (e.g. `"B"` = on file) |
| `guarantorId` | `integer` | `275734` | ID of the guarantor for this coverage; matches `patientId` when self |
| `guarantorRelation` | `integer` | `1` | Relationship code — `1` = self |
| `isGuarantorPatient` | `integer` | `1` | Flag integer — `1` = guarantor and patient are the same person |

---

## Quick-Reference: Code Conventions

| Value | Field | Meaning |
|---|---|---|
| `"Y"` / `"N"` | `assignBenefits` | Benefits assigned to provider / not assigned |
| `"V"` / `"U"` / `"I"` | `encEligibilityStatus` | Verified / Unverified / Inactive eligibility |
| `"$"` / `"%"` | `copayType` | Flat dollar copay / percentage copay |
| `"CI"` | `paymentSource` | Commercial insurance |
| `"B"` | `ptSigSource` | Patient signature on file |
| `1` | `guarantorRelation` | Guarantor is self (same as patient) |
| `1` | `isGuarantorPatient` | Guarantor equals patient (flag integer) |
