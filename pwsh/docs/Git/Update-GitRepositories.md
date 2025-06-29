# Update-GitRepositories

Updates all Git repositories in subdirectories by performing a git pull operation.

## SYNOPSIS
Updates all Git repositories in subdirectories by performing a git pull operation.

## DESCRIPTION
This function searches for all directories containing a .git folder in the specified root directory
(or the current directory by default), and performs a git pull operation in each one to update them
to the latest version of the current branch.

## PARAMETERS

### -RootDirectory
The root directory containing the Git repositories to update. Defaults to the current directory.

```yaml
Type: String
Parameter Sets: (All)
Aliases: None
Required: False
Position: 0
Default value: Current Directory
Accept pipeline input: False
Accept wildcard characters: False
```

### -Recurse
If specified, the function will search for Git repositories recursively in all subdirectories.

```yaml
Type: Switch
Parameter Sets: (All)
Aliases: None
Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Branch
The branch to checkout before pulling. If not specified, pulls the current branch.

```yaml
Type: String
Parameter Sets: (All)
Aliases: None
Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

## EXAMPLES

### Example 1
```powershell
Update-GitRepositories
```
Updates all Git repositories in the current directory.

### Example 2
```powershell
Update-GitRepositories -RootDirectory "C:\Projects"
```
Updates all Git repositories in the C:\Projects directory.

### Example 3
```powershell
Update-GitRepositories -Recurse
```
Updates all Git repositories in the current directory and all its subdirectories recursively.

### Example 4
```powershell
Update-GitRepositories -Branch main
```
Updates all Git repositories in the current directory, checking out the main branch first.

## NOTES
Requires Git to be installed and available in your PATH.

Author: Michiel VH

## RELATED LINKS
- [Git Pull Documentation](https://git-scm.com/docs/git-pull)
