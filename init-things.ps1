using module './psdbms.psd1'
# Import-Module (Join-Path $PSScriptRoot 'psdbms.psd1') -ErrorAction Stop

$az_service_principal = @{
    az_service_principal_id = "6340792e-2589-46f1-a693-1d6e64d52c13"
    az_service_principal_name = "S_TEST_SOLUTION"
    az_service_principal_secr_kv_ref = "https://test-kv.vault.usgovcloudapi.net/secrets/test/stringofcharsbecauseitsnotasecretbutvscodethinksitis"
}
$VerbosePreference = "Continue"
$WarningPreference = "Continue"
[az_service_principal]::New($az_service_principal)
$VerbosePreference = "SilentlyContinue"
$WarningPreference = "SilentlyContinue"
