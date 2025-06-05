# My personal .bashrc file

source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/software/python.sh)

alias venv=set_venv
# Python aliases
alias python=python3
alias pip=pip3
# kubectl aliases
alias kgp='kubectl get pods'
alias kga='kubectl get all'
alias kgn='kubectl get nodes'
alias kgs='kubectl get services'
alias kge='kubectl get events'
alias kgl='kubectl get logs'