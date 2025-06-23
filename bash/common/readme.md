## Common Functions

| Function | Description |
|---|---|
| install_go | Installs the latest version of Golang and configures the environment for the current user. |
| set_go_env | Configures the Go environment variables for the current user. |
| setup_edgectl_dev_env | Sets up the development environment for edgectl with Go installed for the root user. Using root user because edgectl requires root privileges to run. |
| install_minikube | Installs the latest version of minikube. |
| get_latest_github_binary | Downloads and installs the latest release of a binary from a specified GitHub repository. |
| install_aws_cli | Installs and configures the AWS CLI |
| install_azcli | Installs and configures the Azure CLI |
| install_zi | Installs and configures Zi, a package manager for ZSH |
| configure_zsh | Configures ZSH using Zi with plugins and settings for an enhanced shell experience |
| set_default_zsh | Sets ZSH as the default shell for the current user |
| install_nerd_fonts | Install the recommended fonts for Powerlevel10k and configure GNOME Terminal to use them |
| pre_commit_hook | Pre-commit hook that automatically formats Go code using gofumpt |