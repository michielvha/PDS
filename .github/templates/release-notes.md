## PDS (Portable Deploy Suite) v{{VERSION}}

### Installation

#### Direct Installation
```bash
# Download and install
wget https://github.com/{{REPOSITORY}}/releases/download/v{{VERSION}}/{{PACKAGE_NAME}}_{{VERSION}}_all.deb
sudo dpkg -i {{PACKAGE_NAME}}_{{VERSION}}_all.deb
sudo apt-get install -f
```

#### Usage
```bash
# Check installation
pds doctor

# List available functions
pds list

# Example usage
install_docker      # Install Docker
install_vscode      # Install VS Code
install_packer      # Install HashiCorp Packer
```

### What's Included

- **Software Installation Functions**: Docker, VS Code, kubectl, Azure CLI, HashiCorp tools and more
- **UI/Theme Setup**: Font and theme installation for GNOME
- **Development Environment**: Git and shell configuration tools
- **CLI Helper**: `pds` command for function discovery and management

### Features

✅ Auto-loading in interactive shells  
✅ CLI helper for function discovery  
✅ Opt-out support (`export PDS_DISABLE=1`)  
✅ Comprehensive function library  
✅ Easy installation and updates via APT  

### Compatibility

- Ubuntu 20.04, 22.04, 24.04
- Debian 10, 11, 12
- Any Debian-based distribution

### Documentation

- [Installation Guide](https://github.com/{{REPOSITORY}}/blob/main/packaging/README.md)
- [Function Reference](https://github.com/{{REPOSITORY}}/blob/main/bash/debian/readme.md)
- [Contributing](https://github.com/{{REPOSITORY}}/blob/main/CONTRIBUTING.md)
