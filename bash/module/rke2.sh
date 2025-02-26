install_rke2_server() {
  # environment
  local ARCH=$(uname -m | cut -c1-3)

  # Install RKE2
  curl -sfL https://get.rke2.io | sh -

  # Ensure the config directory exists
  mkdir -p /etc/rancher/rke2

  # Write configuration to /etc/rancher/rke2/config.yaml
  cat <<EOF > /etc/rancher/rke2/config.yaml
server: "https://s1.example.com:9345"
node-label:
  - "environment=production"
  - "arch=${ARCH}"
  - "purpose=system"
cni: cilium
enable-metrics: true
tls-san:
  - "s1.example.com"
EOF

  # Enable and start the RKE2 server
  systemctl enable --now rke2-server
}


install_rke2_agent() {
  # environment
  local ARCH=$(uname -m | cut -c1-3)
  local FQDN=$(hostname -f)

  # Install RKE2
  curl -sfL https://get.rke2.io | sh -

  # Ensure the config directory exists
  mkdir -p /etc/rancher/rke2

  # Write configuration to /etc/rancher/rke2/config.yaml
  cat <<EOF > /etc/rancher/rke2/config.yaml
server: "https://rke2-master.example.com:9345"
token:
node-label:
  - "environment=production"
  - "arch=${ARCH}"
  - "purpose=$PURPOSE"
cni: cilium
enable-metrics: true
tls-san:
  - $FQDN
EOF

  # Enable and start the RKE2 server
  systemctl enable --now rke2-agent
}