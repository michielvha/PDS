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
