# PDS

I want to create a personal deploy script that will enable me to easily install all required tooling onto either a windows or linux vm. I'll be using bash and powershell respectively.

I'll be wanting to use package managers or either wget to fetch the urls

tooling I require

- nmap
- pycharm
- git
- az cli
- kubernetes tools ( helm / )
- terraform
- wireguard client

## windows specific
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
- pipeline is not running on managed host, maybe run own hosts in kubernetes after RKE2 Setup ?
- unifi server local host?
