# PDS

I want to create a personal deploy script that will enable me to easily install all required tooling onto either a windows or linux vm. I'll be using bash and powershell respectively.

I'll be wanting to use package managers or either wget to fetch the urls

tooling I require


| **Package**           | **Description**                                                                                     | **Purpose/Use Case**                                                                                 |
|-----------------------|-----------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------|
| **nmap**              | Nmap ("Network Mapper") is an open-source network scanning tool for network discovery and security auditing. | Useful for network exploration, security audits, and penetration testing.                             |
| **git**               | Git is a distributed version control system that allows developers to track changes in source code during software development. | Used for version control in software development, collaboration, and managing repositories.            |
| **azure-cli**         | The Azure Command-Line Interface (CLI) is a set of commands used to create and manage Azure resources. | Helps manage Azure resources via command line; ideal for scripting and automation in cloud environments.|
| **terraform**         | Terraform is an open-source infrastructure as code software tool for building, changing, and versioning infrastructure. | Automates the provisioning of infrastructure using code, ideal for managing cloud infrastructure.       |
| **pycharm-community** | PyCharm is an Integrated Development Environment (IDE) used for programming in Python. The community edition is free and open-source. | Best suited for Python development, providing code analysis, debugging, and testing features.           |
| **angryip**           | Angry IP Scanner is a fast and friendly network scanner. It is widely used by network administrators and security experts. | Scans IP addresses and ports to detect devices on a network.                                            |
| **unxutils**          | Unix-like command-line utilities compiled for Windows. Includes tools like `grep`, `sed`, `awk`, etc.  | Brings Unix command-line functionality to Windows systems. Useful for scripting and automation.         |
| **mobaxterm**         | MobaXterm is a terminal for Windows with an X11 server, tabbed SSH client, and many network tools.    | Provides advanced terminal features, SSH client, and networking tools in a single Windows application. |
| **starship**          | Starship is a fast and customizable prompt for any shell.                                            | Displays essential information (like Git status, AWS profiles) in a minimalist and customizable shell prompt. |
| **rpi-imager**        | Raspberry Pi Imager is a tool used to write Raspberry Pi OS and other images to SD cards and USB drives. | Simplifies installing operating systems onto Raspberry Pi devices.                                      |
| **openlens**          | OpenLens is an open-source IDE for managing Kubernetes clusters.                                     | Provides a graphical interface for managing Kubernetes clusters and workloads.                         |
| **grep**              | `grep` is a command-line utility for searching plain-text data for lines that match a regular expression. | Used for searching and pattern matching in text, commonly found in Unix-like systems.                  |


## windows specific

**next steps: debloat windows by using this [script](https://github.com/Raphire/Win11Debloat/tree/master) define which options and settings you want to set**

binaries installed in sys directory and added to path
- grep on windows
- cat on windows

shell config
- starship + ps readline config


various tweaks in registry

- numlock on by default
- backlit keyboard on by default if available => seems to be controlled by bios

## Linux Specific

configure ohmyzsh with history
set locale


### future enhancements:

- sync shell history across all devices
- unifi server local host?


### Script Docs
### Pipeline Docs