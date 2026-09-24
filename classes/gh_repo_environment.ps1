Class gh_repo_environment
{
	[ValidateNotNullOrEmpty()]
	[string]
	$gh_repo_environment_id

	[ValidateNotNullOrEmpty()]
	[string]
	$gh_repo_environment_name

	gh_repo_environment () {}

	gh_repo_environment ([hashtable]$Properties) {
		foreach ($property in $Properties.Keys) {
			$this.$property = $Properties[$property]
		}
	}
}