# How to use modules in Powershell

### 1. **Create a PowerShell Module (`.psm1` File)**

1. **Create a Directory** for your module:
   PowerShell modules should be placed in a directory named after the module itself.

   ```powershell
   New-Item -Path "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\MyModule" -ItemType Directory
   ```

2. **Create a `.psm1` File**:
   Inside the module directory, create a `.psm1` file. This file will contain your functions.

   ```powershell
   New-Item -Path "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\MyModule\MyModule.psm1" -ItemType File
   ```

3. **Add Functions to the `.psm1` File**:
   Open the `.psm1` file and define your functions. For example:

   ```powershell
   # Inside MyModule.psm1

   function Get-HelloWorld {
       Write-Host "Hello, World!"
   }

   function Add-Numbers {
       param (
           [int]$a,
           [int]$b
       )
       return $a + $b
   }
   ```

4. **Optionally Create a Module Manifest (`.psd1` File)**:
   A manifest file is not required but can provide additional metadata about the module.

   ```powershell
   New-ModuleManifest -Path "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\MyModule\MyModule.psd1"
   ```

### 2. **Import the PowerShell Module into a Script**

To use the module in your PowerShell script, you need to import it using the `Import-Module` cmdlet.

```powershell
# Import the module (assuming it's in the default modules folder)
Import-Module MyModule
# or dot source it
```

### 3. **If the Module is Not in the Default Path**
If your module is not in the default module path (`$env:PSModulePath`), you can specify the full path when importing:

```powershell
# Import the module from a custom path
Import-Module "C:\path\to\MyModule\MyModule.psm1"
```

### 4. **If the modules code gets updated**
If your module has been updated be sure to update to get the latest features:

```powershell
Update-Module -Name ModuleName
```

### 5. **Get information about your module**
use the ``get-command`` cmdlet to view what's inside the module:

```powershell
Get-Command -Module ModuleName
```


### Summary

1. **Create a module** by creating a `.psm1` file containing your functions.
2. **Place the `.psm1` file** in a directory named after your module (e.g., `MyModule`).
3. **Import the module** in your script using `Import-Module` and call the functions defined in the module.


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