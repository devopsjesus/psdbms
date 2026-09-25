@{
    RootModule        = 'psdbms.psm1'
    ModuleVersion     = '0.2.0'
    GUID              = '6e33aefe-ef71-4f0b-9b36-d79b8898f13e'
    Author            = 'devopsjesus'
    Description       = 'A fun project that probably won`t go anywhere, but you know what, I need a lightweight type of solution for storing and accessing data using powershell. So sue me.'
    PowerShellVersion = '7.0'
    CompatiblePSEditions = @('Core')

    FunctionsToExport = @(
        'New-PsEntitySchema'
        'New-PsEntity'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    FileList = @(
        'psdbms.psm1'
    )

    PrivateData = @{
        PSData = @{
            Tags = @('PowerShell', 'Database')
        }
    }
}
