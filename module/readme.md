# Future enhancements

- we need a pipeline to automate the build of the module.

````powershell
New-ModuleManifest -Path example.psd1 -RootModule example.psm1 -FunctionsToExport '*' -Author "MKTHEPLUGG"
````
