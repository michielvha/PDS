# pds.psm1

# Import all functions from the Public folder
Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter *.ps1 | ForEach-Object {
    . $_.FullName
}
