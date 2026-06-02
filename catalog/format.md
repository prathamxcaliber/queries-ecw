# Data Catalog — Format Reference

> This document defines the standard structure and content rules for all EHR resource catalog files.  
> Use it as the single source of truth when documenting a new resource.

---

## Table of Contents

1. [File Naming](#1-file-naming)
2. [File Header Block](#2-file-header-block)
3. [Section Structure](#3-section-structure)
4. [Field Table Columns](#4-field-table-columns)
5. [JSON Type Vocabulary](#5-json-type-vocabulary)
6. [Notes Column Rules](#6-notes-column-rules)
7. [Quick-Reference Table](#7-quick-reference-table)
8. [Checklist Before Saving](#8-checklist-before-saving)

---

## 1. File Naming

| Rule | Detail |
|---|---|
| One file per EHR resource | `patient.md`, `appointments.md`, `coverage.md`, etc. |
| Lowercase, no spaces | Use underscores if needed: `claim_lines.md` |
| Saved in `/catalog/` folder | All catalog files live in the same flat directory |

---

## 2. File Header Block

Every catalog file starts with a title and three metadata lines:

| Line | Required | What to write |
|---|---|---|
| **Source** | Yes | The EHR system and the specific API, endpoint, or table the data comes from |
| **Purpose** | Yes | Always starts with "Knowledge base for AI agents —" followed by a description of what the file covers |
| **Note** | Yes | Any recurring encoding patterns in this resource (flag strings, sentinel dates, code strings). If none, write "No special encoding conventions." |

---

## 3. Section Structure

Each catalog file is divided into numbered sections, one per object or array in the payload. The **Quick-Reference** section is always last and is not numbered.

**Simple resource** (flat JSON object):

| Section | Content |
|---|---|
| 1 | Root-Level Fields |
| — | Quick-Reference: Code Conventions |

**Nested resource** (object with sub-objects or arrays):

| Section | Content |
|---|---|
| 1 | Root-Level Fields |
| 2 | The nested object or array |
| 2a, 2b … | Sub-sections for each sub-object within section 2 |
| — | Quick-Reference: Code Conventions |

When a root-level field (e.g. `preferences`, `insurances`) is documented in a later section, the Notes column for that field references the section number.

---

## 4. Field Table Columns

Every field table documents four pieces of information per row:

| Column | What it contains |
|---|---|
| **Field** | The exact JSON key name |
| **JSON Type** | The data type — see [Section 5](#5-json-type-vocabulary) for allowed values |
| **Example** | A realistic sample value taken from an actual payload |
| **Notes** | A plain-English description — includes data format, what the value means, allowed values, and whether the field can be empty |

---

## 5. JSON Type Vocabulary

Use only these type names in the **JSON Type** column:

| Type | When to use |
|---|---|
| `string` | Any text value, including dates/times stored as strings, flag strings, and code strings |
| `integer` | Whole numbers — IDs, counts, numeric codes |
| `number` | Decimal or floating-point numbers |
| `boolean` | True JSON booleans (`true` / `false`) |
| `object` | A nested JSON object |
| `array` | A JSON array with untyped or mixed elements |
| `array<object>` | A JSON array where every element is an object |
| `array<string>` | A JSON array where every element is a string |

---

## 6. Notes Column Rules

The Notes column must include the following information where applicable:

| Situation | What to document |
|---|---|
| Date or time field | State the exact format: `MM/DD/YYYY` or `YYYY-MM-DD HH:MM:SS` |
| Flag string (`"0"`/`"1"`) | Decode both values: what `"1"` means and what `"0"` means |
| Flag integer (`0`/`1`) | Decode both values: what `1` means and what `0` means |
| Code string (e.g. `"V"`, `"CI"`) | List all known codes and their meanings inline (up to ~4 values); for longer lists, note "see Quick-Reference table" |
| Sentinel date (e.g. `"1900-01-01"`) | Explicitly state that the value is a sentinel and what it signals |
| Field that can be empty or null | State "can be empty" |
| Field whose value is an ID of another resource | Name the resource it links to |
| Field whose value mirrors another field | State which field it matches and under what condition |

---

## 7. Quick-Reference Table

The last section of every file is a code conventions lookup table with three columns:

| Column | Content |
|---|---|
| **Value** | The code, flag value, or sentinel — paired values (e.g. `"Y"` / `"N"`) go on one row |
| **Field** | The field name(s) where this value appears; multiple fields separated by a comma |
| **Meaning** | A short plain-English phrase explaining what the value means |

Every flag value, code string, and sentinel date documented in the field tables above must appear in this table.

---

## 8. Checklist Before Saving

- [ ] Title ends with `Data Catalog`
- [ ] All three header lines present: Source, Purpose, Note
- [ ] Sections are numbered; Quick-Reference is last and unnumbered
- [ ] Every field table has exactly four columns: Field, JSON Type, Example, Notes
- [ ] All JSON Types use only the vocabulary from Section 5
- [ ] Every date/time field states its format
- [ ] Every flag field decodes both values
- [ ] Every code string is decoded inline or points to the Quick-Reference table
- [ ] Every sentinel value is explicitly labeled
- [ ] Quick-Reference table covers all flags, codes, and sentinels in the file
