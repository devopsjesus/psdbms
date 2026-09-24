BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\psdbms.psd1'
    Remove-Module psdbms -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
    $script:schemaType = 'PsEntitySchema' -as [type]
    $script:entityType = 'PsEntity' -as [type]
}

Describe 'generic entity' {
    BeforeEach {
        $script:dataPath = Join-Path $TestDrive 'people.csv'
        $schema = $script:schemaType::new('people', $script:dataPath, @(
			@{ Name = 'id'; Type = 'guid'; Key = $true; Generated = $true }
            @{ Name = 'name'; Type = 'string'; Required = $true }
            @{ Name = 'active'; Type = 'bool' }
        ))
        $script:entity = $script:entityType::new($schema)
        $script:entity.Create($true)
        $script:id = [guid]::NewGuid()
    }

    It 'creates a CSV from its schema' {
        (Get-Content -LiteralPath $script:dataPath -First 1).Trim('"') | Should -Be 'id","name","active'
		Test-Path -LiteralPath "$script:dataPath.psdbms.json" | Should -BeFalse
    }

    It 'adds, finds, updates, and removes records' {
        $record = $script:entity.Add(@{ id = $script:id; name = 'Ada'; active = $true })
        $record.id | Should -Be $script:id.ToString()

        $script:entity.Find(@{ id = $script:id }).name | Should -Be 'Ada'
		$script:entity.Update($script:id, @{ name = 'Grace' }).name | Should -Be 'Grace'

        $script:entity.Remove(@{ id = $script:id })
        $script:entity.Find(@{}).Count | Should -Be 0
    }

	It 'supports scalar and composite schema keys for updates' {
        $noKeyPath = Join-Path $TestDrive 'no-key.csv'
        $noKeyEntity = $script:entityType::new($script:schemaType::new('no-key', $noKeyPath, @(
            @{ Name = 'name'; Required = $true }
        )))
        $noKeyEntity.Create()
        $null = $noKeyEntity.Add(@{ name = 'Ada' })
        { $noKeyEntity.Update('Ada', @{ name = 'Grace' }) } | Should -Throw '*exactly one key column; found 0*'

        $multipleKeyPath = Join-Path $TestDrive 'multiple-key.csv'
        $multipleKeyEntity = $script:entityType::new($script:schemaType::new('multiple-key', $multipleKeyPath, @(
            @{ Name = 'first_id'; Key = $true }
            @{ Name = 'second_id'; Key = $true }
            @{ Name = 'name'; Required = $true }
        )))
        $multipleKeyEntity.Create()
        $null = $multipleKeyEntity.Add(@{ first_id = '1'; second_id = '2'; name = 'Ada' })
        { $multipleKeyEntity.Update('1', @{ name = 'Grace' }) } | Should -Throw '*exactly one key column; found 2*'
		{ $multipleKeyEntity.Update(@{ first_id = '1' }, @{ name = 'Grace' }) } | Should -Throw '*must contain exactly these columns*'
		$multipleKeyEntity.Update(@{ first_id = '1'; second_id = '2' }, @{ name = 'Grace' }).name | Should -Be 'Grace'
    }

    It 'generates a missing guid key' {
        $record = $script:entity.Add(@{ name = 'Ada'; active = $true })

        [guid]::Parse($record.id) | Should -Not -BeNullOrEmpty
        $script:entity.Find(@{ id = $record.id }).name | Should -Be 'Ada'
    }

    It 'generates incrementing numeric keys' {
        $numericPath = Join-Path $TestDrive 'numeric.csv'
        $numericSchema = $script:schemaType::new('numeric', $numericPath, @(
            @{ Name = 'id'; Type = 'int'; Key = $true; Generated = $true }
            @{ Name = 'name'; Required = $true }
        ))
        $numericEntity = $script:entityType::new($numericSchema)
        $numericEntity.Create()

        $numericEntity.Add(@{ name = 'first' }).id | Should -Be '1'
        $numericEntity.Add(@{ name = 'second' }).id | Should -Be '2'
    }

    It 'requires generated columns to be supported keys' {
        { $script:schemaType::new('invalid', (Join-Path $TestDrive 'invalid.csv'), @(
            @{ Name = 'id'; Generated = $true }
        )) } | Should -Throw '*must be a key*'

        { $script:schemaType::new('invalid', (Join-Path $TestDrive 'invalid.csv'), @(
            @{ Name = 'id'; Type = 'datetime'; Key = $true; Generated = $true }
        )) } | Should -Throw '*must use type*'
    }

    It 'rejects missing, unknown, invalid, and duplicate values' {
        { $script:entity.Add(@{ id = [guid]::NewGuid() }) } | Should -Throw '*required*'
        { $script:entity.Add(@{ id = [guid]::NewGuid(); name = 'Ada'; extra = 'value' }) } | Should -Throw '*not defined*'
        { $script:entity.Add(@{ id = 'not-a-guid'; name = 'Ada' }) } | Should -Throw '*not a valid guid*'

        $null = $script:entity.Add(@{ id = $script:id; name = 'Ada' })
        { $script:entity.Add(@{ id = $script:id; name = 'Grace' }) } | Should -Throw '*must be unique*'
    }
}

Describe 'JSON entity schemas and references' {
    It 'loads a schema with a data path override' {
        $schemaPath = Join-Path $PSScriptRoot '..\schemas\az_subscription.json'
        $overridePath = Join-Path $TestDrive 'alternate.csv'

        $schema = $script:schemaType::new($schemaPath, $overridePath)

        $schema.Name | Should -Be 'az_subscription'
        $schema.Path | Should -Be $overridePath
    }

    It 'enforces grouped unique values across rows' {
        $schemaPath = Join-Path $TestDrive 'memberships.json'
        @{
            name = 'memberships'
            path = 'memberships.csv'
            columns = @(
                @{ name = 'id'; type = 'guid'; key = $true; generated = $true }
                @{ name = 'tenant'; required = $true }
                @{ name = 'username'; required = $true }
            )
            uniqueGroups = @(
                @{ columns = @('tenant', 'username') }
            )
        } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $schemaPath

        $entity = $script:entityType::new($script:schemaType::new($schemaPath))
        $entity.Create()
        $first = $entity.Add(@{ tenant = 'one'; username = 'ada' })
        $second = $entity.Add(@{ tenant = 'two'; username = 'ada' })
        $null = $entity.Add(@{ tenant = 'one'; username = 'grace' })

        { $entity.Add(@{ tenant = 'one'; username = 'ada' }) } | Should -Throw '*must be unique as a group*'
        $entity.Update($first.id, @{ username = 'ada' }).username | Should -Be 'ada'
        { $entity.Update($second.id, @{ tenant = 'one' }) } | Should -Throw '*must be unique as a group*'
    }

    It 'validates grouped unique column definitions' {
        { $script:schemaType::new('invalid', (Join-Path $TestDrive 'invalid.csv'), @(
            @{ Name = 'id'; Key = $true }
            @{ Name = 'name' }
        ), @(@{ Columns = @('name') })) } | Should -Throw '*at least two columns*'

        { $script:schemaType::new('invalid', (Join-Path $TestDrive 'invalid.csv'), @(
            @{ Name = 'id'; Key = $true }
            @{ Name = 'name' }
        ), @(@{ Columns = @('name', 'missing') })) } | Should -Throw "*'missing' is not defined*"
    }

    It 'loads a schema with a relative path and enforces references' {
        $parentPath = Join-Path $TestDrive 'parents.csv'
        $parentSchema = $script:schemaType::new('parents', $parentPath, @(
            @{ Name = 'parent_id'; Key = $true }
        ))
        $parent = $script:entityType::new($parentSchema)
        $parent.Create()
        $null = $parent.Add(@{ parent_id = 'parent-1' })

        $schemaPath = Join-Path $TestDrive 'children.json'
        @{
            name = 'children'
            path = 'children.csv'
            columns = @(
                @{ name = 'id'; key = $true }
                @{ name = 'parent_id'; required = $true; references = 'parents.csv' }
            )
        } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $schemaPath

        $childSchema = $script:schemaType::new($schemaPath)
        $child = $script:entityType::new($childSchema)
        $child.Create()
        $child.Schema.Path | Should -Be (Join-Path $TestDrive 'children.csv')
        { $child.Add(@{ id = 'child-1'; parent_id = 'missing' }) } | Should -Throw '*does not exist in reference*'

        $child.Add(@{ id = 'child-1'; parent_id = 'parent-1' }).parent_id | Should -Be 'parent-1'
    }

    It 'rejects a reference whose key column name does not match' {
        $parentPath = Join-Path $TestDrive 'mismatched-parents.csv'
        $parentSchema = $script:schemaType::new('parents', $parentPath, @(
            @{ Name = 'id'; Key = $true }
        ))
        $parent = $script:entityType::new($parentSchema)
        $parent.Create($true)
        $null = $parent.Add(@{ id = 'parent-1' })

        $childSchema = $script:schemaType::new('children', (Join-Path $TestDrive 'mismatched-children.csv'), @(
            @{ Name = 'id'; Key = $true }
            @{ Name = 'parent_id'; Required = $true; References = 'mismatched-parents.csv' }
        ))
        $child = $script:entityType::new($childSchema)
        $child.Create($true)

        { $child.Add(@{ id = 'child-1'; parent_id = 'parent-1' }) } | Should -Throw "*does not contain matching key column 'parent_id'*"
    }

    It 'loads each bundled schema with columns matching its CSV header' -ForEach @(
        'az_service_principal'
        'az_subscription'
        'gh_repository'
        'gh_repo_environment'
        'gh_az_credential'
    ) {
        $schemaPath = Join-Path $PSScriptRoot "..\schemas\$_.json"
        $schema = $script:schemaType::new($schemaPath)
        $header = @((Get-Content -LiteralPath $schema.Path -First 1 -ErrorAction Stop -Encoding utf8) -split ',' | ForEach-Object Trim '"')
        $metadata = $script:entityType::Open($schemaPath).Schema

        $schema.Name | Should -Be $_
        Compare-Object -ReferenceObject $schema.Columns.Name -DifferenceObject $header | Should -BeNullOrEmpty
        $metadata.Name | Should -Be $schema.Name
        Compare-Object -ReferenceObject $schema.Columns.Name -DifferenceObject $metadata.Columns.Name | Should -BeNullOrEmpty
    }
}

Describe 'module surface' {
    It 'exports no wrapper functions' {
        @(Get-Command -Module psdbms -CommandType Function).Count | Should -Be 0
    }
}

Describe 'PsEntity Open' {
    BeforeEach {
        $script:dataPath = Join-Path $TestDrive 'existing.csv'
        $script:schemaPath = Join-Path $TestDrive 'existing.json'
        Remove-Item -LiteralPath $script:dataPath -Force -ErrorAction SilentlyContinue
        @{
            name = 'existing'
            path = 'existing.csv'
            columns = @(
                @{ name = 'id'; key = $true }
                @{ name = 'name'; required = $true }
            )
        } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $script:schemaPath
    }

    It 'loads metadata from the schema' {
        $created = $script:entityType::new($script:schemaType::new($script:schemaPath))
        $created.Create()

        $metadata = $script:entityType::Open($script:schemaPath).Schema

        $metadata.Name | Should -Be 'existing'
        $metadata.Path | Should -Be $script:dataPath
        $metadata.Columns.Name | Should -Be @('id', 'name')
        $metadata.Columns[0].Key | Should -BeTrue
        $metadata.Columns[0].Unique | Should -BeTrue
        $metadata.Columns[1].Required | Should -BeTrue
    }

    It 'loads records into Data' {
        $created = $script:entityType::new($script:schemaType::new($script:schemaPath))
        $created.Create()
        $null = $created.Add(@{ id = 'person-1'; name = 'Ada' })

        $records = @($script:entityType::Open($script:schemaPath).Data)

        $records.Count | Should -Be 1
        $records[0].id | Should -Be 'person-1'
        $records[0].name | Should -Be 'Ada'
    }

    It 'returns no data for an empty entity' {
        $created = $script:entityType::new($script:schemaType::new($script:schemaPath))
        $created.Create()

        @($script:entityType::Open($script:schemaPath).Data).Count | Should -Be 0
    }

    It 'rejects a missing entity' {
        { $script:entityType::Open($script:schemaPath) } | Should -Throw '*was not found*'
    }

    It 'rejects a missing schema' {
        $missingSchemaPath = Join-Path $TestDrive 'missing.json'

        { $script:entityType::Open($missingSchemaPath) } | Should -Throw
    }

    It 'rejects an entity whose header does not match its metadata' {
        $created = $script:entityType::new($script:schemaType::new($script:schemaPath))
        $created.Create()
        Set-Content -LiteralPath $script:dataPath -Value 'wrong_header'

        { $script:entityType::Open($script:schemaPath) } | Should -Throw '*does not match schema*'
    }
}

Describe 'PsEntity retrieval lifecycle' {
    It 'opens an existing entity with complete metadata and no creation command' {
        $dataPath = Join-Path $TestDrive 'inventory.csv'
        $schemaPath = Join-Path $TestDrive 'inventory.json'
        @{
            name = 'inventory'
            path = 'inventory.csv'
            columns = @(
                @{ name = 'sku'; type = 'string'; key = $true }
                @{ name = 'quantity'; type = 'int'; required = $true }
            )
        } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $schemaPath

		$schema = $script:schemaType::new($schemaPath)
        $created = $script:entityType::new($schema)
        $created.Create($true)
        $null = $created.Add(@{ sku = 'B-2'; quantity = 7 })

        $entity = $script:entityType::Open($schemaPath)

        $entity.Schema.Name | Should -Be 'inventory'
        $entity.Schema.Columns.Name | Should -Be @('sku', 'quantity')
        $entity.Schema.Columns[0].Key | Should -BeTrue
        $entity.Schema.Columns[1].Type | Should -Be 'int'
        $entity.Find(@{ sku = 'B-2' }).quantity | Should -Be '7'
    }

    It 'rejects a missing CSV path' {
        $schemaPath = Join-Path $TestDrive 'missing-entity.json'
        @{
            name = 'missing'
            path = 'missing.csv'
            columns = @(@{ name = 'id'; key = $true })
        } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $schemaPath

		{ $script:entityType::Open($schemaPath) } | Should -Throw '*was not found*'
    }
}
