# Patient Data Catalog

> **Source:** EHR system patient record

---

## 1. Root-Level Fields

| Field                    | JSON Type       | Example                       | Notes                                                                               |
| ------------------------ | --------------- | ----------------------------- | ----------------------------------------------------------------------------------- |
| `accountNo`              | `integer`       | `278882`                      | Unique account number; typically matches `patientId`                                |
| `address1`               | `string`        | `"123 Main St Light Test 01"` | Primary street address                                                              |
| `birthDate`              | `string`        | `"07/12/1989"`                | Date of birth — format `MM/DD/YYYY`                                                 |
| `city`                   | `string`        | `"Mansfield"`                 | City of residence                                                                   |
| `country`                | `string`        | `"US"`                        | ISO 2-letter country code (e.g. `"US"`)                                             |
| `createdDate`            | `string`        | `"2026-03-09 08:12:01"`       | Record creation timestamp — format `YYYY-MM-DD HH:MM:SS`                            |
| `deceased`               | `string`        | `"0"`                         | Flag string — `"1"` = deceased, `"0"` = alive                                       |
| `email`                  | `string`        | `"jane.doe@gmail.com"`        | Patient email address                                                               |
| `ethnicity`              | `string`        | `"Declined to Specify"`       | Self-reported ethnicity (e.g. `"Declined to Specify"`)                              |
| `firstName`              | `string`        | `"Sai001"`                    | Patient first name                                                                  |
| `gender`                 | `string`        | `"female"`                    | Patient gender (e.g. `"female"`, `"male"`)                                          |
| `homePhone`              | `string`        | `"123-555-3340"`              | Home phone number — format `XXX-XXX-XXXX`                                           |
| `insurances`             | `array<object>` | `[{...}]`                     | List of insurance records — see [Section 2](#2-insurances-array)                    |
| `language`               | `string`        | `"Declined to Specify"`       | Preferred spoken language                                                           |
| `lastName`               | `string`        | `"ZZTest"`                    | Patient last name                                                                   |
| `needsTranslator`        | `integer`       | `1`                           | Flag integer — `1` = yes, `0` = no                                                  |
| `patientId`              | `integer`       | `278882`                      | Primary patient identifier                                                          |
| `preferences`            | `object`        | `{...}`                       | Communication and account preferences — see [Section 3](#3-preferences-object)      |
| `primaryCareProvider`    | `string`        | `"Patel MD, Jitesh, V"`       | Display name of the assigned PCP                                                    |
| `primaryServiceLocation` | `integer`       | `3`                           | ID of the primary service/clinic location                                           |
| `race`                   | `string`        | `"Declined to Specify"`       | Self-reported race (e.g. `"Declined to Specify"`)                                   |
| `referringProvider`      | `string`        | `"Need, Updated Information"` | Display name of the referring provider                                              |
| `relationToGuarantor`    | `integer`       | `1`                           | Relationship code to the guarantor (e.g. `1` = self)                                |
| `releaseOfInfo`          | `string`        | `"Y"`                         | Code string — `"Y"` = consent given, `"N"` = denied                                 |
| `renderingProvider`      | `string`        | `"Need, Updated Information"` | Display name of the rendering provider                                              |
| `responsibleParty`       | `object`        | `{...}`                       | Guarantor / responsible party details — see [Section 4](#4-responsibleparty-object) |
| `rxHistoryConsent`       | `string`        | `"U"`                         | Code string — `"U"` = unknown, `"Y"` = yes, `"N"` = no                              |
| `selfPay`                | `string`        | `"0"`                         | Flag string — `"1"` = self-pay patient, `"0"` = insured                             |
| `state`                  | `string`        | `"MA"`                        | 2-letter US state code (e.g. `"MA"`)                                                |
| `status`                 | `string`        | `"0"`                         | Flag string — `"0"` = active, `"1"` = inactive                                      |
| `transgender`            | `string`        | `"N"`                         | Code string — `"Y"` = yes, `"N"` = no                                               |
| `zip`                    | `integer`       | `12345`                       | 5-digit ZIP code                                                                    |

---

## 2. `insurances[]` Array

Each element represents one insurance policy attached to the patient.

| Field                 | JSON Type | Example                     | Notes                                                    |
| --------------------- | --------- | --------------------------- | -------------------------------------------------------- |
| `id`                  | `integer` | `511`                       | Unique insurance record ID                               |
| `ptInsId`             | `integer` | `328022`                    | Patient-insurance link ID                                |
| `seqNo`               | `integer` | `1`                         | Sequence / priority order                                |
| `insOrder`            | `string`  | `""`                        | Order label (can be empty)                               |
| `insType`             | `string`  | `"Primary"`                 | Coverage tier — `"Primary"`, `"Secondary"`, `"Tertiary"` |
| `name`                | `string`  | `"Self Pay - No Insurance"` | Insurance plan display name                              |
| `active`              | `string`  | `"I"`                       | Code string — `"A"` = active, `"I"` = inactive           |
| `stDate`              | `string`  | `"2024-03-08"`              | Coverage start date — format `YYYY-MM-DD`                |
| `endDate`             | `string`  | `"2024-12-31"`              | Coverage end date — format `YYYY-MM-DD`                  |
| `eligibilityStatus`   | `string`  | `"V"`                       | Code string — `"V"` = verified, `"U"` = unverified       |
| `copays`              | `integer` | `20`                        | Copay amount                                             |
| `copayType`           | `string`  | `"$"`                       | Code string — `"$"` = flat dollar, `"%"` = percentage    |
| `enableMultipleCoPay` | `string`  | `""`                        | Flag string — enables multiple copay rules               |
| `feeScheduleId`       | `integer` | `3`                         | ID of the associated fee schedule                        |
| `feeScheduleName`     | `string`  | `"4. Selfpay"`              | Display name of the fee schedule                         |
| `groupNumber`         | `integer` | `67890`                     | Insurance group number                                   |
| `subscriberNumber`    | `integer` | `12344`                     | Subscriber / member ID number                            |
| `guarantorId`         | `integer` | `278882`                    | ID of the guarantor tied to this insurance               |
| `guarantorName`       | `string`  | `"ZZTest, Sai001"`          | Display name of the guarantor                            |
| `guarantorRelation`   | `integer` | `1`                         | Relationship code — `1` = self                           |
| `isGuarantorPatient`  | `integer` | `1`                         | Flag integer — `1` = guarantor is the patient            |
| `city`                | `string`  | `""`                        | Insurance holder city (can be empty)                     |
| `state`               | `string`  | `""`                        | Insurance holder state (can be empty)                    |

---

## 3. `preferences` Object

Nested object containing four sub-sections.

---

### 3a. `preferences.patient`

Core patient-level account flags.

| Field           | JSON Type | Example                 | Notes                                                     |
| --------------- | --------- | ----------------------- | --------------------------------------------------------- |
| `id`            | `string`  | `"278882"`              | Patient ID (string form)                                  |
| `language`      | `string`  | `"Declined to Specify"` | Preferred language                                        |
| `lognotes`      | `string`  | `"sample notes 10"`     | Free-text log / admin notes                               |
| `employerphone` | `string`  | `""`                    | Employer phone number (can be empty)                      |
| `enableletters` | `string`  | `"1"`                   | Flag string — `"1"` = paper letters enabled               |
| `isptoptsout`   | `string`  | `"0"`                   | Flag string — `"1"` = patient opted out of communications |
| `optout`        | `string`  | `"0"`                   | Flag string — `"1"` = opted out                           |
| `optreasonid`   | `string`  | `"0"`                   | ID of the opt-out reason (`"0"` = no reason)              |
| `textenabled`   | `string`  | `"1"`                   | Flag string — `"1"` = SMS messaging enabled               |
| `voiceenabled`  | `string`  | `"1"`                   | Flag string — `"1"` = voice/phone messaging enabled       |

---

### 3b. `preferences.textconfig`

SMS / text notification configuration.

| Field                 | JSON Type | Example                 | Notes                                                            |
| --------------------- | --------- | ----------------------- | ---------------------------------------------------------------- |
| `id`                  | `string`  | `"151383"`              | Text config record ID                                            |
| `uid`                 | `string`  | `"278882"`              | Patient user ID                                                  |
| `language`            | `string`  | `"Es"`                  | 2-letter language code (e.g. `"Es"` = Spanish, `"En"` = English) |
| `contacttype`         | `string`  | `"home"`                | Preferred contact method (e.g. `"home"`, `"mobile"`)             |
| `datemodified`        | `string`  | `"2026-03-10 03:15:51"` | Last modified timestamp — format `YYYY-MM-DD HH:MM:SS`           |
| `timetocall`          | `string`  | `"Evening"`             | Preferred time window — `"Morning"`, `"Afternoon"`, `"Evening"`  |
| `appointments`        | `string`  | `"1"`                   | Flag string — `"1"` = receive appointment text reminders         |
| `generalnotification` | `string`  | `"1"`                   | Flag string — `"1"` = receive general notifications              |
| `healthmaintenance`   | `string`  | `"1"`                   | Flag string — `"1"` = receive health maintenance reminders       |
| `labs`                | `string`  | `"0"`                   | Flag string — `"1"` = receive lab result notifications           |
| `primeplus`           | `string`  | `"1"`                   | Flag string — `"1"` = enrolled in PrimePlus messaging            |
| `ptstatements`        | `string`  | `"0"`                   | Flag string — `"1"` = receive billing statement texts            |
| `rx`                  | `string`  | `"1"`                   | Flag string — `"1"` = receive prescription notifications         |

---

### 3c. `preferences.voiceconfig`

Voice / phone call notification configuration.

| Field                 | JSON Type | Example                 | Notes                                                           |
| --------------------- | --------- | ----------------------- | --------------------------------------------------------------- |
| `id`                  | `string`  | `"175939"`              | Voice config record ID                                          |
| `uid`                 | `string`  | `"278882"`              | Patient user ID                                                 |
| `language`            | `string`  | `"English"`             | Preferred language for voice calls (e.g. `"English"`)           |
| `contacttype`         | `string`  | `"home"`                | Preferred contact method (e.g. `"home"`, `"mobile"`)            |
| `datemodified`        | `string`  | `"2026-03-10 03:15:51"` | Last modified timestamp — format `YYYY-MM-DD HH:MM:SS`          |
| `timetocall`          | `string`  | `"Afternoon"`           | Preferred time window — `"Morning"`, `"Afternoon"`, `"Evening"` |
| `prefcomm`            | `string`  | `"voice"`               | Preferred communication channel (e.g. `"voice"`)                |
| `appointments`        | `string`  | `"1"`                   | Flag string — `"1"` = receive appointment voice reminders       |
| `generalnotification` | `string`  | `"1"`                   | Flag string — `"1"` = receive general voice notifications       |
| `healthmaintenance`   | `string`  | `"1"`                   | Flag string — `"1"` = receive health maintenance voice calls    |
| `labs`                | `string`  | `"0"`                   | Flag string — `"1"` = receive lab result voice calls            |
| `primeplus`           | `string`  | `"1"`                   | Flag string — `"1"` = enrolled in PrimePlus voice               |
| `ptstatements`        | `string`  | `"0"`                   | Flag string — `"1"` = receive billing statement voice calls     |
| `rx`                  | `string`  | `"1"`                   | Flag string — `"1"` = receive prescription voice calls          |

---

### 3d. `preferences.user`

Portal / web account profile mirroring core patient demographics.

| Field        | JSON Type | Example                       | Notes                                           |
| ------------ | --------- | ----------------------------- | ----------------------------------------------- |
| `id`         | `string`  | `"278882"`                    | User account ID                                 |
| `dob`        | `string`  | `"07/12/1989"`                | Date of birth — format `MM/DD/YYYY`             |
| `sex`        | `string`  | `"female"`                    | Sex on record (e.g. `"female"`, `"male"`)       |
| `ufname`     | `string`  | `"Sai001"`                    | User first name                                 |
| `ulname`     | `string`  | `"ZZTest"`                    | User last name                                  |
| `uname`      | `string`  | `"jane.doe@gmail.com"`        | Username (typically the email address)          |
| `uemail`     | `string`  | `"jane.doe@gmail.com"`        | User email address                              |
| `umobileno`  | `string`  | `""`                          | Mobile phone number (can be empty)              |
| `upaddress`  | `string`  | `"123 Main St Light Test 01"` | User portal address                             |
| `upcity`     | `string`  | `"Mansfield"`                 | User portal city                                |
| `upstate`    | `string`  | `"MA"`                        | 2-letter US state code                          |
| `upphone`    | `string`  | `"123-555-3340"`              | User portal phone number                        |
| `webenabled` | `string`  | `"1"`                         | Flag string — `"1"` = portal web access enabled |
| `zipcode`    | `string`  | `"12345"`                     | ZIP code (string form)                          |

---

### 3e. `preferences.contacttypeoptions`

| Field                | JSON Type | Example | Notes                                                |
| -------------------- | --------- | ------- | ---------------------------------------------------- |
| `contacttypeoptions` | `array`   | `[]`    | List of available contact type options; can be empty |

---

## 4. `responsibleParty` Object

The guarantor — the person financially responsible for the patient's account.

| Field                | JSON Type | Example            | Notes                                                                            |
| -------------------- | --------- | ------------------ | -------------------------------------------------------------------------------- |
| `guarantorId`        | `integer` | `278882`           | Unique guarantor ID; matches `patientId` when the patient is their own guarantor |
| `guarantorName`      | `string`  | `"ZZTest, Sai001"` | Display name of the guarantor                                                    |
| `guarantorPhone`     | `string`  | `"123-555-3340"`   | Guarantor phone number — format `XXX-XXX-XXXX`                                   |
| `guarantorRelation`  | `integer` | `1`                | Relationship code — `1` = self                                                   |
| `isGuarantorPatient` | `integer` | `1`                | Flag integer — `1` = guarantor and patient are the same person                   |

---

## Quick-Reference: Flag Conventions

| Pattern                | Description                                                         |
| ---------------------- | ------------------------------------------------------------------- |
| `integer` `0` / `1`    | Numeric boolean flag (e.g. `needsTranslator`, `isGuarantorPatient`) |
| `string` `"0"` / `"1"` | String-encoded boolean flag (common inside `preferences.*`)         |
| `"Y"` / `"N"`          | Yes/No code string (e.g. `releaseOfInfo`, `transgender`)            |
| `"A"` / `"I"`          | Active / Inactive status code (e.g. `insurances[].active`)          |
| `"V"` / `"U"`          | Verified / Unverified eligibility code                              |
