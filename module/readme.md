# Future enhancements

- we need a pipeline to automate the build of the module.

````powershell
New-ModuleManifest -Path PDS.psd1 -FunctionsToExport '*' -Author "MKTHEPLUGG" -Description 'Personal Deploy Script' -CompanyName 'meti.pro'
````