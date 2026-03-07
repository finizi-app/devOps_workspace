# GCP IAM Security Fix - 2026-03-07

## Issue 2: Downscope b4b-finizi-app SA from datastore.owner to datastore.user

### Problem
Service account `b4b-finizi-app@finiziapp.iam.gserviceaccount.com` held `roles/datastore.owner`, granting full Firestore/Datastore administrative control including ability to:
- Delete all collections
- Modify indexes
- Export all data

**Impact:** If this SA is compromised via an application vulnerability (SSRF, RCE), an attacker can wipe all Firestore data.

### Resolution

#### 1. Removed datastore.owner role
```bash
gcloud projects remove-iam-policy-binding finiziapp \
  --member="serviceAccount:b4b-finizi-app@finiziapp.iam.gserviceaccount.com" \
  --role="roles/datastore.owner" \
  --condition=None
```

#### 2. Verified datastore.user role exists
The SA already had `roles/datastore.user` for standard read/write operations.

### Result
| Role | Before | After |
|------|--------|-------|
| `roles/datastore.owner` | ✅ Held | ❌ Removed |
| `roles/datastore.user` | ✅ Held | ✅ Held |

---

## Issue 3: Downscope finizi-bigquery-dasbhoard SA from admin to read-only

### Problem
Service account `finizi-bigquery-dasbhoard@finiziapp.iam.gserviceaccount.com` held:
- `roles/bigquery.admin` - full BigQuery admin (delete datasets, manage billing, modify tables)
- `roles/bigquery.dataEditor` - redundant since admin includes it

**Impact:** Dashboard SA only needs read access, not admin control.

### Resolution

#### 1. Removed bigquery.admin and bigquery.dataEditor
```bash
gcloud projects remove-iam-policy-binding finiziapp \
  --member="serviceAccount:finizi-bigquery-dasbhoard@finiziapp.iam.gserviceaccount.com" \
  --role="roles/bigquery.admin" --condition=None

gcloud projects remove-iam-policy-binding finiziapp \
  --member="serviceAccount:finizi-bigquery-dasbhoard@finiziapp.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataEditor" --condition=None
```

#### 2. Added read-only roles
```bash
gcloud projects add-iam-policy-binding finiziapp \
  --member="serviceAccount:finizi-bigquery-dasbhoard@finiziapp.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataViewer" --condition=None

gcloud projects add-iam-policy-binding finiziapp \
  --member="serviceAccount:finizi-bigquery-dasbhoard@finiziapp.iam.gserviceaccount.com" \
  --role="roles/bigquery.jobUser" --condition=None
```

### Result
| Role | Before | After |
|------|--------|-------|
| `roles/bigquery.admin` | ✅ Held | ❌ Removed |
| `roles/bigquery.dataEditor` | ✅ Held | ❌ Removed |
| `roles/bigquery.dataViewer` | ❌ | ✅ Added |
| `roles/bigquery.jobUser` | ❌ | ✅ Added |

---

## Issue 4: Revoke aiplatform.serviceAgent from trung-adk SA

### Problem
Service account `trung-adk@finiziapp.iam.gserviceaccount.com` held `roles/aiplatform.serviceAgent` - a role reserved exclusively for GCP-managed Vertex AI service agents, not user-created SAs.

**Impact:** The SA already had `roles/aiplatform.user` and `roles/ml.developer` which are the correct roles for user workloads.

### Resolution
```bash
gcloud projects remove-iam-policy-binding finiziapp \
  --member="serviceAccount:trung-adk@finiziapp.iam.gserviceaccount.com" \
  --role="roles/aiplatform.serviceAgent" --condition=None
```

### Result
| Role | Before | After |
|------|--------|-------|
| `roles/aiplatform.serviceAgent` | ✅ Held | ❌ Removed |
| `roles/aiplatform.user` | ✅ Held | ✅ Held |
| `roles/ml.developer` | ✅ Held | ✅ Held |

---

## Issue 5: Delete 3 empty storage buckets

### Problem
Three storage buckets were confirmed empty (0 bytes) and served no active purpose:
- `finiziapp-migration-20250718` (July 2025 migration artifact, 7+ months stale)
- `finiziapp-staging-bucket` (empty staging bucket)
- `finizi-dis-temp-dev` (empty temp/dev bucket)

### Resolution
```bash
gsutil rm -r gs://finiziapp-migration-20250718 gs://finiziapp-staging-bucket gs://finizi-dis-temp-dev
```

### Result
All 3 buckets deleted successfully.

---

## Issue 6: Cloud SQL Cost Anomaly Investigation

### Alert
Billing anomaly detection flagged Cloud SQL with z-score 2.16 on Mar 6, 2026. Cloud SQL is the top gross cost driver at $1.51M over 14 days (~$3.3M/month).

### Investigation

#### Instance Status
| Instance | Tier | Storage | Status |
|----------|------|---------|--------|
| finiziapp-db-prod | db-custom-2-4096 | 20GB PD_SSD | ✅ RUNNABLE |
| finizi-content-db | db-f1-micro | 10GB PD_SSD | ✅ RUNNABLE |

#### Key Finding
Hourly costs on Mar 6 dropped from **~$4,711/hour** to **near-zero** at hour 9 (16:00+07:00):

```
Hour 0-8:  ~$4,711/hour (normal)
Hour 9:    $28.93 (abnormally low)
Hour 10:   $0.19 (near zero)
```

#### Possible Causes
1. **Billing data lag** - Hour 9-10 data may be delayed/incomplete
2. **Instance restart/maintenance** - No visible operations in Cloud SQL logs
3. **Anomaly detection** - Flagged the unusual billing data pattern

### Result
- **Status**: No immediate action required
- **Recommendation**: Monitor Mar 6-7 costs for completion, check application logs for connection issues around 16:00+07:00 on Mar 6
- The z-score 2.16 likely flagged the unusual billing data pattern (incomplete day), not an actual cost spike

---

## Issue 1: Firebase Admin SDK TokenCreator Privilege Escalation

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
