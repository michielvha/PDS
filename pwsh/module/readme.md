# Module Docs

here we need to create the docs for the module we created, define all the functions etc etc, the specific docs for each function should be in the functions to be compliant with the way powershell handles Function docs.

## Future enhancements

- Do some research about useful modules
- take inspiration from past works. => Go Through/Cleanup all old scripts, add to github, ... **CLEANUP**
- 

### Implement these useful functions into module

- **Power setting configuration**, take parameters to set the mode.
- Enable developer mode
- **File explorer options**, Adjust settings to show hidden files and extensions.
- Taskbar Customization
- Privacy Settings




## Done

- **WSL** install & Config

- **Hostmetrics on background:** BGinfo (lightweight) or rainmeter (extensible), ...

- we need a **pipeline to automate the build of the module** leveraging gitVersion for versioning. [workflow](./../../.github/workflows/publish-ps-module.yaml)  created

- manual command:
    ````powershell
    New-ModuleManifest -Path PDS.psd1 -FunctionsToExport '*' -Author "MKTHEPLUGG" -Description 'Personal Deploy Script' -CompanyName 'meti.pro'
    ````
  
- pipeline command:
    ````powershell
    New-ModuleManifest -Path PDS.psd1 -FunctionsToExport '*' -Author "MKTHEPLUGG" -Description 'Personal Deploy Script' -CompanyName 'meti.pro'
    ````