# Federated Credentials Skill

Manages federated credentials for Azure DevOps service connections using Workload Identity Federation.

## Purpose

This skill ensures that Service Principal federated credentials match the actual issuer and subject values from Azure DevOps service connections. This is critical for pipeline authentication.

## Key Principle

**NEVER guess or construct the issuer/subject format.** Always retrieve the actual values from Azure DevOps service connections via REST API.

## Quick Usage

```powershell
# Fix all federated credentials
./.github/skills/federated-credentials/fix-federated-credentials.ps1

# Fix specific environments only
./.github/skills/federated-credentials/fix-federated-credentials.ps1 -Environments @("dev", "test")

# Fix credentials without RBAC update
./.github/skills/federated-credentials/fix-federated-credentials.ps1 -SkipRbac
```

## What It Does

1. **Retrieves** actual issuer and subject from Azure DevOps service connections
2. **Deletes** old federated credentials with incorrect format
3. **Creates** new federated credentials with correct values
4. **Adds** Cognitive Services User role for data plane access
5. **Verifies** all credentials are properly configured

## Files

- `SKILL.md` - Complete documentation and troubleshooting guide
- `fix-federated-credentials.ps1` - PowerShell script to fix credentials
- `README.md` - This file

## Related Documentation

- [LESSONS_LEARNED.md](../../../docs/LESSONS_LEARNED.md) - Lesson #1: Why format matters
- [troubleshooting.md](../../../docs/troubleshooting.md) - Authentication issues

## Common Issues

### Issue: "argument --id: expected one argument"

Use JSON file instead of inline parameters. The script handles this correctly.

### Issue: Pipeline still fails after fixing

Check RBAC permissions. Service Principal needs:
- Contributor role (control plane)
- Cognitive Services User role (data plane)

The script adds both automatically unless `-SkipRbac` is specified.

## Success Criteria

✅ Issuer format: `https://login.microsoftonline.com/{tenantId}/v2.0`  
✅ Subject format: `/eid1/c/pub/t/.../sc/{serviceConnectionId}`  
✅ Audiences: `["api://AzureADTokenExchange"]`  
✅ Pipeline authenticates successfully  
✅ No secrets or passwords stored
