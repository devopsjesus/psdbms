Class az_subscription
{
	[ValidateNotNullOrEmpty()]
	[string]
	$az_subscription_id

	[ValidateNotNullOrEmpty()]
	[string]
	$az_subscription_name

	az_subscription () {}

	az_subscription ([hashtable]$Properties) {
		foreach ($property in $Properties.Keys) {
			$this.$property = $Properties[$property]
		}
	}
}