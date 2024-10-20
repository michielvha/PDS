## Future enhancements

- Do some research about useful modules, take inspiration from past works. => Cleanup all old scripts, add to github, ... **CLEANUP**


## Done

- we need a pipeline to automate the build of the module leveraging gitVersion for version. [workflow](./../../.github/workflows/publish-ps-module.yaml)  created, needs to be tested

- manual command:
    ````powershell
    New-ModuleManifest -Path PDS.psd1 -FunctionsToExport '*' -Author "MKTHEPLUGG" -Description 'Personal Deploy Script' -CompanyName 'meti.pro'
    ````
  
- pipeline command:
    ````powershell
    New-ModuleManifest -Path PDS.psd1 -FunctionsToExport '*' -Author "MKTHEPLUGG" -Description 'Personal Deploy Script' -CompanyName 'meti.pro'
    ````