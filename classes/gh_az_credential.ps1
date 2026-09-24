Class gh_az_credential
{
	[ValidateNotNullOrEmpty()]
	[string]
	$gh_az_credential_id

	[ValidateNotNullOrEmpty()]
	[string]
	$gh_repository_id

	[ValidateNotNullOrEmpty()]
	[string]
	$gh_repo_environment_id

	[ValidateNotNullOrEmpty()]
	[string]
	$az_subscription_id

	[ValidateNotNullOrEmpty()]
	[string]
	$az_service_principal_id

	gh_az_credential () {}

	gh_az_credential ([hashtable]$Properties) {
		foreach ($property in $Properties.Keys) {
			$this.$property = $Properties[$property]
		}
	}
}