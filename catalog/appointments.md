# Appointments Data Catalog

> **Source:** EHR system appointment/encounter record  
> **Purpose:** Knowledge base for AI agents — describes all fields returned inside the `encdata` object of an appointment payload.  
> **Note:** "Flag integer" = `0` / `1` numeric boolean. "Code string" = short, controlled-vocabulary string.

---

## 1. Root-Level Fields

| Field | JSON Type | Example | Notes |
|---|---|---|---|
| `encId` | `string` | `"3256292"` | Encounter ID (string form) — matches `encdata.encounterId` |
| `encdata` | `object` | `{...}` | Full encounter/appointment detail — see [Section 2](#2-encdata-object) |

---

## 2. `encdata` Object

| Field | JSON Type | Example | Notes |
|---|---|---|---|
| `encounterId` | `integer` | `3256292` | Unique encounter/appointment ID |
| `ControlNo` | `integer` | `278722` | Control number — typically matches `patientId` |
| `patientId` | `integer` | `278722` | ID of the patient for this appointment |
| `practiceId` | `integer` | `1` | ID of the practice |
| `doctorid` | `integer` | `122` | ID of the attending doctor/provider |
| `ResourceId` | `integer` | `122` | Scheduling resource ID — typically the provider ID |
| `facilityId` | `integer` | `3` | ID of the facility/location |
| `facilityName` | `string` | `"Advanced Urology Institute"` | Display name of the facility |
| `facilityCode` | `string` | `"JPO"` | Short code for the facility |
| `POS` | `integer` | `11` | Place of Service code (CMS standard — e.g. `11` = office) |
| `date` | `string` | `"2026-11-02"` | Appointment date — format `YYYY-MM-DD` |
| `time` | `string` | `"08:00:00"` | Appointment start time — format `HH:MM:SS` |
| `endTime` | `string` | `"08:30:00"` | Appointment end time — format `HH:MM:SS` |
| `arrivedTime` | `string` | `"1900-01-01"` | Patient arrival timestamp; sentinel value `"1900-01-01"` = not yet arrived |
| `depTime` | `string` | `"1900-01-01"` | Patient departure timestamp; sentinel value `"1900-01-01"` = not yet departed |
| `waitTime` | `string` | `"1901-01-01"` | Wait time; sentinel value `"1901-01-01"` = not recorded |
| `status` | `string` | `"PEN"` | Appointment status code — e.g. `"PEN"` = pending, `"ARR"` = arrived, `"CAN"` = cancelled |
| `encType` | `integer` | `1` | Encounter type code — `1` = office visit |
| `visitType` | `string` | `"NP"` | Visit type code — e.g. `"NP"` = new patient, `"FU"` = follow-up |
| `visitTypeDetails` | `string` | `"New Patient"` | Display label for the visit type |
| `reason` | `string` | `"Adrenal Mass"` | Patient-reported reason for visit |
| `Dx` | `string` | `"Adrenal Mass"` | Diagnosis / chief complaint |
| `name` | `string` | `"Acumen II, Test123456, M"` | Patient display name — format `LastName, FirstName, Sex` |
| `sex` | `string` | `"Male"` | Patient sex |
| `dob` | `string` | `"02/01/1990"` | Patient date of birth — format `MM/DD/YYYY` |
| `cellphoneNo` | `string` | `"555-987-8977"` | Patient cell phone number |
| `upPhone` | `string` | `"855-122-4567"` | Patient portal/primary phone number |
| `empPhone` | `string` | `"221-233-1233"` | Patient employer phone number |
| `uemail` | `string` | `"testemailing123@example.com"` | Patient email address |
| `selfPay` | `integer` | `1` | Flag integer — `1` = self-pay, `0` = insured |
| `ClaimReq` | `integer` | `1` | Flag integer — `1` = claim required, `0` = not required |
| `generalNotes` | `string` | `"automated update via RPA for generalNotes"` | General clinical/admin notes for the encounter |
| `notes` | `string` | `"automated update via RPA for generalNotes"` | Additional encounter notes (may mirror `generalNotes`) |
| `billing` | `string` | `"update appointment notes 243 5462"` | Billing-related notes |

---

## Quick-Reference: Code Conventions

| Value | Field | Meaning |
|---|---|---|
| `"PEN"` | `status` | Appointment is pending |
| `"ARR"` | `status` | Patient has arrived |
| `"CAN"` | `status` | Appointment cancelled |
| `"NP"` | `visitType` | New patient visit |
| `"FU"` | `visitType` | Follow-up visit |
| `11` | `POS` / `encType` | Place of Service 11 = office |
| `"1900-01-01"` | `arrivedTime`, `depTime` | Sentinel — event has not occurred yet |
| `"1901-01-01"` | `waitTime` | Sentinel — wait time not recorded |
| `1` | `selfPay` | Patient is self-pay (no insurance) |
| `1` | `ClaimReq` | A claim must be submitted for this encounter |
