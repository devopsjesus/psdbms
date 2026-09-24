Class gh_repository
{
	[ValidateNotNullOrEmpty()]
	[string]
	$gh_repository_id

	[ValidateNotNullOrEmpty()]
	[string]
	$gh_repository_name

	gh_repository () {}

	gh_repository ([hashtable]$Properties) {
		foreach ($property in $Properties.Keys) {
			$this.$property = $Properties[$property]
		}
	}
}