@{
    # PSAvoidUsingWriteHost is excluded on purpose. PDS functions are interactive installers
    # whose Write-Host calls print coloured progress, and no replacement keeps that:
    # Write-Output puts the text into the function's return value, Write-Verbose shows nothing
    # without -Verbose, and Write-Information shows nothing by default and has no colours.
    # Since Windows PowerShell 5.0 Write-Host writes to the information stream, so callers can
    # still silence it with 6>$null (and -InformationAction Ignore on advanced functions).
    # A Write-Host that emits data a caller needs is a defect and uses Write-Output instead.
    ExcludeRules = @('PSAvoidUsingWriteHost')

    # The CodeFormatting preset's rules plus trailing whitespace, and no IncludeRules, so every
    # default analyzer rule also runs.
    Rules        = @{
        PSPlaceOpenBrace           = @{
            Enable             = $true
            OnSameLine         = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
        }
        PSPlaceCloseBrace          = @{
            Enable             = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore  = $false
        }
        PSUseConsistentIndentation = @{
            Enable              = $true
            Kind                = 'space'
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
            IndentationSize     = 4
        }
        PSUseConsistentWhitespace  = @{
            Enable                                  = $true
            CheckInnerBrace                         = $true
            CheckOpenBrace                          = $true
            CheckOpenParen                          = $true
            CheckOperator                           = $true
            CheckPipe                               = $true
            CheckPipeForRedundantWhitespace         = $false
            CheckSeparator                          = $true
            CheckParameter                          = $false
            IgnoreAssignmentOperatorInsideHashTable = $true
        }
        PSAlignAssignmentStatement = @{
            Enable         = $true
            CheckHashtable = $true
        }
        PSUseCorrectCasing         = @{
            Enable = $true
        }
        PSAvoidTrailingWhitespace  = @{
            Enable = $true
        }
    }
}
