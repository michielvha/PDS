# Legacy Bash modules

New provisioning uses the PDS package and sources `/usr/share/pds/init.sh` explicitly.
Maintained helpers live under `bash/common` and `bash/debian`.

`sysadmin.sh` is a compatibility import for a complete checkout and forwards to `bash/common/admin/sysadmin.sh`.
The validated sudoers implementation is `bash/common/shell/set_sudo_nopasswd.sh`.
The legacy module tree is not included in the Debian package.

The supported shell setup uses `install_zi` and `configure_zsh`, with the existing Powerlevel10k preset.
The historical Oh My Zsh helpers in `public.sh` remain archived alternatives and are not selected by the current bootstrap.
Historical RKE2 names in the previous index do not establish that those functions exist in the current package.
