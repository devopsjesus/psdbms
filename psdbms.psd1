@{
    RootModule        = 'psdbms.psm1'
    ModuleVersion     = '0.2.0'
    GUID              = '6e33aefe-ef71-4f0b-9b36-d79b8898f13e'
    Author            = 'devopsjesus'
    Description       = 'A fun project that probably won`t go anywhere, but you know what, I need a lightweight type of solution for storing and accessing data using powershell. So sue me.'
    PowerShellVersion = '7.0'
    CompatiblePSEditions = @('Core')

    ScriptsToProcess = @(
        'classes\ps_entity.ps1'
    )

    FunctionsToExport = @()
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    FileList = @(
        'psdbms.psm1'
        'classes\ps_entity.ps1'
        'data\az_service_principal.csv'
        'data\az_subscription.csv'
        'data\gh_az_credential.csv'
        'data\gh_repository.csv'
        'data\gh_repo_environment.csv'
        'schemas\az_service_principal.json'
        'schemas\az_subscription.json'
        'schemas\gh_az_credential.json'
        'schemas\gh_repository.json'
        'schemas\gh_repo_environment.json'
    )

    PrivateData = @{
        PSData = @{
            Tags = @('PowerShell', 'Database')
        }
    }
}