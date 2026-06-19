# GCP Trainizi Crypto Mining Incident - 2026-04-29

## Alert
"Suspicious Activity observed on your Google Cloud Platform/API project Trainizi-6663629"
Google also suspended IP 34.47.42.142. Refund issue #36765726.

## Timeline
- **2024-10-25**: SA key committed to public GitHub repo `izi-community/castle` by `sonhoai272@gmail.com`
- **2026-04-29 09:38 UTC**: Attacker begins mass VM creation via compromised `dfagent@` SA
- **2026-04-29 ~16:20 +07:00**: Alert received, investigation begins
- **2026-04-29 ~16:30**: 2,858 malicious instances identified, deletion initiated
- **2026-04-29 ~16:40**: `dfagent@` SA disabled, all 4 user-managed keys deleted
- **2026-04-29 ~16:45**: `roles/owner` removed from `dfagent@` and `backup-s3@` SAs
- **2026-04-29 ~17:50**: All 2,858 instances deleted. Project clean.
- **2026-04-29 ~18:00**: Root cause identified - leaked SA key on GitHub

## Root Cause: Leaked SA Key on GitHub

**Key `83544c31`** found in public GitHub repos under `izi-community` org:

| Repo | Path | Key ID | Committed By | Date |
|------|------|--------|-------------|------|
| `izi-community/castle` | `firebase/izi-community-firebase-adminsdk-x2k55-a9bd501f21.json` | `83544c31` | `sonhoai272@gmail.com` | 2024-10-25 |
| `izi-community/backend-v2` | `app/services/trainizi-6663629.json` | `6be847be` | - | - |
| `izi-community/teachizi-backend` | `app/services/trainizi-6663629.json` | `6be847be` | - | - |

**Chain of events**: Developer committed `dfagent@` SA JSON credential to repo. Attacker harvested the key. Used `roles/owner` on the SA to create 2,858 mining VMs across 96+ global zones.

## Resources Created by Attacker
| Resource | Count | Details |
|----------|-------|---------|
| Compute instances | 2,858 | All `auto-vm-*`, 2 vCPU each |
| Persistent disks | ~2,858 | 20GB each (deleted with VMs) |
| Estimated cost | ~$9,000-10,000/day | e2/n1/n2-standard-2 |

## Remediation Completed

| Action | Status |
|--------|--------|
| Disable `dfagent@` SA | Done |
| Delete all 4 dfagent SA keys | Done |
| Remove `roles/owner` from `dfagent@`, `backup-s3@` | Done |
| Delete all 2,858 malicious VMs | Done |
| `firebase-adminsdk` TokenCreator scoped | Done (earlier session) |
| Identify root cause (GitHub leak) | Done |
| Scan GitHub for leaked credentials | Done |

## Manual Actions Required

### 1. File Refund (URGENT - within 60 days)
- **Issue #**: 36765726
- Contact Google Cloud Support for unauthorized usage credit
- Reference suspended IP 34.47.42.142

### 2. Remove Leaked Credentials from GitHub
Contact `izi-community` org admins to purge from these repos:
- `izi-community/castle` → `firebase/izi-community-firebase-adminsdk-x2k55-a9bd501f21.json`
- `izi-community/backend-v2` → `app/services/trainizi-6663629.json`
- `izi-community/teachizi-backend` → `app/services/trainizi-6663629.json`
- Use BFG or `git filter-repo` to purge from git history

### 3. Enable Org Policies (requires Console)
`trung@finizi.app` lacks `orgpolicy.policies.create` permission. A project owner must set:
- `constraints/iam.managed.disableServiceAccountKeyCreation`
- `constraints/compute.requireOsLogin`
- `constraints/compute.vmExternalIpAccess`

### 4. Rotate Remaining SA Keys (when apps ready)
| SA | Keys | Created |
|----|------|---------|
| `firebase-adminsdk-tgwyy` | 3 | 2025-02 to 2025-07 |
| `trainizi-creator` | 1 | 2025-03 |
| `trainizi-live` | 2 | 2025-03 to 2025-07 |
| `vtcizi-ai` | 1 | 2025-02 |
| `trainizi-lp-web` | 1 | 2025-05 |
| `azure-workload` | 1 | 2026-03 |
| `backup-s3` | 1 | 2025-09 |

### 5. IAM Cleanup (team discussion)
- Downgrade `hhieu@trainizi.com` from `roles/editor`
- Verify `baomit01@gmail.com` is authorized
- Scope down default SA editor roles

### 6. Monitoring Setup
- Billing alert at $50/day
- Cloud Monitoring alert for >10 VM creates/hour
- Enable audit logging for all IAM changes

## Unresolved Questions
1. How long were keys exposed before harvesting?
2. Was data exfiltrated from Firestore/Storage?
3. Total financial impact — check billing
4. Does `hhieu@trainizi.com` need editor?
5. Is `baomit01@gmail.com` authorized?
6. More leaked keys in private repos or other orgs?
