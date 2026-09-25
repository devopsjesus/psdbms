using module ..\psdbms.psd1

Describe 'PsDataColumn' {
    It 'makes keys required and unique' {
        $column = [PsDataColumn]::new(@{ Name = 'id'; Key = $true })

        $column.Required | Should -BeTrue
        $column.Unique | Should -BeTrue
    }

    It 'requires generated columns to be supported keys' {
        { [PsDataColumn]::new(@{ Name = 'id'; Generated = $true }) } | Should -Throw '*must be a key*'
        { [PsDataColumn]::new(@{ Name = 'id'; Type = 'datetime'; Key = $true; Generated = $true }) } | Should -Throw '*must use type*'
    }

    It 'rejects invalid column names' {
        { [PsDataColumn]::new(@{ Name = '1invalid' }) } | Should -Throw '*cannot start with a number*'
        { [PsDataColumn]::new(@{ Name = 'invalid-name' }) } | Should -Throw '*only letters, numbers, and underscores*'
    }
}
