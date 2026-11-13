## Debian Functions

| Function | Description |
|---|---|
| install_tokyonight_gtk_theme | Installs and applies the Tokyonight GTK theme |
| setup_gnome_extras | Installs GNOME Tweaks and useful shell extensions |
| set_gnome_fonts | Configures GNOME fonts and rendering settings |
| install_juno_theme | Installs and applies the Juno GTK theme |
| jetbrains_font | Installs the JetBrains Mono font system-wide |
| install_librewolf | Installs librewolf browser |
| install_vscode | Installs Visual Studio Code on a Debian-based system by adding the Microsoft repository and installing the package. |
| install_azcli | Installs and configures the Azure CLI |
| install_zen | Installs Zen Browser |
| install_kubectl | Installs and configures kubectl |
| verify_hashicorp_gpg_key | Downloads and verifies the HashiCorp GPG signing key by fetching the expected fingerprint from HashiCorp's website |
| add_hashicorp_repository | Adds the HashiCorp apt repository to the system's package sources |
| install_hashicorp_product | Installs a HashiCorp product after verifying the GPG key and adding the repository |
| install_terraform | Installs HashiCorp Terraform on a Debian-based system |
| install_vault | Installs HashiCorp Vault on a Debian-based system |
| install_consul | Installs HashiCorp Consul on a Debian-based system |
| install_nomad | Installs HashiCorp Nomad on a Debian-based system |
| install_packer | (legacy standalone) Installs HashiCorp's Packer and configures the system as a Packer build host. |
| install_virtio_win_iso | Downloads or refreshes the Fedora "stable" VirtIO driver ISO for Windows guests (default: Proxmox VE `/var/lib/vz/template/iso`) |
| enable_virtio_win_iso_updates | Schedules a weekly `install_virtio_win_iso` run through `/etc/cron.d/pds-virtio-win` |

### VirtIO drivers for Windows guests

Proxmox VE and Debian do not package `virtio-win`, and upstream only publishes a dnf repository, so there is no APT source to subscribe to. `install_virtio_win_iso` keeps a single `virtio-win.iso` current instead. It follows upstream's `stable-virtio` link over HTTPS only (upstream's redirects fall back to plain HTTP), reads the version from the ISO header, and downloads only when that version changed. The new file replaces the old one atomically, so attached VMs keep working.

On a Proxmox host, as root, after adding the PDS APT repository (see [packaging](../../packaging/README.md#apt-repository-recommended)):

```bash
apt install -y pds && bash -c '. /usr/share/pds/debian/admin/virtio_win.sh && install_virtio_win_iso && enable_virtio_win_iso_updates'
```

`apt upgrade` updates the function and the weekly cron job runs the installed version. Pass another ISO directory as the only argument to use different storage. Remove `/etc/cron.d/pds-virtio-win` to stop the refresh. The ISO then shows up as `local:iso/virtio-win.iso`; attach it as a second CD/DVD drive and run `virtio-win-gt-x64.msi` from it inside Windows.
