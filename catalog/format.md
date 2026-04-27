# Data Catalog — Format Reference

> This document defines the standard structure, rules, and template for all EHR resource catalog files.  
> Use it as the single source of truth when documenting a new resource.

---

## Table of Contents

1. [File Naming](#1-file-naming)
2. [File Header Block](#2-file-header-block)
3. [Section Structure](#3-section-structure)
4. [Field Table Columns](#4-field-table-columns)
5. [JSON Type Vocabulary](#5-json-type-vocabulary)
6. [Note Writing Rules](#6-note-writing-rules)
7. [Quick-Reference Table](#7-quick-reference-table)
8. [Full File Template](#8-full-file-template)
9. [Checklist Before Saving](#9-checklist-before-saving)

---

## 1. File Naming

| Rule | Detail |
|---|---|
| One file per EHR resource | `patient.md`, `appointments.md`, `coverage.md`, etc. |
| Lowercase, no spaces | Use underscores if needed: `claim_lines.md` |
| Saved in `/catalog/` folder | All catalog files live in the same flat directory |

---

## 2. File Header Block

Every file **must** start with an H1 title followed by exactly three blockquote lines.

```markdown
# <Resource Name> Data Catalog

> **Source:** <Where this data comes from — system, API, endpoint>
> **Purpose:** Knowledge base for AI agents — describes all fields returned in a <resource> payload.
> **Note:** <Any important type conventions, e.g. flag strings, sentinel values, code strings>

---
```

### Header Line Rules

| Line | Required | Content |
|---|---|---|
| `> **Source:**` | Yes | Name the EHR system and the specific API / endpoint / table |
| `> **Purpose:**` | Yes | Always start with `"Knowledge base for AI agents —"` then describe what the file covers |
| `> **Note:**` | Yes | Explain any recurring encoding patterns (flag strings, sentinel dates, code strings). If there are none, still include the line and write `"No special encoding conventions."` |

---

## 3. Section Structure

### Simple resource (flat JSON object)

```
## 1. Root-Level Fields
## Quick-Reference: Code Conventions   ← always last
```

### Nested resource (object with sub-objects or arrays)

```
## 1. Root-Level Fields
## 2. `objectName` Object  (or `arrayName[]` Array)
### 2a. `objectName.subObject`
### 2b. `objectName.anotherSubObject`
## Quick-Reference: Code Conventions   ← always last
```

### Rules

- Sections are numbered starting at `1` (except Quick-Reference which is always last and unnumbered).
- Sub-sections use letter suffixes: `3a`, `3b`, `3c`, …
- When a root-level field points to a section, link it in the Notes column:  
  `see [Section 2](#2-objectname-object)`
- Use backtick-wrapped names in headings: `## 2. \`encdata\` Object`

---

## 4. Field Table Columns

Every field table has exactly **four columns** in this order:

```markdown
| Field | JSON Type | Example | Notes |
|---|---|---|---|
```

### Column Definitions

| Column | Purpose | Rules |
|---|---|---|
| **Field** | JSON key name | Always wrapped in backticks: `` `fieldName` `` |
| **JSON Type** | The JSON data type | Use vocabulary from [Section 5](#5-json-type-vocabulary) — always wrapped in backticks |
| **Example** | A realistic sample value | Strings in double-quotes inside backticks: `` `"value"` ``; numbers/booleans unquoted: `` `1` ``, `` `true` ``; nested objects: `` `{...}` ``; empty arrays: `` `[]` `` |
| **Notes** | Human-readable description | Start with a capital letter. Include format patterns, flag decoding, relationships to other fields, or whether the field can be empty |

---

## 5. JSON Type Vocabulary

Use only these standardized type names in the **JSON Type** column:

| Type | When to use |
|---|---|
| `` `string` `` | Any text value, including dates/times stored as strings, flag strings, code strings |
| `` `integer` `` | Whole numbers (IDs, counts, codes stored as numbers) |
| `` `number` `` | Decimal / floating-point numbers |
| `` `boolean` `` | True JSON booleans (`true` / `false`) |
| `` `object` `` | A nested JSON object `{}` |
| `` `array` `` | A JSON array `[]` with untyped or mixed elements |
| `` `array<object>` `` | A JSON array where every element is an object |
| `` `array<string>` `` | A JSON array where every element is a string |

> **Never** use language-specific types (`TypeScript`, `any`, `null`) in the JSON Type column.

---

## 6. Note Writing Rules

### Dates and times
- Always state the format explicitly:  
  `Date of birth — format \`MM/DD/YYYY\``  
  `Timestamp — format \`YYYY-MM-DD HH:MM:SS\``

### Flag strings / flag integers
- Decode both possible values inline:  
  `Flag string — \`"1"\` = enabled, \`"0"\` = disabled`  
  `Flag integer — \`1\` = yes, \`0\` = no`

### Code strings
- List the known codes inline when there are ≤ 4 values:  
  `Code string — \`"V"\` = verified, \`"U"\` = unverified, \`"I"\` = inactive`
- For longer code lists, reference the Quick-Reference table:  
  `Appointment status code — see Quick-Reference table`

### Sentinel values
- Flag sentinel dates explicitly:  
  `Sentinel value \`"1900-01-01"\` = event has not yet occurred`

### Optional / nullable fields
- If a field can be empty or null, say so:  
  `Street address (can be empty)`

### Cross-field references
- If the value of one field is the ID of another resource, say so:  
  `ID of the provider's primary service location`  
  `Matches \`patientId\` when the patient is their own guarantor`

---

## 7. Quick-Reference Table

The last section of every file is a **Quick-Reference: Code Conventions** table. It consolidates all code strings, flag values, and sentinel values in one place so an AI agent can look them up without scanning the full field table.

```markdown
## Quick-Reference: Code Conventions

| Value | Field | Meaning |
|---|---|---|
| `"V"` / `"U"` | `eligibilityStatus` | Verified / Unverified |
| `"$"` / `"%"` | `copayType` | Flat dollar copay / percentage copay |
| `1` | `isGuarantorPatient` | Guarantor equals patient |
| `"1900-01-01"` | `arrivedTime`, `depTime` | Sentinel — event has not occurred yet |
```

### Rules
- Include every code string, flag, and sentinel value used in the file.
- Group related values on one row when the decoding is a simple pair (e.g. `"Y"` / `"N"`).
- List multiple affected fields in the **Field** column separated by `, `.
- Keep the **Meaning** column to one short phrase.

---

## 8. Full File Template

Copy and fill in the blanks when creating a new catalog file.

```markdown
# <Resource Name> Data Catalog

> **Source:** <EHR system> — <API / endpoint / table name>
> **Purpose:** Knowledge base for AI agents — describes all fields returned in a <resource name> payload.
> **Note:** <Encoding conventions, or "No special encoding conventions.">

---

## 1. Root-Level Fields

| Field | JSON Type | Example | Notes |
|---|---|---|---|
| `fieldName` | `string` | `"example"` | Description of the field |

---

## 2. `nestedObject` Object        ← delete if not needed

| Field | JSON Type | Example | Notes |
|---|---|---|---|
| `fieldName` | `integer` | `42` | Description of the field |

---

## Quick-Reference: Code Conventions

| Value | Field | Meaning |
|---|---|---|
| `"Y"` / `"N"` | `someFlag` | Yes / No |
```

---

## 9. Checklist Before Saving

- [ ] H1 title ends with `Data Catalog`
- [ ] All three header blockquote lines present (`Source`, `Purpose`, `Note`)
- [ ] Every section is numbered; Quick-Reference is last and unnumbered
- [ ] Table has exactly four columns: `Field`, `JSON Type`, `Example`, `Notes`
- [ ] All JSON Types use only the vocabulary from Section 5
- [ ] Every date/time field states its format
- [ ] Every flag field decodes both `0`/`1` or `Y`/`N` values
- [ ] Every code string is decoded inline or referenced to Quick-Reference
- [ ] Sentinel values are explicitly labeled
- [ ] Quick-Reference table covers all flags, codes, and sentinels in the file
