# Import the function (Assuming the function is in the same directory)
. "$PSScriptRoot\Refresh-Env.ps1" # Import-Module PDS

# Run Pester Tests
Describe "Refresh-Environment Function Tests" {
    
    BeforeAll {
        # Backup existing TEST_ENV_VAR (if it exists)
        $existingValue = [System.Environment]::GetEnvironmentVariable("TEST_ENV_VAR", "Process")
        $existingUserValue = Get-ItemProperty -Path "HKCU:\Environment" -Name "TEST_ENV_VAR" -ErrorAction SilentlyContinue

        # Set a test value in the registry
        Set-ItemProperty -Path "HKCU:\Environment" -Name "TEST_ENV_VAR" -Value "RegistryValue" -Force
        [System.Environment]::SetEnvironmentVariable("TEST_ENV_VAR", "OldSessionValue", "Process")
    }

    It "Should reload the TEST_ENV_VAR from registry" {
        # Run the refresh function
        Refresh-Environment

        # Check if the session variable matches the registry value
        $sessionValue = [System.Environment]::GetEnvironmentVariable("TEST_ENV_VAR", "Process")
        $sessionValue | Should -Be "RegistryValue"
    }

    It "Should correctly merge system and user Path variables" {
        # Get values before and after refresh
        $beforePath = [System.Environment]::GetEnvironmentVariable("Path", "Process")
        Refresh-Environment
        $afterPath = [System.Environment]::GetEnvironmentVariable("Path", "Process")

        # Check that Path was modified and not empty
        $afterPath | Should -Not -BeEmpty
        $afterPath | Should -Not -BeNullOrEmpty

        # Ensure it contains at least some of the expected paths
        $systemPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
        $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")

        foreach ($pathEntry in $systemPath -split ";") {
            $afterPath | Should -Contain $pathEntry
        }
        foreach ($pathEntry in $userPath -split ";") {
            $afterPath | Should -Contain $pathEntry
        }
    }

    AfterAll {
        # Restore original TEST_ENV_VAR value
        if ($existingUserValue) {
            Set-ItemProperty -Path "HKCU:\Environment" -Name "TEST_ENV_VAR" -Value $existingUserValue.TEST_ENV_VAR -Force
        } else {
            Remove-ItemProperty -Path "HKCU:\Environment" -Name "TEST_ENV_VAR" -ErrorAction SilentlyContinue
        }

        # Restore process environment variable
        [System.Environment]::SetEnvironmentVariable("TEST_ENV_VAR", $existingValue, "Process")
    }
}
