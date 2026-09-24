using module './psdbms.psd1'

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
$spSchema = [PsEntitySchema]::new('.\schemas\az_service_principal.json')
$spEntity = [PsEntity]::new($spSchema)
$spEntity.Add($spData)


# Example: Adding an Azure subscription entity
$subData = @{
    az_subscription_id   = $credentialDefinition.az_subscription_id
    az_subscription_name = $credentialDefinition.az_subscription_name
}
$subSchema = [PsEntitySchema]::new('.\schemas\az_subscription.json')
$subEntity = [PsEntity]::new($subSchema)
$subEntity.Add($subData)

# Example: Adding a GitHub repository environment entity
$ghRepoEnvData = @{
    gh_repo_environment_name = $credentialDefinition.gh_repo_environment_name
}
$ghRepoEnvSchema = [PsEntitySchema]::new('.\schemas\gh_repo_environment.json')
$ghRepoEnvEntity = [PsEntity]::new($ghRepoEnvSchema)
$gh_repo_environment = $ghRepoEnvEntity.Add($ghRepoEnvData)


# Example: Adding a GitHub repository entity
$ghRepoData = @{
    gh_repository_id   = $credentialDefinition.gh_repository_id
    gh_repository_name = $credentialDefinition.gh_repository_name
}
$ghRepoSchema = [PsEntitySchema]::new('.\schemas\gh_repository.json')
$ghRepoEntity = [PsEntity]::new($ghRepoSchema)
$ghRepoEntity.Add($ghRepoData)

# Example: Adding a GitHub credential entity based on Azure service principal
$ghCredData = @{
    gh_az_credential_id     = $credentialDefinition.gh_az_credential_id
    gh_repository_id        = $credentialDefinition.gh_repository_id
    gh_repo_environment_id  = $gh_repo_environment.gh_repo_environment_id
    az_subscription_id      = $credentialDefinition.az_subscription_id
    az_service_principal_id = $credentialDefinition.az_service_principal_id
}
$ghCredSchema = [PsEntitySchema]::new('.\schemas\gh_az_credential.json')
$ghCredEntity = [PsEntity]::new($ghCredSchema)
$ghCredEntity.Add($ghCredData)


$gh_az_credential = [psentity]::Open('.\schemas\gh_az_credential.json')
$gh_az_credential.Data
