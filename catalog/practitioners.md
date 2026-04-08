# Practitioners Data Catalog

> **Source:** EHR system practitioner/provider record  
> **Purpose:** Knowledge base for AI agents — describes all fields returned in a practitioner payload.  
> **Note:** "Flag integer" = `0` / `1` numeric boolean.

---

## 1. Root-Level Fields

| Field | JSON Type | Example | Notes |
|---|---|---|---|
| `id` | `integer` | `122` | Unique provider ID |
| `fullname` | `string` | `"Patel,Jitesh V"` | Provider full name — format `LastName,FirstName MiddleInitial` |
| `dbprintname` | `string` | `"Jitesh V Patel M.D. TEST"` | Formatted display/print name including credentials |
| `userName` | `string` | `"jiteshp"` | EHR system username for the provider |
| `providerCode` | `string` | `"JVP"` | Short provider code / abbreviation |
| `NPI` | `integer` | `1265640486` | National Provider Identifier (10-digit) |
| `P2PNPI` | `integer` | `0` | Secondary / peer-to-peer NPI; `0` = not set |
| `Credentials` | `string` | `"MD"` | Provider credentials (e.g. `"MD"`, `"DO"`, `"NP"`, `"PA"`) |
| `Specialty` | `string` | `"Urology"` | Provider medical specialty |
| `sex` | `string` | `"Male"` | Provider sex (e.g. `"Male"`, `"Female"`) |
| `languages` | `string` | `"English"` | Languages spoken by the provider |
| `primarylocation` | `integer` | `3` | ID of the provider's primary service location |
| `timezone` | `string` | `""` | Provider timezone (can be empty) |
| `inactive` | `integer` | `0` | Flag integer — `1` = inactive, `0` = active |
| `status` | `integer` | `0` | Flag integer — `0` = active, `1` = inactive |

---

## Quick-Reference: Code Conventions

| Value | Field | Meaning |
|---|---|---|
| `0` | `inactive` | Provider is active |
| `1` | `inactive` | Provider is inactive / deactivated |
| `0` | `status` | Provider status is active |
| `0` | `P2PNPI` | No secondary NPI assigned |
