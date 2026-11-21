BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
    # git may be absent on the test machine and must never run for real; a module-scope
    # stub lets Pester mock it.
    InModuleScope PDS { function script:git { } }
}

Describe 'Set-LF' {
    BeforeEach {
        # A fresh tree per test under TestDrive: two shell scripts (one nested) and a text file.
        $script:root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $null = New-Item -ItemType Directory -Path (Join-Path $script:root 'sub')
        $script:topScript = Join-Path $script:root 'build.sh'
        $script:nestedScript = Join-Path $script:root 'sub' 'deploy.sh'
        $script:textFile = Join-Path $script:root 'notes.txt'
        [System.IO.File]::WriteAllText($script:topScript, "#!/bin/sh`r`necho one`r`n")
        [System.IO.File]::WriteAllText($script:nestedScript, "#!/bin/sh`recho two`r")
        [System.IO.File]::WriteAllText($script:textFile, "line one`r`nline two`r`n")
        Mock git -ModuleName PDS { }
    }

    It 'converts CRLF and CR to LF in shell scripts and leaves other files alone' {
        Set-LF -Path $script:root 6>$null

        [System.IO.File]::ReadAllText($script:topScript) | Should -BeExactly "#!/bin/sh`necho one`n"
        [System.IO.File]::ReadAllText($script:nestedScript) | Should -BeExactly "#!/bin/sh`necho two`n"
        [System.IO.File]::ReadAllText($script:textFile) | Should -BeExactly "line one`r`nline two`r`n"
        Should -Invoke git -ModuleName PDS -Times 0 -Exactly
    }

    It 'writes a file without a byte-order mark back without one' {
        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($script:topScript, "#!/bin/sh`r`necho caf$([char]0xE9)`r`n", $utf8NoBom)

        Set-LF -Path $script:topScript 6>$null

        $bytes = [System.IO.File]::ReadAllBytes($script:topScript)
        $bytes[0..1] | Should -Be @(0x23, 0x21)
        $bytes | Should -Be $utf8NoBom.GetBytes("#!/bin/sh`necho caf$([char]0xE9)`n")
    }

    It 'keeps the byte-order mark of a UTF-8 file that has one' {
        $utf8Bom = [System.Text.UTF8Encoding]::new($true)
        [System.IO.File]::WriteAllText($script:topScript, "#!/bin/sh`r`necho caf$([char]0xE9)`r`n", $utf8Bom)

        Set-LF -Path $script:topScript 6>$null

        $bytes = [System.IO.File]::ReadAllBytes($script:topScript)
        $bytes[0..2] | Should -Be @(0xEF, 0xBB, 0xBF)
        $bytes | Should -Be ($utf8Bom.GetPreamble() + $utf8Bom.GetBytes("#!/bin/sh`necho caf$([char]0xE9)`n"))
    }

    It 'keeps a UTF-16 file in UTF-16' {
        $utf16 = [System.Text.UnicodeEncoding]::new($false, $true)
        [System.IO.File]::WriteAllText($script:topScript, "#!/bin/sh`r`necho one`r`n", $utf16)

        Set-LF -Path $script:topScript 6>$null

        $bytes = [System.IO.File]::ReadAllBytes($script:topScript)
        $bytes | Should -Be ($utf16.GetPreamble() + $utf16.GetBytes("#!/bin/sh`necho one`n"))
    }

    It 'does not descend into subdirectories when Recurse is false' {
        Set-LF -Path $script:root -Recurse $false 6>$null

        [System.IO.File]::ReadAllText($script:topScript) | Should -BeExactly "#!/bin/sh`necho one`n"
        [System.IO.File]::ReadAllText($script:nestedScript) | Should -BeExactly "#!/bin/sh`recho two`r"
    }

    It 'converts the file types it is given' {
        Set-LF -Path $script:root -FileTypes '.txt' 6>$null

        [System.IO.File]::ReadAllText($script:textFile) | Should -BeExactly "line one`nline two`n"
        [System.IO.File]::ReadAllText($script:topScript) | Should -BeExactly "#!/bin/sh`r`necho one`r`n"
    }

    It 'disables autocrlf and re-stages each matching file with the Git method' {
        Set-LF -Path $script:root -Method Git 6>$null

        Should -Invoke git -ModuleName PDS -Times 1 -Exactly -ParameterFilter { ($args -join ' ') -eq 'config core.autocrlf false' }
        Should -Invoke git -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $args[0] -eq 'add' -and $args[1] -eq $script:topScript }
        Should -Invoke git -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $args[0] -eq 'reset' -and $args[1] -eq $script:topScript }
        Should -Invoke git -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $args[0] -eq 'add' -and $args[1] -eq $script:nestedScript }
        Should -Invoke git -ModuleName PDS -Times 0 -Exactly -ParameterFilter { $args[1] -eq $script:textFile }
        [System.IO.File]::ReadAllText($script:topScript) | Should -BeExactly "#!/bin/sh`r`necho one`r`n"
    }

    It 'warns about a path that does not exist' {
        $missing = Join-Path $TestDrive 'missing'

        $warnings = Set-LF -Path $missing 6>$null 3>&1

        "$warnings" | Should -Be "Path does not exist: $missing"
    }

    It 'changes nothing under -WhatIf' {
        Set-LF -Path $script:root -WhatIf 6>$null
        Set-LF -Path $script:root -Method Git -WhatIf 6>$null

        Should -Invoke git -ModuleName PDS -Times 0 -Exactly
        [System.IO.File]::ReadAllText($script:topScript) | Should -BeExactly "#!/bin/sh`r`necho one`r`n"
        [System.IO.File]::ReadAllText($script:nestedScript) | Should -BeExactly "#!/bin/sh`recho two`r"
    }
}
