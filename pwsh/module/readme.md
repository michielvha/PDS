## Future enhancements

- Do some research about useful modules
- take inspiration from past works. => Go Through/Cleanup all old scripts, add to github, ... **CLEANUP**

### Useful Modules

- **Power setting configuration**, take parameters to set the mode.
- Enable developer mode
- **File explorer options**, Adjust settings to show hidden files and extensions.
- Taskbar Customization
- WSL install & Config
- Privacy Settings
- **Hostmetrics on background:** BGinfo (lightweight) or rainmeter (extensible), ...

## Done

- we need a pipeline to automate the build of the module leveraging gitVersion for version. [workflow](./../../.github/workflows/publish-ps-module.yaml)  created, needs to be tested => seems to work

- manual command:
    ````powershell
    New-ModuleManifest -Path PDS.psd1 -FunctionsToExport '*' -Author "MKTHEPLUGG" -Description 'Personal Deploy Script' -CompanyName 'meti.pro'
    ````
  
- pipeline command:
    ````powershell
    New-ModuleManifest -Path PDS.psd1 -FunctionsToExport '*' -Author "MKTHEPLUGG" -Description 'Personal Deploy Script' -CompanyName 'meti.pro'
    ````