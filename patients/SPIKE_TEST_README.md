# Patients Spike Test - Validation Guide

## Overview
Testing all 7 pending fixes for the Patients resource before applying to main query.

## How to Run
1. Execute `patients_query_spike.sql` in your SQL client
2. Review the results comparing `*_current` vs `*_fixed` columns
3. Report back which fixes show the expected values

## Expected Results

### Fix 1: ethnicity
- **ethnicity_current:** `ASKU`
- **ethnicity_fixed:** `Declined to Specify` ✓

### Fix 2: needsTranslator  
- **needsTranslator_current:** Should already be `1`
- **bTranslator_raw:** Check actual database value
- ℹ️ This may already be correct - verify the raw value

### Fix 3: primaryCareProvider
- **primaryCareProvider_current:** `PATEL, JITESH, V`
- **primaryCareProvider_fixed:** `Patel MD, Jitesh, V` ✓
- Check debug fields: `att_credentials` should show `MD`

### Fix 4: primaryServiceLocation
- **primaryServiceLocation_current:** `0`
- **One of these should be 3:**
  - `pmcId_raw`
  - `DefFeeSchId_option`
  - `primaryservicelocation_from_users` ← Most likely

### Fix 5: referringProvider
- **referringProvider_current:** Empty
- **referringProvider_fixed:** Should show `Need, Updated Information`
- Check: `refPrId`, `ref_lastname`, `ref_firstname` - do these have data?

### Fix 6: renderingProvider
- **renderingProvider_current:** Empty  
- **renderingProvider_fixed:** Should show `Need, Updated Information`
- Check: `rendPrId`, `rend_lastname`, `rend_firstname` - do these have data?

### Fix 7: feeScheduleName (separate query)
- **feeScheduleName_current:** Empty
- **Should show:** `4. Selfpay`
- Check: `slidingscalesetup_value`

## Report Template

Copy and fill in:

```
FIX 1 (ethnicity): ✓ Works / ✗ Doesn't work
  - ethnicity_fixed shows: _________

FIX 2 (needsTranslator): ✓ Already correct / ✗ Still wrong
  - needsTranslator_current: _________
  - bTranslator_raw: _________

FIX 3 (primaryCareProvider): ✓ Works / ✗ Doesn't work
  - primaryCareProvider_fixed shows: _________
  - att_credentials: _________

FIX 4 (primaryServiceLocation): Which field has value 3?
  - pmcId_raw: _________
  - DefFeeSchId_option: _________
  - primaryservicelocation_from_users: _________

FIX 5 (referringProvider): ✓ Data exists / ✗ No data
  - referringProvider_fixed shows: _________
  - refPrId: _________
  - ref_lastname: _________

FIX 6 (renderingProvider): ✓ Data exists / ✗ No data
  - renderingProvider_fixed shows: _________
  - rendPrId: _________
  - rend_lastname: _________

FIX 7 (feeScheduleName): ✓ Works / ✗ Doesn't work
  - feeScheduleName_current: _________
  - slidingscalesetup_value: _________
```

## Next Steps
Once you report the results, I'll:
1. Apply working fixes to `patients_query.sql`
2. Update `mismatches.json`
3. Identify any remaining data quality issues
