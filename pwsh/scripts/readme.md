# Purpose

This powershell script is used to deploy my software stack to any windows host I might get from work or somewhere else.

I'm trying to make it as modular as possible 

### Prefered deployment method

Currently I first like to customize my base windows 11 image with [tiny11builder](https://github.com/ntdevlabs/tiny11builder). Afterwards this script can be applied to it in which ever way you seem fit (autologon,packer,...)

# Thoughts

**18/10/2024**
- Currently packing modules in script thinking about creating
    1. Main Online version using powershell gallery to store functions in modules.
    2. Portable Offline version doing something to package the modules inside the exe. 

**19/10/2024**
- Okey so let's say that the lite version is the main version and the full can be seperately maintained, this will make it easier to compile it automatically from the modules already created in the lite version

### Main Version

For this version of the powershell script we'll be using nuget to maintain all our powershell packages.

I'm trailing this out to see what it's like since I've never used it but seems to be a good way of managing packages within powershell using the native technologies.

### Portable version

This version can be ran without an active internet connection. Created by merging the module file with some execution commands to pack them all in one file.