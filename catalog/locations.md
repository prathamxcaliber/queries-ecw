# Locations Data Catalog

> **Source:** EHR system service location record  
> **Purpose:** Knowledge base for AI agents — describes all fields returned in a location payload.

---

## 1. Root-Level Fields

| Field | JSON Type | Example | Notes |
|---|---|---|---|
| `id` | `integer` | `3` | Unique location / facility ID |
| `name` | `string` | `"Advanced Urology Institute"` | Display name of the location |
| `address` | `string` | `""` | Street address (can be empty) |
| `city` | `string` | `"SNELLVILLE"` | City — typically uppercase |
| `state` | `string` | `"GA"` | 2-letter US state code |
| `zip` | `string` | `"30078-5686"` | ZIP code — may include ZIP+4 format (`XXXXX-XXXX`) |
| `pos` | `integer` | `11` | Place of Service code (CMS standard — e.g. `11` = office) |

---

## Quick-Reference: Code Conventions

| Value | Field | Meaning |
|---|---|---|
| `11` | `pos` | Place of Service 11 = physician office |
| `21` | `pos` | Place of Service 21 = inpatient hospital |
| `22` | `pos` | Place of Service 22 = outpatient hospital |
