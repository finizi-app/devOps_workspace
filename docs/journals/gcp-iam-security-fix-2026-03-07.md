# GCP IAM Security Fix - 2026-03-07

## Issue
Critical privilege escalation vulnerability in GCP project `finiziapp`.

### Problem
Service account `firebase-adminsdk-fbsvc@finiziapp.iam.gserviceaccount.com` held the `roles/iam.serviceAccountTokenCreator` role at **project level**, granting it the ability to mint tokens for **any** service account in the project.

This included:
- `full-access-sa@finiziapp.iam.gserviceaccount.com` (Owner role)
- `owner-service-account@finiziapp.iam.gserviceaccount.com` (Owner role)

**Impact:** If `firebase-adminsdk-fbsvc` was compromised, attacker could generate tokens for owner-level SAs and achieve full project takeover.

## Resolution

### 1. Removed Project-Level TokenCreator
```bash
gcloud projects remove-iam-policy-binding finiziapp \
  --member="serviceAccount:firebase-adminsdk-fbsvc@finiziapp.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountTokenCreator" \
  --condition=None
```

### 2. Added Granular Condition
```bash
gcloud alpha projects add-iam-policy-binding finiziapp \
  --member="serviceAccount:firebase-adminsdk-fbsvc@finiziapp.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountTokenCreator" \
  --condition="title=Allow firebase to mint tokens for app SA,expression=resource.name.endsWith('b4b-finizi-app')"
```

## Result
| Target SA | Before | After |
|-----------|--------|-------|
| `full-access-sa` | ✅ Can impersonate | ❌ Blocked |
| `owner-service-account` | ✅ Can impersonate | ❌ Blocked |
| `b4b-finizi-app` | ✅ Can impersonate | ✅ Allowed |

## Date
Fixed: 2026-03-07
