Describe 'credential workflow' {
    BeforeAll {
        $repositoryRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
        $script:workflowRoot = Join-Path $TestDrive 'workflow'
        $script:dataRoot = Join-Path $script:workflowRoot 'data'

        New-Item -ItemType Directory -Path $script:workflowRoot | Out-Null
        Copy-Item -LiteralPath (Join-Path $repositoryRoot 'schemas') -Destination $script:workflowRoot -Recurse
        New-Item -ItemType Directory -Path $script:dataRoot | Out-Null
        Import-Module (Join-Path $repositoryRoot 'psdbms\psdbms.psd1')

        $credentialDefinition = @{
            gh_repository_id                 = '12345676532'
            az_subscription_id               = '12345678-1234-1234-1234-123456789012'
            az_subscription_name             = 'subscription-name'
            az_service_principal_id          = '6340792e-2589-46f1-a693-1d6e64d52c13'
            az_service_principal_name        = 'sp-name'
            gh_repo_environment_name         = 'environment-name'
            gh_repository_name               = 'repository-name'
        }

        $schemaRoot = Join-Path $script:workflowRoot 'schemas'

        $servicePrincipalSchema = Get-PsEntitySchema (Join-Path $schemaRoot 'az_service_principal.json')
        $servicePrincipalEntity = New-PsEntity $servicePrincipalSchema
        $null = $servicePrincipalEntity.Add(@{
            az_service_principal_id   = $credentialDefinition.az_service_principal_id
            az_service_principal_name = $credentialDefinition.az_service_principal_name
        })

        $subscriptionSchema = Get-PsEntitySchema (Join-Path $schemaRoot 'az_subscription.json')
        $subscriptionEntity = New-PsEntity $subscriptionSchema
        $null = $subscriptionEntity.Add(@{
            az_subscription_id   = $credentialDefinition.az_subscription_id
            az_subscription_name = $credentialDefinition.az_subscription_name
        })

        $environmentSchema = Get-PsEntitySchema (Join-Path $schemaRoot 'gh_repo_environment.json')
        $environmentEntity = New-PsEntity $environmentSchema
        $environment = $environmentEntity.Add(@{
            gh_repo_environment_name = $credentialDefinition.gh_repo_environment_name
        })

        $repositorySchema = Get-PsEntitySchema (Join-Path $schemaRoot 'gh_repository.json')
        $repositoryEntity = New-PsEntity $repositorySchema
        $null = $repositoryEntity.Add(@{
            gh_repository_id   = $credentialDefinition.gh_repository_id
            gh_repository_name = $credentialDefinition.gh_repository_name
        })

        $credentialSchema = Get-PsEntitySchema (Join-Path $schemaRoot 'gh_az_credential.json')
        $credentialEntity = New-PsEntity $credentialSchema
        $script:credential = $credentialEntity.Add(@{
            gh_repository_id        = $credentialDefinition.gh_repository_id
            gh_repo_environment_id  = $environment.gh_repo_environment_id
            az_subscription_id      = $credentialDefinition.az_subscription_id
            az_service_principal_id = $credentialDefinition.az_service_principal_id
        })
    }

    It 'initializes the related entities' {
        $environment = Import-Csv -LiteralPath (Join-Path $script:dataRoot 'gh_repo_environment.csv')
        $servicePrincipal = Import-Csv -LiteralPath (Join-Path $script:dataRoot 'az_service_principal.csv')

        @($script:credential).Count | Should -Be 1
        [guid]::Parse($script:credential.gh_az_credential_id) | Should -Not -BeNullOrEmpty
        $script:credential.gh_repo_environment_id | Should -Be $environment.gh_repo_environment_id
        $script:credential.az_service_principal_id | Should -Be $servicePrincipal.az_service_principal_id
    }

    It 'adds a credential through existing entities and environment' {
        $schemaRoot = Join-Path $script:workflowRoot 'schemas'
        $servicePrincipalId = [guid]::NewGuid().Guid
        $subscriptionId = [guid]::NewGuid().Guid
        $repositoryId = '9876543210'

        $servicePrincipalEntity = Get-PsEntitySchema (Join-Path $schemaRoot 'az_service_principal.json') |
            Get-PsEntity
        $null = $servicePrincipalEntity.Add(@{
            az_service_principal_id   = $servicePrincipalId
            az_service_principal_name = 'new-solution-sp'
        })

        $subscriptionEntity = Get-PsEntitySchema (Join-Path $schemaRoot 'az_subscription.json') |
            Get-PsEntity
        $null = $subscriptionEntity.Add(@{
            az_subscription_id   = $subscriptionId
            az_subscription_name = 'new-solution-sub'
        })

        $environmentEntity = Get-PsEntitySchema (Join-Path $schemaRoot 'gh_repo_environment.json') |
            Get-PsEntity
        $environment = $environmentEntity.Find(@{
            gh_repo_environment_name = 'environment-name'
        })

        $repositoryEntity = Get-PsEntitySchema (Join-Path $schemaRoot 'gh_repository.json') |
            Get-PsEntity
        $null = $repositoryEntity.Add(@{
            gh_repository_id   = $repositoryId
            gh_repository_name = 'new-solution-repo'
        })

        $credentialEntity = Get-PsEntitySchema (Join-Path $schemaRoot 'gh_az_credential.json') |
            Get-PsEntity
        $newCredential = $credentialEntity.Add(@{
            gh_repository_id        = $repositoryId
            gh_repo_environment_id  = $environment.gh_repo_environment_id
            az_subscription_id      = $subscriptionId
            az_service_principal_id = $servicePrincipalId
        })
        $persistedCredential = $credentialEntity.Find($newCredential.gh_az_credential_id)

        [guid]::Parse($newCredential.gh_az_credential_id) | Should -Not -BeNullOrEmpty
        $persistedCredential.gh_repository_id | Should -Be $repositoryId
        $persistedCredential.gh_repo_environment_id | Should -Be $environment.gh_repo_environment_id
        $persistedCredential.az_subscription_id | Should -Be $subscriptionId
        $persistedCredential.az_service_principal_id | Should -Be $servicePrincipalId
    }

    It 'rejects credential creation when the environment lookup finds no record' {
        $schemaRoot = Join-Path $script:workflowRoot 'schemas'
        $environmentEntity = Get-PsEntitySchema (Join-Path $schemaRoot 'gh_repo_environment.json') |
            Get-PsEntity
        $environment = $environmentEntity.Find(@{
            gh_repo_environment_name = 'missing-environment'
        })
        $credentialEntity = Get-PsEntitySchema (Join-Path $schemaRoot 'gh_az_credential.json') |
            Get-PsEntity
        $credentialCount = $credentialEntity.Find(@{}).Count

        @($environment).Count | Should -Be 0
        {
            $credentialEntity.Add(@{
                gh_repository_id        = $script:credential.gh_repository_id
                gh_repo_environment_id  = $environment.gh_repo_environment_id
                az_subscription_id      = $script:credential.az_subscription_id
                az_service_principal_id = $script:credential.az_service_principal_id
            })
        } | Should -Throw "*Column 'gh_repo_environment_id' is required*"
        $credentialEntity.Find(@{}).Count | Should -Be $credentialCount
    }

    It 'retains earlier records when credential creation fails' {
        $schemaRoot = Join-Path $script:workflowRoot 'schemas'
        $servicePrincipalId = [guid]::NewGuid().Guid
        $subscriptionId = [guid]::NewGuid().Guid
        $repositoryId = '8765432109'

        $servicePrincipalEntity = Get-PsEntitySchema (Join-Path $schemaRoot 'az_service_principal.json') |
            Get-PsEntity
        $null = $servicePrincipalEntity.Add(@{
            az_service_principal_id   = $servicePrincipalId
            az_service_principal_name = 'partial-sp'
        })

        $subscriptionEntity = Get-PsEntitySchema (Join-Path $schemaRoot 'az_subscription.json') |
            Get-PsEntity
        $null = $subscriptionEntity.Add(@{
            az_subscription_id   = $subscriptionId
            az_subscription_name = 'partial-sub'
        })

        $repositoryEntity = Get-PsEntitySchema (Join-Path $schemaRoot 'gh_repository.json') |
            Get-PsEntity
        $null = $repositoryEntity.Add(@{
            gh_repository_id   = $repositoryId
            gh_repository_name = 'partial-repo'
        })

        $credentialEntity = Get-PsEntitySchema (Join-Path $schemaRoot 'gh_az_credential.json') |
            Get-PsEntity
        $credentialCount = $credentialEntity.Find(@{}).Count
        {
            $credentialEntity.Add(@{
                gh_repository_id        = $repositoryId
                gh_repo_environment_id  = 'missing-environment-id'
                az_subscription_id      = $subscriptionId
                az_service_principal_id = $servicePrincipalId
            })
        } | Should -Throw '*does not exist in referenced entity*'

        $servicePrincipalEntity.Find($servicePrincipalId).az_service_principal_name | Should -Be 'partial-sp'
        $subscriptionEntity.Find($subscriptionId).az_subscription_name | Should -Be 'partial-sub'
        $repositoryEntity.Find($repositoryId).gh_repository_name | Should -Be 'partial-repo'
        $credentialEntity.Find(@{}).Count | Should -Be $credentialCount
    }

    It 'supports repeated incremental credential workflows' {
        $schemaRoot = Join-Path $script:workflowRoot 'schemas'
        $environmentEntity = Get-PsEntitySchema (Join-Path $schemaRoot 'gh_repo_environment.json') |
            Get-PsEntity
        $environment = $environmentEntity.Find(@{
            gh_repo_environment_name = 'environment-name'
        })
        $credentialEntity = Get-PsEntitySchema (Join-Path $schemaRoot 'gh_az_credential.json') |
            Get-PsEntity
        $initialCredentialCount = $credentialEntity.Find(@{}).Count
        $createdCredentials = @()

        foreach ($index in 1..2) {
            $servicePrincipalId = [guid]::NewGuid().Guid
            $subscriptionId = [guid]::NewGuid().Guid
            $repositoryId = "76543210$index"

            $servicePrincipalEntity = Get-PsEntitySchema (Join-Path $schemaRoot 'az_service_principal.json') |
                Get-PsEntity
            $null = $servicePrincipalEntity.Add(@{
                az_service_principal_id   = $servicePrincipalId
                az_service_principal_name = "repeated-sp-$index"
            })

            $subscriptionEntity = Get-PsEntitySchema (Join-Path $schemaRoot 'az_subscription.json') |
                Get-PsEntity
            $null = $subscriptionEntity.Add(@{
                az_subscription_id   = $subscriptionId
                az_subscription_name = "repeated-sub-$index"
            })

            $repositoryEntity = Get-PsEntitySchema (Join-Path $schemaRoot 'gh_repository.json') |
                Get-PsEntity
            $null = $repositoryEntity.Add(@{
                gh_repository_id   = $repositoryId
                gh_repository_name = "repeated-repo-$index"
            })

            $createdCredentials += $credentialEntity.Add(@{
                gh_repository_id        = $repositoryId
                gh_repo_environment_id  = $environment.gh_repo_environment_id
                az_subscription_id      = $subscriptionId
                az_service_principal_id = $servicePrincipalId
            })
        }

        $createdCredentials.Count | Should -Be 2
        $createdCredentials[0].gh_az_credential_id | Should -Not -Be $createdCredentials[1].gh_az_credential_id
        $credentialEntity.Find(@{}).Count | Should -Be ($initialCredentialCount + 2)
        foreach ($credential in $createdCredentials) {
            $credentialEntity.Find($credential.gh_az_credential_id).gh_repository_id |
                Should -Be $credential.gh_repository_id
        }
    }

    It 'queries related entities to build credential data' {
        $schemaPath = Join-Path $script:workflowRoot 'schemas\gh_az_credential.json'
        $credentialEntity = Get-PsEntitySchema $schemaPath | Get-PsEntity
        $credential = $credentialEntity.Find($script:credential.gh_az_credential_id)

        $environment = $credentialEntity.GetReferencedRowByKey(
            'gh_repo_environment_id',
            $credential.gh_repo_environment_id
        )
        $servicePrincipal = $credentialEntity.GetReferencedRowByKey(
            'az_service_principal_id',
            $credential.az_service_principal_id
        )

        $credentialData = @{
            client_id        = $credential.az_service_principal_id
            subscription_id  = $credential.az_subscription_id
            repository_id    = $credential.gh_repository_id
            environment_name = $environment.gh_repo_environment_name
            secret_name      = $servicePrincipal.az_service_principal_name
        }

        $credentialData.client_id | Should -Be '6340792e-2589-46f1-a693-1d6e64d52c13'
        $credentialData.subscription_id | Should -Be '12345678-1234-1234-1234-123456789012'
        $credentialData.repository_id | Should -Be '12345676532'
        $credentialData.environment_name | Should -Be 'environment-name'
        $credentialData.secret_name | Should -Be 'sp-name'
    }
}