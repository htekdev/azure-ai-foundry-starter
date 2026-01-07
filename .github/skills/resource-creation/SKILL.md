---
name: resource-creation
description: Creates and configures Azure resources required for the Azure AI Foundry starter deployment including Service Principals, AI Foundry projects, and proper RBAC configuration. Use this when setting up Azure infrastructure, creating missing resources, or configuring resource permissions for deployment.
---

# Azure Resource Creation for Azure AI Foundry Starter

This skill automates the creation of Azure resources required for the Azure AI Foundry starter template deployment. It checks for resource existence before creating and ensures proper configuration.

## When to use this skill

Use this skill when you need to:
- Create Azure resources required for AI agent deployment
- Set up Service Principals with proper RBAC permissions (Contributor + Cognitive Services User)
- Create Azure AI Foundry projects
- Configure resource access and permissions
- Verify resource configuration before deployment

## Resources managed by this skill

### 1. Service Principal
- Creates Service Principal for workload identity federation
- Assigns Contributor role to resource group
- Assigns Cognitive Services User role (required for AI Foundry)
- Configures federated credentials for Azure DevOps

### 2. Azure AI Foundry Project
- Creates or validates AI Foundry project
- Configures project endpoints for dev/test/prod
- Sets up project permissions
- Enables agent deployment capabilities

### 3. Supporting Resources
- Resource groups
- Role assignments (RBAC)
- Federated identity credentials

**Note**: This is a starter template - AI Foundry projects should typically be created through the Azure portal first, then referenced in configuration.

## Resource creation process

**💡 Recommended**: Use configuration management for consistent naming:

```powershell
# Load configuration functions
. ./.github/skills/configuration-management/config-functions.ps1

# Get configuration
$config = Get-MigrationConfig

# Extract Azure resource names
$rgName = $config.azure.resourceGroupName
$location = $config.azure.location
$spName = $config.servicePrincipal.name
$mlWorkspace = $config.azure.mlWorkspaceName
$openAIService = $config.azure.openAIServiceName
```

### Step 1: Check existing resources

Before creating any resources, verify what already exists:

```powershell
# Load configuration
. ./.github/skills/configuration-management/config-functions.ps1
$config = Get-MigrationConfig

# Check Service Principal
az ad sp list --display-name $config.servicePrincipal.name --query "[].{Name:displayName, AppId:appId}" -o table

# Check resource group
az group show --name $config.azure.resourceGroupName

# Check ML workspace
az ml workspace show --resource-group $config.azure.resourceGroupName --workspace-name $config.azure.mlWorkspaceName

# Check OpenAI service
az cognitiveservices account show --resource-group $config.azure.resourceGroupName --name $config.azure.openAIServiceName
```

### Step 2: Create missing resources

Use the resource creation script with configuration:

```powershell
# Load configuration
. ./.github/skills/configuration-management/config-functions.ps1
$config = Get-MigrationConfig

# Create resources using configuration values
cd .github/skills/resource-creation
./create-resources.ps1 `
  -ResourceGroupName $config.azure.resourceGroupName `
  -Location $config.azure.location `
  -ServicePrincipalName $config.servicePrincipal.name `
  -MLWorkspaceName $config.azure.mlWorkspaceName `
  -OpenAIServiceName $config.azure.openAIServiceName `
  -CreateServicePrincipal $true `
  -CreateMLWorkspace $true `
  -CreateOpenAI $true
```

### Step 3: Verify resource creation

After creation, verify all resources are properly configured:

```powershell
# Verify Service Principal
az ad sp show --id $(az ad sp list --display-name "migration-sp" --query "[0].appId" -o tsv)

# Verify RBAC assignment
az role assignment list --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/northwind-ml-rg" --query "[?principalType=='ServicePrincipal'].{Principal:principalName, Role:roleDefinitionName}" -o table

# Verify ML workspace
az ml workspace show --resource-group "northwind-ml-rg" --workspace-name "northwind-ml-workspace" --query "{Name:name, Location:location, State:provisioningState}" -o table

# Verify OpenAI deployments
az cognitiveservices account deployment list --resource-group "northwind-ml-rg" --name "northwind-openai" -o table
```

### Step 4: Save credentials securely

Store Service Principal credentials in Azure Key Vault or secure location:

```powershell
# Get Service Principal credentials
$spCredentials = az ad sp create-for-rbac --name "migration-sp" --role Contributor --scopes "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/northwind-ml-rg" | ConvertFrom-Json

# Store in Key Vault (recommended)
az keyvault secret set --vault-name "northwind-keyvault" --name "migration-sp-appid" --value $spCredentials.appId
az keyvault secret set --vault-name "northwind-keyvault" --name "migration-sp-password" --value $spCredentials.password
az keyvault secret set --vault-name "northwind-keyvault" --name "migration-sp-tenant" --value $spCredentials.tenant

# Or save to secure file (for testing only)
$spCredentials | ConvertTo-Json | Out-File -FilePath "sp-credentials.json" -Encoding UTF8
Write-Host "⚠️ WARNING: Store sp-credentials.json securely and delete after use!"
```

## Service Principal creation

### Create with Contributor role

```powershell
# Create Service Principal with Contributor role on resource group
az ad sp create-for-rbac `
  --name "migration-sp" `
  --role "Contributor" `
  --scopes "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/northwind-ml-rg" `
  --query "{appId:appId, password:password, tenant:tenant}" `
  -o json
```

### Assign additional roles if needed

```powershell
# Get Service Principal object ID
$spObjectId = az ad sp list --display-name "migration-sp" --query "[0].id" -o tsv

# Assign Machine Learning Workspace Contributor role
az role assignment create `
  --assignee $spObjectId `
  --role "AzureML Workspace Contributor" `
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/northwind-ml-rg"

# Assign Cognitive Services Contributor role
az role assignment create `
  --assignee $spObjectId `
  --role "Cognitive Services Contributor" `
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/northwind-ml-rg"
```

## ML Workspace creation

### Create workspace with all dependencies

```powershell
# Create ML workspace (automatically creates storage, key vault, app insights)
az ml workspace create `
  --resource-group "northwind-ml-rg" `
  --name "northwind-ml-workspace" `
  --location "eastus" `
  --description "ML workspace for repository migration" `
  --public-network-access Enabled `
  --query "{Name:name, Location:location, State:provisioningState}" `
  -o table

# Wait for workspace to be ready
az ml workspace show `
  --resource-group "northwind-ml-rg" `
  --workspace-name "northwind-ml-workspace" `
  --query "provisioningState" `
  -o tsv
```

### Configure workspace features

```powershell
# Enable features if needed
az ml workspace update `
  --resource-group "northwind-ml-rg" `
  --name "northwind-ml-workspace" `
  --public-network-access Enabled `
  --allow-public-access-when-behind-vnet true
```

## OpenAI Service creation

### Create OpenAI service

```powershell
# Create Cognitive Services account for OpenAI
az cognitiveservices account create `
  --resource-group "northwind-ml-rg" `
  --name "northwind-openai" `
  --location "eastus" `
  --kind "OpenAI" `
  --sku "S0" `
  --custom-domain "northwind-openai" `
  --query "{Name:name, Location:location, State:properties.provisioningState}" `
  -o table

# Wait for deployment to complete
Start-Sleep -Seconds 30
```

### Deploy OpenAI models

```powershell
# Deploy GPT-4 model
az cognitiveservices account deployment create `
  --resource-group "northwind-ml-rg" `
  --name "northwind-openai" `
  --deployment-name "gpt-4" `
  --model-name "gpt-4" `
  --model-version "turbo-2024-04-09" `
  --model-format "OpenAI" `
  --sku-capacity 10 `
  --sku-name "Standard"

# Deploy GPT-3.5-turbo model
az cognitiveservices account deployment create `
  --resource-group "northwind-ml-rg" `
  --name "northwind-openai" `
  --deployment-name "gpt-35-turbo" `
  --model-name "gpt-35-turbo" `
  --model-version "0125" `
  --model-format "OpenAI" `
  --sku-capacity 10 `
  --sku-name "Standard"

# Verify deployments
az cognitiveservices account deployment list `
  --resource-group "northwind-ml-rg" `
  --name "northwind-openai" `
  --query "[].{Name:name, Model:properties.model.name, State:properties.provisioningState}" `
  -o table
```

### Get OpenAI endpoint and keys

```powershell
# Get endpoint
az cognitiveservices account show `
  --resource-group "northwind-ml-rg" `
  --name "northwind-openai" `
  --query "properties.endpoint" `
  -o tsv

# Get API keys
az cognitiveservices account keys list `
  --resource-group "northwind-ml-rg" `
  --name "northwind-openai" `
  --query "{Key1:key1, Key2:key2}" `
  -o json
```

## Resource Group creation

### Create resource group if it doesn't exist

```powershell
# Check if resource group exists
$rgExists = az group exists --name "northwind-ml-rg"

if ($rgExists -eq "false") {
    # Create resource group
    az group create `
      --name "northwind-ml-rg" `
      --location "eastus" `
      --tags "Environment=Production" "Project=Migration" `
      --query "{Name:name, Location:location, State:properties.provisioningState}" `
      -o table
    
    Write-Host "✅ Resource group created successfully"
} else {
    Write-Host "✅ Resource group already exists"
}
```

## Troubleshooting

### Service Principal creation fails
```powershell
# Check if SP already exists
az ad sp list --display-name "migration-sp" --query "[].{Name:displayName, AppId:appId}" -o table

# If exists, delete and recreate
$appId = az ad sp list --display-name "migration-sp" --query "[0].appId" -o tsv
if ($appId) {
    az ad sp delete --id $appId
    Write-Host "Deleted existing Service Principal"
}
```

### ML Workspace creation fails
```powershell
# Check quota limits
az ml quota list --resource-group "northwind-ml-rg" --location "eastus"

# Check if name is available
az ml workspace show --resource-group "northwind-ml-rg" --workspace-name "northwind-ml-workspace" 2>&1

# Try different location if region doesn't support ML
az account list-locations --query "[?metadata.regionType=='Physical'].{Name:name, DisplayName:displayName}" -o table
```

### OpenAI Service creation fails
```powershell
# Check OpenAI availability in region
az cognitiveservices account list-kinds --query "[?kind=='OpenAI']" -o table

# Check if name is available
az cognitiveservices account check-name-availability --name "northwind-openai" --type "Microsoft.CognitiveServices/accounts"

# List available SKUs
az cognitiveservices account list-skus --kind OpenAI --location "eastus" -o table
```

### Deployment quota exceeded
```powershell
# Check current deployments
az cognitiveservices account deployment list --resource-group "northwind-ml-rg" --name "northwind-openai" -o table

# Delete unused deployments
az cognitiveservices account deployment delete --resource-group "northwind-ml-rg" --name "northwind-openai" --deployment-name "old-model"

# Request quota increase through Azure Portal
Write-Host "If quota exceeded, request increase at: https://portal.azure.com/#view/Microsoft_Azure_Support/HelpAndSupportBlade"
```

## Best practices

### Security
- Store Service Principal credentials in Azure Key Vault
- Use managed identities when possible
- Rotate credentials regularly
- Apply least privilege access principle
- Enable diagnostic logging on all resources

### Naming conventions
- Use consistent naming: `{project}-{resource-type}-{env}`
- Examples: `northwind-ml-workspace`, `northwind-openai`
- Include environment tags: `Production`, `Development`, `Test`

### Cost management
- Use appropriate SKUs (S0 for production, F0 for dev/test)
- Set quota limits on OpenAI deployments
- Enable auto-shutdown for ML compute when not in use
- Monitor resource usage with Azure Cost Management

### Resource organization
- Group related resources in same resource group
- Use consistent locations/regions
- Apply tags for cost tracking and management
- Document resource dependencies

## Integration with migration workflow

This skill should be used early in the migration process:

1. **Before migration**: Create all required resources
2. **During setup**: Configure Service Principal and RBAC
3. **Before execution**: Verify all resources are accessible
4. **After migration**: Validate resource configurations

## Automation examples

### Create all resources in one command
```powershell
./create-resources.ps1 `
  -ResourceGroupName "northwind-ml-rg" `
  -Location "eastus" `
  -ServicePrincipalName "migration-sp" `
  -MLWorkspaceName "northwind-ml-workspace" `
  -OpenAIServiceName "northwind-openai" `
  -CreateAll $true `
  -OutputFormat json
```

### Create only missing resources
```powershell
./create-resources.ps1 `
  -ResourceGroupName "northwind-ml-rg" `
  -CheckExisting $true `
  -SkipIfExists $true
```

## Related resources

- [COPILOT_EXECUTION_GUIDE.md](../../../COPILOT_EXECUTION_GUIDE.md) - Complete migration process
- [environment-validation/SKILL.md](../environment-validation/SKILL.md) - Environment validation skill
- [create-resources.ps1](./create-resources.ps1) - Resource creation script
- [Azure ML CLI Reference](https://learn.microsoft.com/en-us/cli/azure/ml)
- [Azure OpenAI Service Documentation](https://learn.microsoft.com/en-us/azure/ai-services/openai/)
