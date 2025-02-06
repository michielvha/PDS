#!/bin/bash
# Dependencies:
source module/public.sh

# upgrade system
full_upgrade

# set locale

# install software

# install & configure zsh
install_zsh
configure_zsh

# extra system config
update_system_cron_entry