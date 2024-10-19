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

# Call the functions from the module
Get-HelloWorld
$sum = Add-Numbers -a 5 -b 10
Write-Host "Sum: $sum"
```

### 3. **If the Module is Not in the Default Path**
If your module is not in the default module path (`$env:PSModulePath`), you can specify the full path when importing:

```powershell
# Import the module from a custom path
Import-Module "C:\path\to\MyModule\MyModule.psm1"
```

### Summary

1. **Create a module** by creating a `.psm1` file containing your functions.
2. **Place the `.psm1` file** in a directory named after your module (e.g., `MyModule`).
3. **Import the module** in your script using `Import-Module` and call the functions defined in the module.


# Publish module to PSGallery for modularity

You can publish your PowerShell module to the PowerShell Gallery, which allows others (or your scripts) to import it directly using the `Install-Module` or `Import-Module` cmdlets, just like PSReadline. Here's how you can do it:

### Steps to publish your module:

1. **Prepare the module:**
   - Create a `.psm1` file (PowerShell module script) where you define your functions and variables.
   - Create a manifest file (`.psd1`) that describes the module (name, version, author, etc.). You can generate this using `New-ModuleManifest`.
     ```powershell
     New-ModuleManifest -Path example.psd1 -RootModule example.psm1 -FunctionsToExport '*' -Author "MKTHEPLUGG"
     ```

2. **Create a PowerShell Gallery account:**
   - Go to the [PowerShell Gallery](https://www.powershellgallery.com/) and create an account.

3. **Register and publish your module:**
   - After creating an account, you need to register your module using an API key from the gallery:
     - Go to your profile on the PowerShell Gallery website and generate an API key.
   - Once you’ve done that, publish your module with the following command:
     ```powershell
     Publish-Module -Name <moduleName> -NuGetApiKey <apiKey> 
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
- **Versioning:** Ensure you update the version in the manifest each time you make changes.
- **Dependencies:** If your module depends on others, specify them in the manifest file.
- **Testing:** Use `Test-ModuleManifest` to validate your module before publishing.

This way, you can keep your script modular and easily manage updates by just updating the module instead of the entire script.