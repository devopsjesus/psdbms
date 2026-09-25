Import-Module '.\psdbms\psdbms.psd1'

Write-Output "Initializing datastore."
$OVERWRITE_DATASTORE = $false

# Example credential definition
$credentialDefinition = @{
    gh_repository_id                 = '12345676532'
    az_subscription_id               = '12345678-1234-1234-1234-123456789012'
    az_subscription_name             = 'subscription-name'
    az_service_principal_id          = '6340792e-2589-46f1-a693-1d6e64d52c13'
    az_service_principal_name        = 'sp-name'
    az_service_principal_secr_kv_ref = "https://example.test/secrets/test-secret"
    gh_repo_environment_name         = 'environment-name'
    gh_repository_name               = 'repository-name'
}


# Example: Adding an Azure service principal entity
$spData = @{
    az_service_principal_id          = $credentialDefinition.az_service_principal_id
    az_service_principal_name        = $credentialDefinition.az_service_principal_name
    az_service_principal_secr_kv_ref = $credentialDefinition.az_service_principal_secr_kv_ref
}
$spSchema = New-PsEntitySchema -SchemaPath '.\schemas\az_service_principal.json'
$spEntity = New-PsEntity -Schema $spSchema
$spEntity.Create($OVERWRITE_DATASTORE)
$null = $spEntity.Add($spData)


# Example: Adding an Azure subscription entity
$subData = @{
    az_subscription_id   = $credentialDefinition.az_subscription_id
    az_subscription_name = $credentialDefinition.az_subscription_name
}
$subSchema = New-PsEntitySchema -SchemaPath '.\schemas\az_subscription.json'
$subEntity = New-PsEntity -Schema $subSchema
$subEntity.Create($OVERWRITE_DATASTORE)
$null = $subEntity.Add($subData)


# Example: Adding a GitHub repository environment entity
$ghRepoEnvData = @{
    gh_repo_environment_name = $credentialDefinition.gh_repo_environment_name
}
$ghRepoEnvSchema = New-PsEntitySchema -SchemaPath '.\schemas\gh_repo_environment.json'
$ghRepoEnvEntity = New-PsEntity -Schema $ghRepoEnvSchema
$ghRepoEnvEntity.Create($OVERWRITE_DATASTORE)
$ghRepoEnvCreationResult = $ghRepoEnvEntity.Add($ghRepoEnvData)


# Example: Adding a GitHub repository entity
$ghRepoData = @{
    gh_repository_id   = $credentialDefinition.gh_repository_id
    gh_repository_name = $credentialDefinition.gh_repository_name
}
$ghRepoSchema = New-PsEntitySchema -SchemaPath '.\schemas\gh_repository.json'
$ghRepoEntity = New-PsEntity -Schema $ghRepoSchema
$ghRepoEntity.Create($OVERWRITE_DATASTORE)
$null = $ghRepoEntity.Add($ghRepoData)


# Example: Adding a GitHub credential entity based on Azure service principal
$ghCredData = @{
    gh_az_credential_id     = $credentialDefinition.gh_az_credential_id
    gh_repository_id        = $credentialDefinition.gh_repository_id
    gh_repo_environment_id  = $ghRepoEnvCreationResult.gh_repo_environment_id
    az_subscription_id      = $credentialDefinition.az_subscription_id
    az_service_principal_id = $credentialDefinition.az_service_principal_id
}
$ghCredSchema = New-PsEntitySchema -SchemaPath '.\schemas\gh_az_credential.json'
$ghCredEntity = New-PsEntity -Schema $ghCredSchema
$ghCredEntity.Create($OVERWRITE_DATASTORE)
$newCredentialRecord = $ghCredEntity.Add($ghCredData)

Write-Output "Newly created credential:"
$ghCredEntity.Find($newCredentialRecord.gh_az_credential_id)

Write-Output "Running query script on newly created credential."
. ./query-things.ps1 -Id $newCredentialRecord.gh_az_credential_id
