# Cloudflare tunnel hosts

`bootstrap_cloudflared_host.sh` prepares a Linux host to create and run its own
Cloudflare tunnels. It installs Arch's signed `cloudflared` package when needed;
on other distributions install `cloudflared` first using
`bash/common/software/install_cloudflared.sh`.

Run from a PDS checkout on an authenticated machine such as Fedora:

```bash
bash bash/common/cloud/bootstrap_cloudflared_host.sh \
  --ssh sysadmin@arch-1.tail6948f.ts.net \
  --cert-file ~/.cloudflared/cert.pem
```

The SSH account needs key authentication, a verified host key, a working systemd
user session, and permission to run `sudo -n pacman` and `sudo -n loginctl`.
Configure the SSH identity in `~/.ssh/config` if necessary. For initial key setup,
use `ssh-copy-id -i ~/.ssh/YOUR_KEY.pub sysadmin@arch-1.tail6948f.ts.net` and enter
the account password interactively. Keep passwords and private keys outside PDS.

Alternatively run the script directly on the target with `--cert-file` pointing
to a securely transferred account certificate. A browser login with
`cloudflared tunnel login` can obtain a new certificate instead.

The bootstrap transfers only `cert.pem`, with directory mode `0700` and file mode
`0600`, and refuses to overwrite a different certificate. This certificate grants
account-level tunnel management and DNS routing privileges; treat the destination
as a trusted administration host. See [Cloudflare tunnel permissions](https://developers.cloudflare.com/tunnel/features/locally-managed-tunnels/tunnel-permissions/).

The script verifies authentication by listing tunnels. It installs the user unit
`pds-cloudflared@.service` and enables lingering so enabled instances run after
logout and at boot. Repeating the bootstrap preserves the same certificate and
unit. It creates no tunnels or DNS records and starts no connector. Fedora's
running tunnel credentials and routing configuration stay on Fedora.

## Publish a service on the new host

Run these commands as the target SSH user. Choose a new tunnel name and hostname
for each service; do not reuse Fedora's active tunnel IDs or JSON credentials.

```bash
cloudflared tunnel create arch-1-app
# Note the UUID printed by the command. Replace UUID below with that value.
cat > ~/.cloudflared/arch-1-app.yml <<EOF
tunnel: UUID
credentials-file: $HOME/.cloudflared/UUID.json
ingress:
  - hostname: app.example.com
    service: http://127.0.0.1:8080
  - service: http_status:404
EOF
chmod 600 ~/.cloudflared/arch-1-app.yml ~/.cloudflared/UUID.json
cloudflared tunnel --config ~/.cloudflared/arch-1-app.yml ingress validate
cloudflared tunnel route dns arch-1-app app.example.com
systemctl --user enable --now pds-cloudflared@arch-1-app.service
systemctl --user status pds-cloudflared@arch-1-app.service
journalctl --user -u pds-cloudflared@arch-1-app.service -f
```

Replace `app.example.com` and port `8080` with the actual service. The DNS route
publishes the service on that hostname; configure Cloudflare Access before
publishing applications that need authentication. Tunnel creation writes its own
JSON credential on this host. Each service instance reads its matching
`~/.cloudflared/NAME.yml`; use a catch-all `http_status:404` rule last.

For a temporary URL without a custom domain, no account certificate is required:

```bash
cloudflared tunnel --url http://127.0.0.1:8080
```

## Validate changes to the bootstrap

These checks use dummy credentials and make no network requests:

```bash
bash -n bash/common/cloud/bootstrap_cloudflared_host.sh bash/common/software/install_cloudflared.sh
python3 -m unittest discover -s tests -v
```

The GitHub Actions workflow runs the same checks. Host installation and Cloudflare
connectivity need a separate check against the destination host.
