Class az_service_principal
{
	[ValidateNotNullOrEmpty()]
	[string]
	$az_service_principal_id

	[ValidateNotNullOrEmpty()]
	[string]
	$az_service_principal_name

	[ValidateNotNullOrEmpty()]
	[string]
	$az_service_principal_secr_kv_ref

	hidden [string] $data_source = $env:DATA_SOURCE ? $env:DATA_SOURCE : [System.IO.Path]::GetFullPath("$PSScriptRoot\..\data\az_service_principal.csv")

	az_service_principal () {}

	az_service_principal ([hashtable]$Properties) {
		foreach ($property in $Properties.Keys) {
			$this.$property = $Properties[$property]
		}
	}

	static [bool] ValidateDataSource([string]$data_source) {
		$data_source_exists = Test-Path -Path $data_source
		if (-not ($data_source_exists)) {
			Write-Warning "Data source path '$data_source' was not found, object cannot be written to any data store."
			Write-Warning 'Use the environment variable "DATA_SOURCE" to specify a valid data source path.'
			Write-Warning 'Alternatively, pass in a valid data source path using the "data_source" property.'
			Write-Warning 'EXAMPLE: $testSp.Add(".\data\az_service_principal.csv")'

			Write-Error "Data source path '$data_source' was not found." -Category ObjectNotFound -ErrorAction Stop
		}
		return $data_source_exists
	}

	[string] Add() {
		$connectionValid = [az_service_principal]::ValidateDataSource($this.data_source)
		Write-Verbose "Data source connection valid: $connectionValid"

		return "Data added teehee..."
	}

	[string] Add([string]$data_source) {
		$connectionValid = [az_service_principal]::ValidateDataSource($data_source)
		Write-Verbose "Data source connection valid: $connectionValid"

		return "Data added teehee..."
	}
}