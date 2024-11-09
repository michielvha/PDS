# Module Docs

### List & Description of Functions in Module (TO DO)
here we need to create the docs for the module we created, define all the functions etc etc, the specific docs for each function should be in the functions to be compliant with the way powershell handles Function docs.

## Future enhancements

- Do some research about useful modules
- take inspiration from past works. => Go Through/Cleanup all old scripts, add to github, ... **CLEANUP**
- I want to create a pipeline that will test the functions in the module.

### TODO: Implement these useful functions into module

- set aliases, docker compose up -d (dcu) & docker compose down (dcd)
- **Power setting configuration**, take parameters to set the mode.
- Enable developer mode
- **File explorer options**, Adjust settings to show hidden files and extensions.
- Taskbar Customization
- Privacy Settings
- Auto enable numlock
- Firefox deployed with extension ( containers / Simple Tabs Groups / Adblock plus) => with Firefox account or in script ... ?

## Done

- Enable longpaths support in registry.

- **WSL** install & Config

- **Hostmetrics on background:** BGinfo (lightweight) or rainmeter (extensible), ...

- we need a **pipeline to automate the build of the module** leveraging gitVersion for versioning. [workflow](./../../.github/workflows/publish-pwsh-module.yaml)  created

- manual command:
    ````powershell
    New-ModuleManifest -Path PDS.psd1 -FunctionsToExport '*' -Author "MKTHEPLUGG" -Description 'Personal Deploy Script' -CompanyName 'meti.pro'
    ````
  
- pipeline command:
    ````powershell
    New-ModuleManifest -Path PDS.psd1 -FunctionsToExport '*' -Author "MKTHEPLUGG" -Description 'Personal Deploy Script' -CompanyName 'meti.pro'
    ````


### Reference

[Official NuGet Repo in PSGallery](https://www.powershellgallery.com/packages/PDS/)