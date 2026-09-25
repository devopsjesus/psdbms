class PsDataColumn
{
	[ValidateNotNullOrEmpty()]
	[string] $Name

	[ValidateSet('string', 'int', 'long', 'decimal', 'double', 'bool', 'datetime', 'guid', 'uri')]
	[string] $Type = 'string'

	[bool] $Required = $false
	[bool] $Key = $false
	[bool] $Unique = $false
	[bool] $Generated = $false
	[string] $References

	PsDataColumn([System.Collections.IDictionary] $Properties) {
		foreach ($property in $Properties.Keys) {
			$this.$property = $Properties[$property]
		}

		if ($this.Name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
			throw "Column name '$($this.Name)' must contain only letters, numbers, and underscores, and cannot start with a number."
		}

		if ($this.Key) {
			$this.Required = $true
			$this.Unique = $true
		}

		if ($this.Generated -and -not $this.Key) {
			throw "Generated column '$($this.Name)' must be a key."
		}
		if ($this.Generated -and $this.Type -notin @('string', 'guid', 'int', 'long')) {
			throw "Generated column '$($this.Name)' must use type string, guid, int, or long."
		}
	}
}

class PsUniqueGroup
{
	[ValidateNotNullOrEmpty()]
	[string[]] $Columns

	PsUniqueGroup([object] $Definition) {
		$columnNames = if ($Definition -is [System.Collections.IDictionary]) {
			$Definition['Columns']
		}
		elseif ($Definition.PSObject.Properties.Name -contains 'Columns') {
			$Definition.Columns
		}
		else {
			$Definition
		}
		$this.Columns = @($columnNames | ForEach-Object { [string] $_ })
		if ($this.Columns.Count -lt 2) {
			throw 'A unique group must contain at least two columns.'
		}
		if (@($this.Columns | Group-Object | Where-Object Count -gt 1).Count -gt 0) {
			throw 'A unique group cannot contain duplicate columns.'
		}
	}
}

class PsEntitySchema
{
	[ValidateNotNullOrEmpty()]
	[string] $Name

	[ValidateNotNullOrEmpty()]
	[string] $Path

	[ValidateNotNullOrEmpty()]
	[PsDataColumn[]] $Columns

	[PsUniqueGroup[]] $UniqueGroups = @()

	PsEntitySchema([string] $SchemaPath) {
		$this.LoadSchema($SchemaPath, $null)
	}

	PsEntitySchema([string] $SchemaPath, [string] $DataPath) {
		$this.LoadSchema($SchemaPath, $DataPath)
	}

	PsEntitySchema([string] $Name, [string] $Path, [object[]] $Columns) {
		$this.Initialize($Name, $Path, $Columns, @())
	}

	PsEntitySchema([string] $Name, [string] $Path, [object[]] $Columns, [object[]] $UniqueGroups) {
		$this.Initialize($Name, $Path, $Columns, $UniqueGroups)
	}

	hidden [void] LoadSchema([string] $SchemaPath, [string] $DataPath) {
		$schemaFile = (Resolve-Path -LiteralPath $SchemaPath -ErrorAction Stop).Path
		$configuration = Get-Content -LiteralPath $schemaFile -Raw | ConvertFrom-Json
		if (-not $configuration.Name -or -not $configuration.Columns) {
			throw "Schema '$schemaFile' must contain Name and Columns properties."
		}

		if ([string]::IsNullOrWhiteSpace($DataPath)) {
			$DataPath = $configuration.Path
		}
		if ([string]::IsNullOrWhiteSpace($DataPath)) {
			throw "Schema '$schemaFile' must contain Path, or a data path must be supplied."
		}
		if (-not [System.IO.Path]::IsPathRooted($DataPath)) {
			$DataPath = Join-Path (Split-Path -Parent $schemaFile) $DataPath
		}

		$this.Initialize($configuration.Name, $DataPath, @($configuration.Columns), @($configuration.UniqueGroups))
	}

	hidden [void] Initialize([string] $Name, [string] $Path, [object[]] $Columns, [object[]] $UniqueGroups) {
		$this.Name = $Name
		$this.Path = [System.IO.Path]::GetFullPath($Path)
		$this.Columns = @(
			foreach ($column in $Columns) {
				if ($column -is [PsDataColumn]) {
					$column
				}
				elseif ($column -is [System.Collections.IDictionary]) {
					[PsDataColumn]::new($column)
				}
				else {
					$properties = @{}
					foreach ($property in $column.PSObject.Properties) {
						$properties[$property.Name] = $property.Value
					}
					[PsDataColumn]::new($properties)
				}
			}
		)

		if ($this.Columns.Count -eq 0) {
			throw "Entity '$Name' must define at least one column."
		}

		$duplicates = @($this.Columns.Name | Group-Object | Where-Object Count -gt 1)
		if ($duplicates.Count -gt 0) {
			throw "Entity '$Name' contains duplicate column '$($duplicates[0].Name)'."
		}

		$this.UniqueGroups = @(
			foreach ($group in $UniqueGroups) {
				if ($null -eq $group) { continue }
				[PsUniqueGroup]::new($group)
			}
		)
		foreach ($group in $this.UniqueGroups) {
			foreach ($columnName in $group.Columns) {
				if ($columnName -notin $this.Columns.Name) {
					throw "Unique group column '$columnName' is not defined by entity '$Name'."
				}
			}
		}
	}
}

class PsEntity
{
	[ValidateNotNull()]
	[PsEntitySchema] $Schema

	PsEntity([PsEntitySchema] $Schema) {
		$this.Schema = $Schema
	}

	[void] Validate() {
		$this.AssertDataSource()
	}

	[void] Create() {
		$this.Create($false)
	}

	[void] Create([bool] $Force) {
		if ((Test-Path -LiteralPath $this.Schema.Path) -and -not $Force) {
			throw "Entity '$($this.Schema.Path)' already exists."
		}

		$parent = Split-Path -Parent $this.Schema.Path
		if ($parent -and -not (Test-Path -LiteralPath $parent)) {
			$null = New-Item -ItemType Directory -Path $parent -Force
		}

		$header = ($this.Schema.Columns.Name | ForEach-Object { '"' + $_ + '"' }) -join ','
		Set-Content -LiteralPath $this.Schema.Path -Value $header -Encoding utf8
	}

	[pscustomobject] Add([hashtable] $Record) {
		$this.AssertDataSource()
		$rows = $this.ReadRows()
		$recordWithGeneratedValues = $this.GenerateValues($Record, $rows)
		$validated = $this.ValidateRecord($recordWithGeneratedValues, $false)
		$this.AssertReferences($validated)
		$this.AssertUnique($validated, $rows, $null)

		$row = [pscustomobject] $validated
		$row | Export-Csv -LiteralPath $this.Schema.Path -Append -NoTypeInformation -Encoding utf8
		return $row
	}

	[object[]] Find([hashtable] $Criteria) {
		$this.AssertDataSource()
		$this.AssertKnownColumns($Criteria)
		$normalizedCriteria = $this.NormalizePartialRecord($Criteria)
		$rows = $this.ReadRows()

		return @($rows | Where-Object {
			$row = $_
			$isMatch = $true
			foreach ($name in $normalizedCriteria.Keys) {
				if ($row.$name -cne $normalizedCriteria[$name]) {
					$isMatch = $false
					break
				}
			}
			$isMatch
		})
	}

	[object[]] Find([object] $Key) {
		$keyColumn = $this.GetKeyColumn('Find')
		return $this.Find(@{ $keyColumn.Name = $Key })
	}

	[pscustomobject] GetReferencedRowByKey([string] $ColumnName, [object] $KeyValue) {
		$column = @($this.Schema.Columns | Where-Object Name -ceq $ColumnName)
		if ($column.Count -eq 0) {
			throw "Column '$ColumnName' is not defined by entity '$($this.Schema.Name)'."
		}
		if ([string]::IsNullOrWhiteSpace($column[0].References)) {
			throw "Column '$ColumnName' does not reference another entity."
		}

		$normalizedKey = $this.ConvertToStorageValue($column[0], $KeyValue)
		$referencePath = $column[0].References
		if (-not [System.IO.Path]::IsPathRooted($referencePath)) {
			$referencePath = Join-Path (Split-Path -Parent $this.Schema.Path) $referencePath
		}
		$referencePath = [System.IO.Path]::GetFullPath($referencePath)
		if (-not (Test-Path -LiteralPath $referencePath -PathType Leaf)) {
			throw "Referenced entity '$referencePath' was not found."
		}

		$header = Get-Content -LiteralPath $referencePath -First 1
		$columns = @(($header -split ',').Trim('"'))
		if ($ColumnName -notin $columns) {
			throw "Referenced entity '$referencePath' does not contain matching key column '$ColumnName'."
		}

		$matchingRows = @(Import-Csv -LiteralPath $referencePath | Where-Object { $_.$ColumnName -ceq $normalizedKey })
		if ($matchingRows.Count -ne 1) {
			throw "Referenced entity query for column '$ColumnName' and value '$normalizedKey' expected one record but found $($matchingRows.Count)."
		}
		return $matchingRows[0]
	}

	[pscustomobject] Update([object] $Key, [hashtable] $Changes) {
		$keyColumn = $this.GetKeyColumn('Update')
		return $this.UpdateByKey(@{ $keyColumn.Name = $Key }, $Changes)
	}

	[pscustomobject] Update([hashtable] $Key, [hashtable] $Changes) {
		$this.AssertCompleteKey($Key)
		return $this.UpdateByKey($Key, $Changes)
	}

	hidden [pscustomobject] UpdateByKey([hashtable] $Key, [hashtable] $Changes) {
		$this.AssertDataSource()
		$this.AssertKnownColumns($Changes)

		$rows = $this.ReadRows()
		$normalizedKey = $this.NormalizePartialRecord($Key)
		$matchingRows = @($rows | Where-Object { $this.RowMatches($_, $normalizedKey) })
		if ($matchingRows.Count -ne 1) {
			throw "Update expected one record but found $($matchingRows.Count)."
		}

		$target = $matchingRows[0]
		$record = @{}
		foreach ($column in $this.Schema.Columns) {
			$record[$column.Name] = $target.($column.Name)
		}
		foreach ($name in $Changes.Keys) {
			$record[$name] = $Changes[$name]
		}

		$validated = $this.ValidateRecord($record, $false)
		$this.AssertReferences($validated)
		$this.AssertUnique($validated, $rows, $target)
		$replacement = [pscustomobject] $validated
		$output = @($rows | ForEach-Object { if ($_ -eq $target) { $replacement } else { $_ } })
		$this.WriteRows($output)
		return $replacement
	}

	[void] Remove([hashtable] $Key) {
		$this.AssertDataSource()
		if ($Key.Count -eq 0) {
			throw 'Remove requires at least one key criterion.'
		}
		$this.AssertKnownColumns($Key)

		$rows = $this.ReadRows()
		$normalizedKey = $this.NormalizePartialRecord($Key)
		$matchingRows = @($rows | Where-Object { $this.RowMatches($_, $normalizedKey) })
		if ($matchingRows.Count -ne 1) {
			throw "Remove expected one record but found $($matchingRows.Count)."
		}

		$target = $matchingRows[0]
		$this.WriteRows(@($rows | Where-Object { $_ -ne $target }))
	}

	hidden [void] AssertDataSource() {
		if (-not (Test-Path -LiteralPath $this.Schema.Path -PathType Leaf)) {
			throw "Entity '$($this.Schema.Path)' was not found. Call Create() before using it."
		}

		$header = Get-Content -LiteralPath $this.Schema.Path -First 1
		$actualColumns = @(($header -split ',').Trim('"'))
		$expectedColumns = @($this.Schema.Columns.Name)
		if (($actualColumns.Count -ne $expectedColumns.Count) -or (Compare-Object $expectedColumns $actualColumns)) {
			throw "Entity '$($this.Schema.Path)' does not match schema '$($this.Schema.Name)'."
		}
	}

	hidden [void] AssertKnownColumns([hashtable] $Record) {
		$knownColumns = @($this.Schema.Columns.Name)
		foreach ($name in $Record.Keys) {
			if ($name -notin $knownColumns) {
				throw "Column '$name' is not defined by entity '$($this.Schema.Name)'."
			}
		}
	}

	hidden [System.Collections.Specialized.OrderedDictionary] ValidateRecord([hashtable] $Record, [bool] $AllowPartial) {
		$this.AssertKnownColumns($Record)
		$validated = [ordered] @{}
		foreach ($column in $this.Schema.Columns) {
			$hasValue = $Record.ContainsKey($column.Name)
			$value = if ($hasValue) { $Record[$column.Name] } else { $null }
			if (-not $AllowPartial -and $column.Required -and ($null -eq $value -or $value -eq '')) {
				throw "Column '$($column.Name)' is required."
			}
			if ($hasValue -or -not $AllowPartial) {
				$validated[$column.Name] = $this.ConvertToStorageValue($column, $value)
			}
		}
		return $validated
	}

	hidden [System.Collections.Specialized.OrderedDictionary] NormalizePartialRecord([hashtable] $Record) {
		return $this.ValidateRecord($Record, $true)
	}

	hidden [PsDataColumn] GetKeyColumn([string] $Operation) {
		$keyColumns = @($this.Schema.Columns | Where-Object Key)
		if ($keyColumns.Count -ne 1) {
			throw "$Operation requires entity '$($this.Schema.Name)' to define exactly one key column; found $($keyColumns.Count)."
		}
		return $keyColumns[0]
	}

	hidden [void] AssertCompleteKey([hashtable] $Key) {
		$keyColumns = @($this.Schema.Columns | Where-Object Key)
		if ($keyColumns.Count -eq 0) {
			throw "Update requires entity '$($this.Schema.Name)' to define at least one key column."
		}

		$expectedNames = @($keyColumns.Name)
		$providedNames = @($Key.Keys)
		if (($providedNames.Count -ne $expectedNames.Count) -or (Compare-Object $expectedNames $providedNames)) {
			throw "Update key must contain exactly these columns: $($expectedNames -join ', ')."
		}
	}

	hidden [hashtable] GenerateValues([hashtable] $Record, [object[]] $Rows) {
		$generatedRecord = @{}
		foreach ($name in $Record.Keys) {
			$generatedRecord[$name] = $Record[$name]
		}

		foreach ($column in $this.Schema.Columns | Where-Object Generated) {
			if ($generatedRecord.ContainsKey($column.Name) -and $null -ne $generatedRecord[$column.Name] -and $generatedRecord[$column.Name] -ne '') {
				continue
			}

			switch ($column.Type) {
				{ $_ -in @('string', 'guid') } {
					$generatedRecord[$column.Name] = [guid]::NewGuid()
					break
				}
				'int' {
					$values = @($Rows | ForEach-Object { [int] $_.($column.Name) })
					$generatedRecord[$column.Name] = if ($values.Count -eq 0) { 1 } else { ($values | Measure-Object -Maximum).Maximum + 1 }
					break
				}
				'long' {
					$values = @($Rows | ForEach-Object { [long] $_.($column.Name) })
					$generatedRecord[$column.Name] = if ($values.Count -eq 0) { [long] 1 } else { [long] (($values | Measure-Object -Maximum).Maximum + 1) }
				}
			}
		}

		return $generatedRecord
	}

	hidden [string] ConvertToStorageValue([PsDataColumn] $Column, [object] $Value) {
		if ($null -eq $Value -or $Value -eq '') {
			return ''
		}

		try {
			switch ($Column.Type) {
				'string' { return [string] $Value }
				'int' { return ([int] $Value).ToString([System.Globalization.CultureInfo]::InvariantCulture) }
				'long' { return ([long] $Value).ToString([System.Globalization.CultureInfo]::InvariantCulture) }
				'decimal' { return ([decimal] $Value).ToString([System.Globalization.CultureInfo]::InvariantCulture) }
				'double' { return ([double] $Value).ToString('R', [System.Globalization.CultureInfo]::InvariantCulture) }
				'bool' {
					$booleanValue = if ($Value -is [string]) { [bool]::Parse($Value) } else { [bool] $Value }
					return $booleanValue.ToString().ToLowerInvariant()
				}
				'datetime' { return ([datetime] $Value).ToUniversalTime().ToString('o', [System.Globalization.CultureInfo]::InvariantCulture) }
				'guid' { return ([guid] $Value).ToString() }
				'uri' {
					$uri = [uri] $Value
					if (-not $uri.IsAbsoluteUri) { throw 'URI must be absolute.' }
					return $uri.AbsoluteUri
				}
			}
		}
		catch {
			throw "Value for column '$($Column.Name)' is not a valid $($Column.Type): $($_.Exception.Message)"
		}

		throw "Column '$($Column.Name)' has unsupported type '$($Column.Type)'."
	}

	hidden [void] AssertUnique([System.Collections.Specialized.OrderedDictionary] $Record, [object[]] $Rows, [object] $ExcludedRow) {
		foreach ($column in $this.Schema.Columns | Where-Object Unique) {
			$value = $Record[$column.Name]
			if ($value -eq '') { continue }
			$duplicate = @($Rows | Where-Object { $_ -ne $ExcludedRow -and $_.($column.Name) -ceq $value })
			if ($duplicate.Count -gt 0) {
				throw "Column '$($column.Name)' must be unique; value '$value' already exists."
			}
		}

		foreach ($group in $this.Schema.UniqueGroups) {
			$values = @($group.Columns | ForEach-Object { $Record[$_] })
			if (@($values | Where-Object { $_ -eq '' }).Count -gt 0) { continue }

			$duplicate = @($Rows | Where-Object {
				$row = $_
				if ($row -eq $ExcludedRow) { return $false }
				foreach ($columnName in $group.Columns) {
					if ($row.$columnName -cne $Record[$columnName]) { return $false }
				}
				return $true
			})
			if ($duplicate.Count -gt 0) {
				throw "Columns '$($group.Columns -join ', ')' must be unique as a group; values '$($values -join ', ')' already exist."
			}
		}
	}

	hidden [void] AssertReferences([System.Collections.Specialized.OrderedDictionary] $Record) {
		foreach ($column in $this.Schema.Columns | Where-Object References) {
			$value = $Record[$column.Name]
			if ($value -eq '') { continue }

			$referencePath = $column.References
			if (-not [System.IO.Path]::IsPathRooted($referencePath)) {
				$referencePath = Join-Path (Split-Path -Parent $this.Schema.Path) $referencePath
			}
			$referencePath = [System.IO.Path]::GetFullPath($referencePath)
			if (-not (Test-Path -LiteralPath $referencePath -PathType Leaf)) {
				throw "Referenced entity '$referencePath' was not found."
			}

			$referenceColumn = $column.Name
			$header = Get-Content -LiteralPath $referencePath -First 1
			$columns = @(($header -split ',').Trim('"'))
			if ($referenceColumn -notin $columns) {
				throw "Referenced entity '$referencePath' does not contain matching key column '$referenceColumn'."
			}

			$match = @(Import-Csv -LiteralPath $referencePath | Where-Object { $_.$referenceColumn -ceq $value })
			if ($match.Count -eq 0) {
				throw "Value '$value' in column '$($column.Name)' does not exist in referenced entity '$($column.References)'."
			}
		}
	}

	hidden [bool] RowMatches([object] $Row, [System.Collections.Specialized.OrderedDictionary] $Criteria) {
		foreach ($name in $Criteria.Keys) {
			if ($Row.$name -cne $Criteria[$name]) {
				return $false
			}
		}
		return $true
	}

	hidden [object[]] ReadRows() {
		return @(Import-Csv -LiteralPath $this.Schema.Path)
	}

	hidden [void] WriteRows([object[]] $Rows) {
		if ($Rows.Count -eq 0) {
			$header = ($this.Schema.Columns.Name | ForEach-Object { '"' + $_ + '"' }) -join ','
			Set-Content -LiteralPath $this.Schema.Path -Value $header -Encoding utf8
			return
		}
		$Rows | Select-Object $this.Schema.Columns.Name | Export-Csv -LiteralPath $this.Schema.Path -NoTypeInformation -Encoding utf8
	}
}

function New-PsEntitySchema
{
	[CmdletBinding()]
	[OutputType([PsEntitySchema])]
	param(
		[Parameter(Mandatory, Position = 0)]
		[string] $SchemaPath,

		[Parameter(Position = 1)]
		[string] $DataPath
	)

	if ($PSBoundParameters.ContainsKey('DataPath')) {
		return [PsEntitySchema]::new($SchemaPath, $DataPath)
	}
	return [PsEntitySchema]::new($SchemaPath)
}

function New-PsEntity
{
	[CmdletBinding()]
	[OutputType([PsEntity])]
	param(
		[Parameter(Mandatory, Position = 0, ValueFromPipeline)]
		[PsEntitySchema] $Schema
	)

	process {
		return [PsEntity]::new($Schema)
	}
}
