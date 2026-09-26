param(
    [string]$Id
)

$env:AZURE_TENANT_ID = 'e77268c3-357d-4cfd-9247-3988e7c9f4f6'

Import-Module '.\psdbms\psdbms.psd1'

# Example: Querying the Credential entity's referenced rows to return related information
$ghCredEntitySchema = Get-PsEntitySchema -SchemaPath '.\schemas\gh_az_credential.json'
$ghCredEntity = $ghCredEntitySchema | Get-PsEntity
$newCredentialRecord = $ghCredEntity.Find($Id)

$ghRepoEnvName = $ghCredEntity.GetReferencedRowByKey('gh_repo_environment_id', $newCredentialRecord.gh_repo_environment_id).gh_repo_environment_name
$spName = $ghCredEntity.GetReferencedRowByKey('az_service_principal_id', $newCredentialRecord.az_service_principal_id).az_service_principal_name

$credBuilder = @{
    client_id        = $newCredentialRecord.az_service_principal_id
    subscription_id  = $newCredentialRecord.az_subscription_id
    tenant_id        = $env:AZURE_TENANT_ID
    repository_id    = $newCredentialRecord.gh_repository_id
    environment_name = $ghRepoEnvName
    secret_name      = $spName
}

Write-Output "Credential object built by referencing the credential's related entities:"
$credBuilder | Format-Table

# Example: Querying all unique repository IDs associated with a specific service principal ID
# $ghCredEntity.Find(@{
#     az_service_principal_id = $newCredentialRecord.az_service_principal_id
# }) | Select-Object -ExpandProperty gh_repository_id -Unique
