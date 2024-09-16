# install chocolatey package manager

Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# close and reopen shell if needed

choco install nmap `
              git `
              azure-cli `
              terraform `
              pycharm-community `
              angryip `                 # fast port scans ?
              unxutils `                # a bunch of common unix utils like grep etc (look into overwriting aliases)


# tes


# once azure cli is installed use it to install kubectl

# shell customizations with the startship and config file thing