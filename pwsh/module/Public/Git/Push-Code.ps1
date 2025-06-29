function Push-Code {
<#
.SYNOPSIS
    Quickly stage, commit, and push code to a Git repository.

.DESCRIPTION
    This function allows you to stage all changes, commit them with a provided message, 
    and push to a specified branch of a Git repository (defaulting to 'main').

.PARAMETER Message
    The commit message to use when committing changes.

.PARAMETER Branch
    The Git branch to push to. Defaults to 'main'.

.EXAMPLE
    Push-Code -Message "Fix: Corrected typo in README" -Branch "main"
    Push-Code -m "Fix: Corrected typo in README" -b "main"
    This command will stage all changes, commit with the message "Fix: Corrected typo in README",
    and push those changes to the 'main' branch.

.NOTES
    Ensure you are in the correct repository folder before running this command.
    Requires Git to be installed and available in your PATH.

    Author: Michiel VH
.LINK
    https://git-scm.com/docs
#>

    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $false,
            HelpMessage = "Provide the commit message."
        )]
        [Alias('m')]
        [string]
        $Message = 'Update: Code changes',

        [Parameter(
            Mandatory = $false,
            HelpMessage = "Specify which branch to push to."
        )]
        [Alias('b')]
        [string]
        $Branch = 'main'
    )
    
    try {
        Write-Verbose "Staging all changes..."
        git add .
        
        Write-Verbose "Committing with message: $Message"
        git commit -m $Message
        
        Write-Verbose "Pushing to branch '$Branch'..."
        git push -u origin $Branch
        
        Write-Host "Successfully pushed changes to '$Branch' branch."
    }
    catch {
        Write-Error "An error occurred while pushing the code: $_"
    }
}
