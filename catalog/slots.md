# ECW Slot Data Catalog

> **Source:** ECW EHR scheduling API — encounters and workhours  
> **Purpose:** Knowledge base for AI agents — describes all fields returned in scheduling slot and work-hour payloads.  
> **Note:** "Flag string" = a string holding `"Y"/"N"` as a boolean equivalent. Sentinel dates (e.g. `"1900-01-01"`) indicate the event has not yet occurred.

---

## 1. `Encounter` (booked / open appointment slot)

| Field          | JSON Type       | Example                     | Notes                                               |
| -------------- | --------------- | --------------------------- | --------------------------------------------------- |
| `encounterId`  | `string`        | `"ENC-12345"`               | Unique encounter ID from ECW                        |
| `id`           | `string`        | `"12345"`                   | Alternate encounter identifier                      |
| `patId`        | `string`        | `"275734"`                  | Patient ID — present only for booked slots          |
| `patName`      | `string`        | `"Smith, John"`             | Patient display name                                |
| `doctorId`     | `string`        | `"42"`                      | Provider/doctor ID                                  |
| `doctorName`   | `string`        | `"Dr. Jane Doe"`            | Provider display name                               |
| `facilityId`   | `string`        | `"10"`                      | Facility/department ID — `"0"` or empty = invalid   |
| `facilityName` | `string`        | `"Main Clinic"`             | Facility display name — empty string = invalid      |
| `start`        | `string`        | `"2026-04-08 09:00:00"`     | Slot start — format `yyyy-MM-dd HH:mm:ss`           |
| `end`          | `string`        | `"2026-04-08 09:30:00"`     | Slot end — format `yyyy-MM-dd HH:mm:ss`             |
| `visitId`      | `string`        | `"301"`                     | Visit type ID                                       |
| `visitTypeId`  | `string`        | `"301"`                     | Alternate visit type ID field                       |
| `reason`       | `string`        | `"Annual checkup"`          | Reason for visit                                    |
| `status`       | `string`        | `"VER"`                     | Encounter status code — see status code table       |
| `pStatus`      | `string`        | `"VER"`                     | Patient status code — used as fallback for `status` |
| `resources`    | `string`        | `"42"`                      | Resource/provider ID (alternate field)              |
| `POS`          | `string`        | `"11"`                      | Place of service code                               |
| `totalVisit`   | `number`        | `3`                         | Total visit/remaining capacity count                |
| `dob`          | `string`        | `"01/15/1980"`              | Patient date of birth                               |
| `email`        | `string`        | `"patient@example.com"`     | Patient email                                       |
| `cellphoneNo`  | `string`        | `"555-1234"`                | Patient cell phone                                  |
| `upPhone`      | `string`        | `"555-5678"`                | Patient alternate phone                             |
| `generalNotes` | `string`        | `"Patient prefers morning"` | General appointment notes                           |
| `encType`      | `string`        | `"OF"`                      | Encounter type code                                 |
| `newPt`        | `string`        | `"Y"`                       | Flag — `"Y"` = new patient                          |
| `deptId`       | `string`        | `"5"`                       | Department ID                                       |

---

## 2. `WorkHour` (provider availability block)

| Field          | JSON Type       | Example                 | Notes                                      |
| -------------- | --------------- | ----------------------- | ------------------------------------------ |
| `resourceId`   | `string`        | `"42"`                  | Provider/resource ID                       |
| `facilityId`   | `string`        | `"10"`                  | Facility ID — `"0"` or empty = invalid     |
| `facilityName` | `string`        | `"Main Clinic"`         | Facility display name                      |
| `start`        | `string`        | `"2026-04-08 08:00:00"` | Block start — format `yyyy-MM-dd HH:mm:ss` |
| `end`          | `string`        | `"2026-04-08 17:00:00"` | Block end — format `yyyy-MM-dd HH:mm:ss`   |
| `POS`          | `number`        | `11`                    | Place of service code                      |
| `free`         | `boolean`       | `true`                  | Whether block is available                 |
| `nWeekDay`     | `number`        | `1`                     | Day of week (0=Sun … 6=Sat)                |
| `size`         | `number`        | `30`                    | Slot size in minutes                       |
| `background`   | `string`        | `"#FFFFFF"`             | UI background color                        |
| `userId`       | `number`        | `42`                    | User ID associated with block              |

---

## Quick-Reference: Code Conventions

| Value | Field | Meaning |
|---|---|---|
| `"Y"` | `newPt` | Patient is a new patient |
| `"VER"` | `status`, `pStatus` | Encounter / patient status verified |
| `"OF"` | `encType` | Office encounter type |
| `"11"` | `POS` | Place of Service 11 = physician office |
| `"0"` / `""` | `facilityId` | Invalid / unset facility — should be filtered out |
| `"1900-01-01"` | date sentinel | Event has not yet occurred |
| `true` | `free` | Work-hour block is available for scheduling |
| `0` | `nWeekDay` | Sunday (0=Sun … 6=Sat) |

