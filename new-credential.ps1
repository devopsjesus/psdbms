$env:AZURE_TENANT_ID = 'e77268c3-357d-4cfd-9247-3988e7c9f4f6'
$env:AZURE_KEY_VAULT_NAME = 'examplekvname'

Import-Module '.\psdbms\psdbms.psd1'


# Example credential definition
$credentialDefinition = @{
    gh_repository_id                 = Get-Random -Minimum 1000000000 -Maximum 9999999999
    az_subscription_id               = (New-Guid).Guid
    az_subscription_name             = 'new-solution-sub'
    az_service_principal_id          = (New-Guid).Guid
    az_service_principal_name        = 'new-solution-sp'
    gh_repo_environment_name         = 'prod'
    gh_repository_name               = 'new-solution-repo'
}


# Example: Adding an Azure service principal entity
$spData = @{
    az_service_principal_id   = $credentialDefinition.az_service_principal_id
    az_service_principal_name = $credentialDefinition.az_service_principal_name
}
$spSchema = Get-PsEntitySchema -SchemaPath '.\schemas\az_service_principal.json'
$spEntity = Get-PsEntity -Schema $spSchema
$null = $spEntity.Add($spData)


# Example: Adding an Azure subscription entity
$subData = @{
    az_subscription_id   = $credentialDefinition.az_subscription_id
    az_subscription_name = $credentialDefinition.az_subscription_name
}
$subSchema = Get-PsEntitySchema -SchemaPath '.\schemas\az_subscription.json'
$subEntity = Get-PsEntity -Schema $subSchema
$null = $subEntity.Add($subData)

# Example: Retrieving an existing GitHub repository environment entity
$ghRepoEnvSchema = Get-PsEntitySchema -SchemaPath '.\schemas\gh_repo_environment.json'
$ghRepoEnvEntity = Get-PsEntity -Schema $ghRepoEnvSchema
$ghRepoEnvRecord = $ghRepoEnvEntity.Find(@{gh_repo_environment_name = $credentialDefinition.gh_repo_environment_name})

# Example: Adding a GitHub repository entity
$ghRepoData = @{
    gh_repository_id   = $credentialDefinition.gh_repository_id
    gh_repository_name = $credentialDefinition.gh_repository_name
}
$ghRepoSchema = Get-PsEntitySchema -SchemaPath '.\schemas\gh_repository.json'
$ghRepoEntity = Get-PsEntity -Schema $ghRepoSchema
$null = $ghRepoEntity.Add($ghRepoData)


# Example: Adding a GitHub credential entity based on Azure service principal
$ghCredData = @{
    gh_repository_id        = $credentialDefinition.gh_repository_id
    gh_repo_environment_id  = $ghRepoEnvRecord.gh_repo_environment_id
    az_subscription_id      = $credentialDefinition.az_subscription_id
    az_service_principal_id = $credentialDefinition.az_service_principal_id
}
$ghCredSchema = Get-PsEntitySchema -SchemaPath '.\schemas\gh_az_credential.json'
$ghCredEntity = Get-PsEntity -Schema $ghCredSchema
$newCredentialRecord = $ghCredEntity.Add($ghCredData)

Write-Output "Newly created credential:"
$ghCredEntity.Find($newCredentialRecord.gh_az_credential_id)

Write-Output "Running query script on newly created credential."
. ./query-things.ps1 -Id $newCredentialRecord.gh_az_credential_id
