@{
    RootModule        = 'psdbms.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '6e33aefe-ef71-4f0b-9b36-d79b8898f13e'
    Author            = 'devopsjesus'
    Description       = 'A fun project that probably won`t go anywhere, but you know what, I need a lightweight type of solution for storing and accessing data using powershell. So sue me. Most of this was written from my brain, not a bot. But the bots helped with the mundane boring shtuff.'
    PowerShellVersion = '7.0'
    CompatiblePSEditions = @('Core')

    ScriptsToProcess = @(
        'classes\az_service_principal.ps1'
        'classes\az_subscription.ps1'
        'classes\gh_repository.ps1'
        'classes\gh_repo_environment.ps1'
        'classes\gh_az_credential.ps1'
    )

    FunctionsToExport = @()
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    FileList = @(
        'psdbms.psm1'
        'classes\az_service_principal.ps1'
        'classes\az_subscription.ps1'
        'classes\gh_az_credential.ps1'
        'classes\gh_repository.ps1'
        'classes\gh_repo_environment.ps1'
        'data\az_service_principal.csv'
        'data\az_subscription.csv'
        'data\gh_az_credential.csv'
        'data\gh_repository.csv'
        'data\gh_repo_environment.csv'
    )

    PrivateData = @{
        PSData = @{
            Tags = @('PowerShell', 'Database')
        }
    }
}