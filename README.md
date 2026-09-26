# psdbms

A lightweight, schema-driven entity manager for PowerShell. It uses CSV files when a full DBMS would be excessive but records still need validation, keys, uniqueness, and simple relationships.

## Create an entity

```powershell
Import-Module ./psdbms/psdbms.psd1

$schema = Get-PsEntitySchema -SchemaPath './schemas/people.json'
$people = New-PsEntity -Schema $schema

$record = $people.Add(@{ name = 'Ada'; active = $true })
$id = $record.id
$people.Find($id)
$people.Update($id, @{ name = 'Grace' })
$people.Remove(@{ id = $id })
```

For a schema with multiple key columns, pass all key values as a hashtable:

```powershell
$entity.Update(@{ tenant_id = 'tenant-1'; record_id = 'record-1' }, @{ name = 'Grace' })
```

`New-PsEntity` creates the CSV and refuses to overwrite an existing file. Use `New-PsEntity -Schema $schema -Force` to recreate it. Use `Get-PsEntity` to load and validate an existing CSV without recreating it.

## JSON schemas

Schemas are reusable and remain separate from application code:

```json
{
	"name": "people",
	"path": "../data/people.csv",
	"columns": [
		{ "name": "id", "type": "guid", "key": true, "generated": true },
		{ "name": "tenant", "type": "string", "required": true },
		{ "name": "name", "type": "string", "required": true }
	],
	"uniqueGroups": [
		{ "columns": ["tenant", "name"] }
	]
}
```

Paths are resolved relative to the schema file:

```powershell
$schema = Get-PsEntitySchema -SchemaPath './schemas/people.json'
$people = New-PsEntity -Schema $schema
```

Override the schema's data path with the two-argument constructor:

```powershell
$schema = Get-PsEntitySchema -SchemaPath './schemas/people.json' -DataPath './alternate/people.csv'
```

The schema JSON remains the authoritative metadata source. To access an existing entity without recreating its CSV, construct it from the schema and validate the data source:

```powershell
$peopleEntity = Get-PsEntity -SchemaPath './schemas/people.json'
$peopleEntity.Find(@{ name = 'Ada' })
```

An existing `PsEntitySchema` object can also be passed directly or through the pipeline:

```powershell
$peopleEntity = Get-PsEntity -Schema $schema
$peopleEntity = $schema | Get-PsEntity
```

Passing a single value to `Find()` compares it to the entity's sole key column. Use a hashtable for named criteria; scalar lookup is rejected when the schema defines zero or multiple keys.

Retrieval loads key, required, type, uniqueness, and relationship metadata from the schema and validates it against the CSV header.

Supported types are `string`, `int`, `long`, `decimal`, `double`, `bool`, `datetime`, `guid`, and `uri`. A key is automatically required and unique. Other columns can set `unique` explicitly. A key can set `generated` to create its value when omitted: `string` and `guid` keys receive a GUID, while `int` and `long` keys receive the next numeric value. Callers may still provide an explicit value.

Use `uniqueGroups` when a combination of values must be unique across rows while each value may repeat independently. Grouped constraints are enforced during both `Add()` and `Update()`. A group containing an empty value is not constrained.

Relationships reference another entity by path. The foreign-key column name must match the key column name in the referenced entity. Relative reference paths are resolved from the data file's directory:

```json
{
	"name": "id",
	"required": true,
	"references": "people.csv"
}
```

Here, the local `id` value is checked against the `id` column in `people.csv`. A reference is rejected if the referenced entity does not contain a same-named column or the value is absent. References are enforced when records are added or updated. The bundled schemas represent a GitHub and Azure credential model, while the entity engine itself is domain independent.

Retrieve the complete row from a referenced entity using the shared key column:

```powershell
$repository = $credentialEntity.GetReferencedRowByKey(
	'gh_repository_id',
	$credential.gh_repository_id
)
```

## Scope

CSV storage is intentionally small-scale. Writes replace the file for updates and deletes, operations are not transactional, and concurrent writers are not coordinated. Use a conventional database when those guarantees matter.
