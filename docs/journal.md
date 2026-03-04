# DevOps Workspace Journal

---

## Entry 1: Documentation & KiotViet Deployment (2026-03-03)

### Work Done
1. **Initialized DevOps documentation** in `docs/`:
   - `README.md` - Operations overview
   - `target-projects.md` - b4b-api, finizi_kiotviet_client, fina-ai-agent
   - `infrastructure.md` - Azure VMs, PostgreSQL, Key Vault, GCloud
   - `deployment-guide.md` - CI/CD procedures

2. **Reviewed finizi_kiotviet_client/deploy/** scripts:
   - `deploy.sh`, `setup-vm.sh`, `check-vm.sh`, `prepare-vm.sh`
   - `docker-compose.prod.yml`, `nginx-8010.conf`

3. **Fixed KiotViet server** (52.163.118.135:8010):
   - Started container: `docker compose -f docker-compose.prod.yml up -d --build`
   - Removed conflicting nginx config
   - Added nginx proxy for port 8010 → container:8001
   - Health check: `{"status":"healthy","service":"KiotViet API Tester"}`

4. **Synced with b4b deployment journal**:
   - Read `/Users/trunghuynh/development/b4b-api/docs/journals/deployment-azure-production.md`
   - Updated docs with staging VM details (finizi_dev, 52.163.118.135)
   - Added production URLs, credential handling, key fixes

5. **Created journal monitor script**:
   - `scripts/check-deployment-journal.sh` - monitors b4b journal for changes
   - Reports pending tasks, blockers, unchecked items

### Current Infrastructure Status

| Environment | VM | IP | Domain | Status |
|-------------|-----|-----|--------|--------|
| Production | vm-finizi-prod | 20.212.32.64 | admin.prod.finizi.ai | ✅ Running |
| Staging | finizi_dev | 52.163.118.135 | admin.dev.finizi.ai | ✅ Running |
| KiotViet | finizi_dev | 52.163.118.135:8010 | - | ✅ Running |

### Files Created This Session
```
docs/
├── README.md (updated)
├── target-projects.md (created + updated)
├── infrastructure.md (created + updated)
├── deployment-guide.md (created + updated)
└── journal.md (this file)

scripts/
├── check-deployment-journal.sh (created)
└── README.md (created)

.cache/
└── journal-last-check.md5 (auto-generated)
```

### Next Steps
- Monitor b4b deployment journal for new operations
- Keep docs updated as infrastructure changes

---
