# Publish module to PSGallery for modularity

You can publish your PowerShell module to the PowerShell Gallery, which allows to import it directly using the `Install-Module` or `Import-Module` cmdlets. Here's how you can do it:

### Steps to publish your module:

1. **Prepare the module:**
   - Create a `.psm1` file (PowerShell module script) where you define your functions and variables.
   - Create a manifest file (`.psd1`) that describes the module (name, version, author, etc.). You can generate this using `New-ModuleManifest`.
     ```powershell
     New-ModuleManifest -Path example.psd1 -RootModule example.psm1 -FunctionsToExport '*' -Author "MKTHEPLUGG" -ModuleVersion "0.0.1"
     
     # example from pipeline
     New-ModuleManifest -Path "$env:GITHUB_WORKSPACE\output\module\PDS.psd1" `
          -RootModule PDS `
          -FunctionsToExport '*'  `
          -Author "MKTHEPLUGG" -ModuleVersion "${{ steps.gitversion.outputs.semVer }}"  `
          -Description 'Personal Deploy Script'  `
          -CompanyName 'meti.pro'  `
          -ReleaseNotes "$env:message"
     ```

2. **Create a PowerShell Gallery account:**
   - Go to the [PowerShell Gallery](https://www.powershellgallery.com/) and create an account.

3. **Register and publish your module:**
   - After creating an account, you need to register your module using an API key from the gallery:
     - Go to your profile on the PowerShell Gallery website and generate an API key.
   - Once you’ve done that, publish your module with the following command:
     ```powershell
     # import-module .\PDS.psm1
     Publish-Module -Name <moduleName>.psm1 -NuGetApiKey <apiKey> 
     ```
   - you can publish any script using this command:
     ```powershell
     Publish-Script -Path <scriptPath> -NuGetApiKey <apiKey> 
     ```
4. **Use the module in your scripts:**
   - After it's published, you or anyone can install and import it with:
     ```powershell
     Install-Module -Name YourModuleName
     Import-Module -Name YourModuleName
     ```

### Considerations:
- **Versioning:** Ensure you update the version in the manifest each time you make changes. **Handled by pipeline**
- **Dependencies:** If your module depends on others, specify them in the manifest file.
- **Testing:** Use `Test-ModuleManifest` to validate your module before publishing. **To be included in pipeline, we don't do any testing for the moment**