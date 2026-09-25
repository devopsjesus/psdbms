using module ..\psdbms.psd1

Describe 'PsUniqueGroup' {
    It 'accepts two or more distinct columns' {
        $group = [PsUniqueGroup]::new(@{ Columns = @('tenant', 'name') })

        $group.Columns | Should -Be @('tenant', 'name')
    }

    It 'rejects too few or duplicate columns' {
        { [PsUniqueGroup]::new(@{ Columns = @('name') }) } | Should -Throw '*at least two columns*'
        { [PsUniqueGroup]::new(@{ Columns = @('name', 'name') }) } | Should -Throw '*duplicate columns*'
    }
}
