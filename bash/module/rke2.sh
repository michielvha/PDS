# RKE2 module for RKE2 installation and configuration
# purpose: bootstrap RKE2 nodes.
# ------------------------------------------------------------------------------------------------------------------------------------------------

install_rke2_server() {
  echo "🚀 Configuring RKE2 Server Node..."

  # Default parameter values
  local LB_HOSTNAME="loadbalancer.example.com"

  # Parse options using getopts
  while getopts "l:" opt; do
    case "$opt" in
      l) LB_HOSTNAME="$OPTARG" ;;  # -l <loadbalancer-hostname>
      \?)
        echo "❌ Invalid option: -$OPTARG"
        echo "Usage: install_rke2_server [-l <loadbalancer-hostname>]"
        return 1
        ;;
    esac
  done

  # environment
  local ARCH=$(uname -m | cut -c1-3)
  local FQDN=$(hostname -f)

  # Install RKE2
  curl -sfL https://get.rke2.io | sh -

  # Ensure the config directory exists
  mkdir -p /etc/rancher/rke2

  # Write configuration to /etc/rancher/rke2/config.yaml
  # https://docs.rke2.io/reference/server_config
  cat <<EOF > /etc/rancher/rke2/config.yaml
node-label:
  - "environment=production"
  - "arch=${ARCH}"
  - "purpose=system"
cni: cilium
tls-san:
  - $FQDN
  - "$LB_HOSTNAME"
EOF

  # Enable and start RKE2 server
  echo "⚙️  Starting RKE2 server..."
  sudo systemctl enable --now rke2-server && echo "✅ RKE2 Server node bootstrapped."
}


install_rke2_agent() {
  echo "🚀 Configuring RKE2 Agent Node..."

  # Default parameter values
  local LB_HOSTNAME="loadbalancer.example.com"

  # Parse options using getopts
  while getopts "l:" opt; do
    case "$opt" in
      l) LB_HOSTNAME="$OPTARG" ;;  # -l <loadbalancer-hostname>
      \?)
        echo "❌ Invalid option: -$OPTARG"
        echo "Usage: install_rke2_server [-l <loadbalancer-hostname>]"
        return 1
        ;;
    esac
  done

  # environment
  local ARCH=$(uname -m | cut -c1-3)
  local FQDN=$(hostname -f)

  # Install RKE2
  curl -sfL https://get.rke2.io | sh -

  # Ensure the config directory exists
  mkdir -p /etc/rancher/rke2

  # Write configuration to /etc/rancher/rke2/config.yaml
  # https://docs.rke2.io/reference/linux_agent_config
  cat <<EOF > /etc/rancher/rke2/config.yaml
server: "https://loadbalancer.example.com:9345"
token:
node-label:
  - "environment=production"
  - "arch=${ARCH}"
  - "purpose=$PURPOSE"
cni: cilium
tls-san:
  - $FQDN
  - "$LB_HOSTNAME"
EOF

  # Enable and start RKE2 agent
  echo "⚙️  Starting RKE2 agent..."
  sudo systemctl enable --now rke2-agent && echo "✅ RKE2 Agent node bootstrapped."
}

configure_rke2_bash() {
  local profile_file="/etc/profile.d/rke2.sh"

  # Ensure the file exists
  sudo touch "$profile_file"

  # Add RKE2 to the PATH if not already present
  grep -q 'export PATH=.*:/var/lib/rancher/rke2/bin' "$profile_file" || echo "export PATH=\$PATH:/var/lib/rancher/rke2/bin" | sudo tee -a "$profile_file" > /dev/null

  # Add KUBECONFIG if not already present
  grep -q 'export KUBECONFIG=/etc/rancher/rke2/rke2.yaml' "$profile_file" || echo "export KUBECONFIG=/etc/rancher/rke2/rke2.yaml" | sudo tee -a "$profile_file" > /dev/null

  # Source the profile file to apply changes immediately
  source "$profile_file"
}

configure_rke2_host() {
  echo "🚀 Default RKE2 Node Config..."

  # Disable swap if not already disabled
  if free | awk '/^Swap:/ {exit !$2}'; then
    echo "⚙️  Disabling swap..."
    sudo swapoff -a
    sudo sed -i '/swapfile/s/^/#/' /etc/fstab
  else
    echo "✅ Swap is already disabled."
  fi

  # TODO: add check if cilium ebpf is enabled, this config is only needed in kube-proxy mode.
  local sysctl_file="/etc/sysctl.d/k8s.conf"

  echo "🛠️  Applying sysctl settings for Kubernetes (kube-proxy) networking..."
  cat <<EOF | sudo tee "$sysctl_file" > /dev/null
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

  sudo sysctl --system > /dev/null && echo "✅ Sysctl settings applied successfully."

  sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward
}

configure_ufw_rke2_server() {
  # Allow Kubernetes API (6443) from agent nodes
  sudo ufw allow proto tcp from any to any port 6443 comment "RKE2 API Server"

  # Allow RKE2 supervisor API (9345) from agent nodes
  sudo ufw allow proto tcp from any to any port 9345 comment "RKE2 Supervisor API"

  # Allow kubelet metrics (10250) from all nodes
  sudo ufw allow proto tcp from any to any port 10250 comment "kubelet metrics"

  # Allow etcd client port (2379) between RKE2 server nodes
  sudo ufw allow proto tcp from any to any port 2379 comment "etcd client port"

  # Allow etcd peer port (2380) between RKE2 server nodes
  sudo ufw allow proto tcp from any to any port 2380 comment "etcd peer port"

  # Allow etcd metrics port (2381) between RKE2 server nodes
  sudo ufw allow proto tcp from any to any port 2381 comment "etcd metrics port"

  # Allow NodePort range (30000-32767) between all nodes
  sudo ufw allow proto tcp from any to any port 30000:32767 comment "Kubernetes NodePort range"

  echo "✅ UFW rules configured for RKE2 Server Node."
}

configure_ufw_rke2_agent() {
  # Allow kubelet metrics (10250) from all nodes
  sudo ufw allow proto tcp from any to any port 10250 comment "kubelet metrics"

  # Allow NodePort range (30000-32767) between all nodes
  sudo ufw allow proto tcp from any to any port 30000:32767 comment "Kubernetes NodePort range"

  echo "✅ UFW rules configured for RKE2 Agent Node."
}
