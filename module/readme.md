# Future enhancements

- we need a pipeline to automate the build of the module.

````powershell
New-ModuleManifest -Path PDS.psd1 -FunctionsToExport '*' -Author "MKTHEPLUGG"
````

New-ModuleManifest -Path .\PDS.psd1 -RootModule PDS -Author 'MKTHEPLUGG' -Description 'Personal Deploy Script' -CompanyName 'meti.pro'