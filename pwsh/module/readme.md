# Module Docs

### List & Description of Functions in Module (TO DO)
here we need to create the docs for the module we created, define all the functions etc etc, the specific docs for each function should be in the functions to be compliant with the way powershell handles Function docs.

- We could probably get all the info to generate a markdown here using the module info list functions since all functions have docs defined.. look into this
  - implemented using [platyPS](https://github.com/PowerShell/platyPS)

## Future enhancements

- Do some research about useful modules
- take inspiration from past works. => Go Through/Cleanup all old scripts, add to github, ... **CLEANUP**

### TODO: 

#### Implement these useful functions into module

- set aliases, docker compose up -d (dcu) & docker compose down (dcd)
- **Power setting configuration**, take parameters to set the mode.
- Enable developer mode
- **File explorer options**, Adjust settings to show hidden files and extensions.
- Taskbar Customization
- Privacy Settings
- Auto enable numlock
- Enable sudo on windows ( currently via dev settings), set terminal as default terminal
- Firefox deployed with extension ( containers / Simple Tabs Groups / Adblock plus) => with Firefox account or in script ... ?

#### Code quality enhancements

- add static code checking using `https://github.com/PowerShell/PSScriptAnalyzer`
  - maybe add to pipeline or shift left with githook ?
- add testing of functions using [Pester](https://github.com/PowerShell/PowerShell/tree/master/test/powershell)
  - also maybe add to pipeline

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