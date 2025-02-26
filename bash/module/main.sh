#!/bin/bash
source install.sh
source sysadmin.sh
source public.sh

# how about we verify if curl is installed and provision the scripts like this on any random host ? Could be a great entry point to provide 1 single file.
# source <(curl -fsSL "https://raw.githubusercontent.com/michielvha/PDS/main/bash/module/install.sh")