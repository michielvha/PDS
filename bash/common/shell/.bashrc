# My personal .bashrc file

source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/software/python.sh)

# - aliases -
# Python
alias venv=set_venv
alias python=python3
alias pip=pip3
# kubectl
alias kgp='kubectl get pods'
alias kga='kubectl get all'
alias kgn='kubectl get nodes'
alias kgs='kubectl get services'
alias kge='kubectl get events'
alias kgl='kubectl get logs'