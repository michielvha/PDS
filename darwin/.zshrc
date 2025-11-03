# Custom .zshrc file, should be placed in zshrc.d and imported here, this way you only need to write one statement to the users .zshrc file, this prevents the need to check if the config
#  is already present in the file.

# Alias for Iterm: open current context
alias iterm='open -a iTerm .'
# Alias for kubelogin: required if installed via brew
alias kubelogin="kubectl oidc-login"
