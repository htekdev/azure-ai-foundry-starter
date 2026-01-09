# Repository Migration Manual Checklist

## Pre-Migration Setup

### Environment Variables Setup
- [ ] Set `AZURE_DEVOPS_PAT` (Personal Access Token)
- [ ] Set `AZURE_CLIENT_ID` (Service Principal)
- [ ] Set `AZURE_CLIENT_SECRET` (Service Principal Secret)
- [ ] Set `AZURE_TENANT_ID` (Azure AD Tenant)
- [ ] Set `AZURE_SUBSCRIPTION_ID` (Azure Subscription)

### Tool Installation
- [ ] PowerShell 7+ installed
- [ ] Git installed (2.30+)
- [ ] Azure CLI installed (2.50+)
- [ ] Python 3.11+ installed
- [ ] VS Code or preferred editor

### Azure DevOps Access
- [ ] Access to Azure DevOps organization
- [ ] Project Administrator permissions
- [ ] Can create repositories
- [ ] Can create pipelines
- [ ] Can manage service connections

### Azure Resources
- [ ] Azure AI Project (Dev) created
- [ ] Azure AI Project (Test) created
- [ ] Azure AI Project (Prod) created
- [ ] Azure OpenAI Service deployed
- [ ] Service Principal has appropriate roles

---

## Phase 1: Local Preparation

### Step 1: Create Workspace
```powershell
New-Item -ItemType Directory -Path "C:\Repos\northwind-systems\migration-workspace" -Force
cd C:\Repos\northwind-systems\migration-workspace
```

**Status**: ⬜ Not Started | ✅ Complete | ❌ Failed

---

### Step 2: Clone Source Repository
```powershell
git clone https://github.com/balakreshnan/foundrycicdbasic.git source-repo
cd source-repo
```

**Verification**: Check that files exist:
- [ ] `createagent.py`
- [ ] `cicd/createagentpipeline.yml`
- [ ] `docs/README.md`
- [ ] `requirements.txt`

**Status**: ⬜ Not Started | ✅ Complete | ❌ Failed

---

### Step 3: Create Backup
```powershell
cd ..
Copy-Item -Path "source-repo" -Destination "source-repo-backup" -Recurse
Compress-Archive -Path "source-repo-backup" -DestinationPath "backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').zip"
```

**Verification**: Backup zip file created

**Status**: ⬜ Not Started | ✅ Complete | ❌ Failed

---

## Phase 2: Reorganization

### Step 4: Create New Directory Structure
```powershell
cd source-repo

# Create directories
$dirs = @(
    ".azure-pipelines",
    "config",
    "src/agents",
    "src/evaluation",
    "src/security",
    "src/utils",
    "scripts/setup",
    "tests/unit"
)

foreach ($dir in $dirs) {
    New-Item -ItemType Directory -Path $dir -Force
}
```

**Verification**: Directories created

**Status**: ⬜ Not Started | ✅ Complete | ❌ Failed

---

### Step 5: Move Python Scripts
```powershell
Move-Item "createagent.py" "src/agents/create_agent.py"
Move-Item "exagent.py" "src/agents/test_agent.py"
Move-Item "agenteval.py" "src/evaluation/evaluate_agent.py"
Move-Item "redteam.py" "src/security/redteam_scan.py"
Move-Item "redteam1.py" "src/security/redteam_advanced.py"
```

**Verification**: Files moved successfully

**Status**: ⬜ Not Started | ✅ Complete | ❌ Failed

---

### Step 6: Move CI/CD Files
```powershell
Move-Item "cicd/createagentpipeline.yml" ".azure-pipelines/create-agent-pipeline.yml"
Move-Item "cicd/agentconsumptionpipeline.yml" ".azure-pipelines/test-agent-pipeline.yml"
Move-Item "cicd/README.md" ".azure-pipelines/README.md"
Remove-Item "cicd" -Recurse -Force
```

**Verification**: CI/CD files in `.azure-pipelines/`

**Status**: ⬜ Not Started | ✅ Complete | ❌ Failed

---

### Step 7: Create __init__.py Files
```powershell
$initFiles = @(
    "src/__init__.py",
    "src/agents/__init__.py",
    "src/evaluation/__init__.py",
    "src/security/__init__.py",
    "src/utils/__init__.py"
)

foreach ($file in $initFiles) {
    New-Item -ItemType File -Path $file -Force
    Set-Content -Path $file -Value "# Package file"
}
```

**Verification**: All __init__.py files created

**Status**: ⬜ Not Started | ✅ Complete | ❌ Failed

---

### Step 8: Update Pipeline References
Edit `.azure-pipelines/create-agent-pipeline.yml`:
- Change `createagent.py` → `src/agents/create_agent.py`

Edit `.azure-pipelines/test-agent-pipeline.yml`:
- Change `exagent.py` → `src/agents/test_agent.py`
- Change `agenteval.py` → `src/evaluation/evaluate_agent.py`
- Change `redteam.py` → `src/security/redteam_scan.py`

**Status**: ⬜ Not Started | ✅ Complete | ❌ Failed

---

### Step 9: Commit Changes
```powershell
git checkout -b migration/reorganize-structure
git add -A
git commit -m "Reorganize repository structure

- Move Python scripts to src/ module structure
- Reorganize CI/CD to .azure-pipelines/
- Create Python package with __init__.py files
- Update pipeline script references
"
```

**Verification**: `git status` shows clean working directory

**Status**: ⬜ Not Started | ✅ Complete | ❌ Failed

---

## Phase 3: Azure DevOps - Create Repository

### Step 10: Create Repository in Portal

1. Go to `https://dev.azure.com/{your-org}/{your-project}`
2. Click **Repos** → **Files**
3. Click repository dropdown → **+ New repository**
4. Name: `foundry-cicd`
5. Type: Git
6. ❌ Don't add README or .gitignore
7. Click **Create**
8. Copy the clone URL

**Repository URL**: _________________________________

**Status**: ⬜ Not Started | ✅ Complete | ❌ Failed

---

### Step 11: Push Code to Azure DevOps
```powershell
git remote add azure https://dev.azure.com/{org}/{project}/_git/foundry-cicd
git push azure main
git push azure migration/reorganize-structure
```

**Verification**: Code visible in Azure DevOps Repos

**Status**: ⬜ Not Started | ✅ Complete | ❌ Failed

---

## Phase 4: Azure DevOps - Service Connections

### Step 12: Create Service Connection - Dev

1. Navigate to **Project Settings** → **Service connections**
2. Click **New service connection** → **Azure Resource Manager**
3. Select **Service principal (manual)**
4. Fill in:
   - **Subscription ID**: From `$env:AZURE_SUBSCRIPTION_ID`
   - **Service Principal ID**: From `$env:AZURE_CLIENT_ID`
   - **Service Principal Key**: From `$env:AZURE_CLIENT_SECRET`
   - **Tenant ID**: From `$env:AZURE_TENANT_ID`
5. **Name**: `azure-foundry-dev`
6. ✅ Grant access to all pipelines
7. Click **Verify and save**

**Status**: ⬜ Not Started | ✅ Complete | ❌ Failed

---

### Step 13: Create Service Connection - Test

Repeat Step 12 with:
- **Name**: `azure-foundry-test`

**Status**: ⬜ Not Started | ✅ Complete | ❌ Failed

---

### Step 14: Create Service Connection - Prod

Repeat Step 12 with:
- **Name**: `azure-foundry-prod`

**Status**: ⬜ Not Started | ✅ Complete | ❌ Failed

---

## Phase 5: Azure DevOps - Variable Groups

### Step 15: Create Variable Group - Dev

1. Navigate to **Pipelines** → **Library** → **+ Variable group**
2. Name: `{projectName}-dev-vars` (replace {projectName} with your config.naming.projectName value)
3. Add variables:

| Variable Name | Value | Secret? |
|--------------|-------|---------|
| `AZURE_AI_PROJECT_DEV` | `https://your-dev-project.api.azureml.ms` | ❌ No |
| `AZURE_OPENAI_ENDPOINT_DEV` | `https://your-dev-openai.openai.azure.com/` | ❌ No |
| `AZURE_OPENAI_KEY_DEV` | `your-dev-key` | ✅ Yes |
| `AZURE_OPENAI_API_VERSION_DEV` | `2024-02-15-preview` | ❌ No |
| `AZURE_OPENAI_DEPLOYMENT_DEV` | `gpt-4o` | ❌ No |
| `AZURE_SERVICE_CONNECTION_DEV` | `azure-foundry-dev` | ❌ No |

4. Click **Save**

**Status**: ⬜ Not Started | ✅ Complete | ❌ Failed

---

### Step 16: Create Variable Group - Test

Repeat Step 15 with:
- Name: `{projectName}-test-vars` (replace {projectName} with your config.naming.projectName value)
- Replace `DEV` with `TEST` in variable names
- Use test environment values

**Status**: ⬜ Not Started | ✅ Complete | ❌ Failed

---

### Step 17: Create Variable Group - Prod

Repeat Step 15 with:
- Name: `{projectName}-prod-vars` (replace {projectName} with your config.naming.projectName value)
- Replace `DEV` with `PROD` in variable names
- Use production environment values

**Status**: ⬜ Not Started | ✅ Complete | ❌ Failed

---

## Phase 6: Azure DevOps - Environments

### Step 18: Create Environment - Dev

1. Navigate to **Pipelines** → **Environments** → **New environment**
2. Name: `dev`
3. Resource: None
4. Click **Create**

**Status**: ⬜ Not Started | ✅ Complete | ❌ Failed

---

### Step 19: Create Environment - Test

Repeat Step 18:
- Name: `test`

**Status**: ⬜ Not Started | ✅ Complete | ❌ Failed

---

### Step 20: Create Environment - Production

1. Name: `production`
2. After creation, click on `production`
3. Click **⋮** → **Approvals and checks**
4. Click **Approvals**
5. Add required approvers
6. Set timeout: 7 days
7. Save

**Status**: ⬜ Not Started | ✅ Complete | ❌ Failed

---

## Phase 7: Azure DevOps - Pipelines

### Step 21: Create Agent Creation Pipeline

1. Navigate to **Pipelines** → **Pipelines** → **New pipeline**
2. Select **Azure Repos Git**
3. Select repository: `foundry-cicd`
4. Select **Existing Azure Pipelines YAML file**
5. Branch: `migration/reorganize-structure` (or `main` if merged)
6. Path: `/.azure-pipelines/create-agent-pipeline.yml`
7. Click **Continue** → **Save**
8. Rename to: `Foundry Agent Creation`

**Status**: ⬜ Not Started | ✅ Complete | ❌ Failed

---

### Step 22: Create Agent Testing Pipeline

Repeat Step 21:
- Path: `/.azure-pipelines/test-agent-pipeline.yml`
- Name: `Foundry Agent Testing`

**Status**: ⬜ Not Started | ✅ Complete | ❌ Failed

---

## Phase 8: Testing & Validation

### Step 23: Validate Repository Structure

Check in Azure DevOps Repos that structure looks like:
- [ ] `.azure-pipelines/` directory exists
- [ ] `src/agents/create_agent.py` exists
- [ ] `src/evaluation/evaluate_agent.py` exists
- [ ] `docs/` reorganized
- [ ] Old `cicd/` directory removed

**Status**: ⬜ Not Started | ✅ Complete | ❌ Failed

---

### Step 24: Test Pipeline - Dry Run

1. Go to **Pipelines** → **Foundry Agent Creation**
2. Click **Run pipeline**
3. Select branch: `migration/reorganize-structure`
4. Click **Run**
5. Monitor execution
6. Check for any errors

**Pipeline Run ID**: _________________________________

**Status**: ⬜ Not Started | ✅ Complete | ❌ Failed

---

### Step 25: Merge Migration Branch (Optional)

If pipeline succeeds and you want to merge:

```powershell
# Create Pull Request via Portal
# OR merge directly
git checkout main
git merge migration/reorganize-structure
git push azure main
```

**Status**: ⬜ Not Started | ✅ Complete | ❌ Failed

---

## Post-Migration Tasks

### Step 26: Configure Branch Policies

1. Go to **Project Settings** → **Repositories** → `foundry-cicd`
2. Click **Policies** tab
3. Under **Branch Policies**, select `main`
4. Configure:
   - [ ] Require minimum 2 reviewers
   - [ ] Check for linked work items
   - [ ] Check for comment resolution
   - [ ] Limit merge types to squash

**Status**: ⬜ Not Started | ✅ Complete | ❌ Failed

---

### Step 27: Document Changes

1. Update README.md with new structure
2. Update team wiki
3. Notify team of migration
4. Update onboarding docs

**Status**: ⬜ Not Started | ✅ Complete | ❌ Failed

---

### Step 28: Archive Old Repository

If migrating from GitHub, archive the original:
1. Go to GitHub repository settings
2. Scroll to "Danger Zone"
3. Click "Archive this repository"

**Status**: ⬜ Not Started | ✅ Complete | ❌ Failed

---

## Troubleshooting Reference

### Issue: Authentication Failed
**Solution**: Verify PAT token in environment variable, regenerate if needed

### Issue: Import Errors in Python
**Solution**: Ensure all `__init__.py` files created, check PYTHONPATH

### Issue: Pipeline Can't Find Scripts
**Solution**: Verify script paths updated in YAML files

### Issue: Service Connection Fails
**Solution**: Verify service principal credentials, check Azure role assignments

### Issue: Variable Group Not Accessible
**Solution**: Ensure "Grant access to all pipelines" is checked

---

## Success Criteria

✅ **Migration Complete When:**

- [ ] Repository exists in Azure DevOps
- [ ] All files reorganized correctly
- [ ] Service connections working for all environments
- [ ] Variable groups created with correct values
- [ ] Environments created (with prod approval gates)
- [ ] Both pipelines created and saved
- [ ] Test pipeline run succeeds
- [ ] Team has access and understands new structure
- [ ] Documentation updated

---

## Timeline Tracker

| Phase | Estimated Time | Actual Time | Status |
|-------|----------------|-------------|--------|
| Pre-Migration Setup | 30 min | _____ | ⬜ |
| Phase 1: Local Prep | 15 min | _____ | ⬜ |
| Phase 2: Reorganization | 30 min | _____ | ⬜ |
| Phase 3: Create Repo | 10 min | _____ | ⬜ |
| Phase 4: Service Connections | 20 min | _____ | ⬜ |
| Phase 5: Variable Groups | 30 min | _____ | ⬜ |
| Phase 6: Environments | 15 min | _____ | ⬜ |
| Phase 7: Pipelines | 20 min | _____ | ⬜ |
| Phase 8: Testing | 30 min | _____ | ⬜ |
| Post-Migration | 30 min | _____ | ⬜ |
| **TOTAL** | **4-5 hours** | **_____** | ⬜ |

---

## Notes & Issues

_Use this space to document any issues encountered, deviations from the plan, or important notes:_

---

**Checklist Version**: 1.0  
**Date Started**: _____________  
**Date Completed**: _____________  
**Completed By**: _____________
