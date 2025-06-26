Function Template-Function {
    <#
    .SYNOPSIS
    
    Provide a brief summary of what the function does. This should be a concise description, typically one or two sentences, that gives an overview of the function's purpose and functionality.

    .DESCRIPTION

    Provide a description for the function

    .PARAMETER Example

    provide info about the parameter

    .EXAMPLE

    Give an example of how the function can be used

    .NOTES

    extra notes

    .LINK

    extra links

    #>

    # Parameters if any
    param (
        [Parameter(Mandatory=$true)]
        [string]$Example
    )

    # function definition

}

<#

The following verbs are approved by Microsoft for use in PowerShell functions.
Using these verbs ensures your functions follow PowerShell's naming conventions.
Always use these verbs to maintain consistency and follow best practices.

you can check via the terminal with `Get-Verb | Sort-Object -Property Group, Verb | Format-Table -GroupBy Group -Property Verb, Synopsis -AutoSize`
Providing an export below for easy reference.

    1. Common Verbs
    - Add      : Adds a resource to a container, or attaches an item to another item
    - Clear    : Removes all items from a container but doesn't delete the container
    - Close    : Changes the state of a resource to make it inaccessible
    - Copy     : Copies a resource to another name or container
    - Enter    : Creates an entry in a log or record or specifies entering a new context
    - Exit     : Sets the current environment or context to the most recently used context
    - Find     : Looks for an object in a container that is unknown, implied, optional, or specified
    - Format   : Arranges objects in a specified form or layout
    - Get      : Retrieves a resource or gets information about a resource
    - Hide     : Makes a resource undetectable
    - Join     : Combines resources into one resource
    - Lock     : Secures a resource, preventing modification by other users
    - Move     : Moves a resource from one location to another
    - New      : Creates a new resource
    - Open     : Changes the state of a resource to make it accessible
    - Optimize : Increases the effectiveness of a resource
    - Pop      : Removes an item from the top of a stack
    - Push     : Adds an item to the top of a stack
    - Redo     : Resets a resource to the state after Undo
    - Remove   : Deletes a resource from a container
    - Rename   : Changes the name of a resource
    - Reset    : Sets a resource back to its original state
    - Resize   : Changes the size of a resource
    - Search   : Creates a reference to a resource in a container
    - Select   : Locates a resource in a container
    - Set      : Replaces data on an existing resource or creates a resource that contains data
    - Show     : Makes a resource visible to the user
    - Skip     : Bypasses one or more resources in a sequence
    - Split    : Separates parts of a resource
    - Step     : Moves to the next point or resource in a sequence
    - Switch   : Specifies an alternate resource to use
    - Undo     : Sets a resource to its previous state
    - Unlock   : Releases a resource that was locked
    - Watch    : Continually inspects or monitors a resource for changes

    2. Communications Verbs
    - Connect     : Creates a link between a source and a destination
    - Disconnect  : Breaks the link between a source and a destination
    - Read        : Acquires information from a source
    - Receive     : Accepts information from a source
    - Send        : Delivers information to a destination
    - Write       : Adds information to a target

    3. Data Verbs
    - Backup      : Stores data by replicating it
    - Checkpoint  : Creates a snapshot of the current state of data or configuration
    - Compare     : Evaluates the differences between resources
    - Compress    : Compacts data of a resource
    - Convert     : Changes the data type of a resource
    - ConvertFrom : Imports data from another format
    - ConvertTo   : Exports data to another format
    - Dismount    : Detaches a named entity from a location
    - Edit        : Modifies existing data based on user input
    - Expand      : Restores data from a compressed state
    - Export      : Encapsulates and saves data to persistent storage
    - Group       : Arranges resources into discrete sets
    - Import      : Creates resource from data stored in persistent storage
    - Initialize  : Prepares a resource for use, setting it to a default state
    - Limit       : Applies constraints to a resource
    - Merge       : Creates a single resource from multiple resources
    - Mount       : Attaches a named entity to a location
    - Out         : Sends data out of an environment
    - Publish     : Makes a resource available to others
    - Restore     : Sets a resource to a predefined state, such as by reapplying settings
    - Save        : Preserves data to avoid loss
    - Sync        : Ensures resources in two locations are identical
    - Unpublish   : Makes a resource unavailable to others
    - Update      : Brings a resource up-to-date to maintain compatibility

    4. Diagnostic Verbs
    - Debug       : Examines a resource to diagnose operational problems
    - Measure     : Identifies resources consumed by a specified operation
    - Ping        : Confirms the presence of an active resource
    - Repair      : Restores a resource to a usable condition
    - Resolve     : Maps a shorthand representation of a resource to a more complete one
    - Test        : Verifies the operation or consistency of a resource
    - Trace       : Tracks the activities of a resource

    5. Lifecycle Verbs
    - Approve     : Confirms or agrees to the status of a resource
    - Assert      : Affirms the state of a resource
    - Build       : Creates an artifact from components
    - Complete    : Concludes an operation
    - Confirm     : Acknowledges, verifies, or validates the state of a resource
    - Deny        : Refuses, objects to, or blocks the state of a resource
    - Deploy      : Sends an application, website, or solution to a remote target
    - Disable     : Configures a resource to an unavailable or inactive state
    - Enable      : Configures a resource to an available or active state
    - Install     : Places a resource in a location and optionally initializes it
    - Invoke      : Performs an action, such as running a command or a method
    - Register    : Creates an entry for a resource in a repository
    - Request     : Asks for a resource or permission
    - Restart     : Stops an operation and then starts it again
    - Resume      : Starts an operation that has been suspended
    - Start       : Initiates an operation
    - Stop        : Discontinues an activity
    - Submit      : Presents a resource for approval
    - Suspend     : Pauses an operation
    - Uninstall   : Removes a resource from an indicated location
    - Unregister  : Removes the entry for a resource from a repository
    - Wait        : Pauses an operation until a specified event occurs

    6. Security Verbs
    - Block       : Restricts access to a resource
    - Grant       : Allows access to a resource
    - Protect     : Guards a resource from attack or loss
    - Revoke      : Specifies an action that rescinds access permission to a resource
    - Unblock     : Removes restrictions on a resource
    - Unprotect   : Removes safeguards from a resource

    7. Other Verbs
    - Use         : Employs a resource with a specified purpose
#>
