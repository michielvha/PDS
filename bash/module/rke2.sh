# RKE2 module for RKE2 installation and configuration
# purpose: bootstrap RKE2 nodes.
# usage: quickly source this module with the following command:
# ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/module/rke2.sh) ` 
# ------------------------------------------------------------------------------------------------------------------------------------------------

# TODO: add logic if already installed, skip installation and proceed with configuration. or provide some kind of update functionality. We could check for the existance of these folders /etc/rancher /var/lib/kubelet /var/lib/etcd
# TODO: Look into harding the RKE2 installation with CIS benchmarks. SEL linux etc etc.
install_rke2_server() {
  # purpose: bootstrap a RKE2 server node
  # usage: install_rke2_server [-l <loadbalancer-hostname>]
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

  # perform default bootstrap configurations required on each RKE2 node.
  configure_rke2_host

 # Install RKE2
  echo "⬇️  Downloading and installing RKE2..."
  curl -sfL https://get.rke2.io | sudo sh - || { echo "❌ Failed to download RKE2. Exiting."; return 1; }

  # Ensure the config directory exists
  sudo mkdir -p /etc/rancher/rke2

  # Write configuration to /etc/rancher/rke2/config.yaml
  # https://docs.rke2.io/reference/server_config
  cat <<EOF | sudo tee /etc/rancher/rke2/config.yaml
node-label:
  - "environment=production"
  - "arch=${ARCH}"
  - "purpose=system"

cni: cilium
disable-kube-proxy: true    # Disable kube-proxy (since eBPF replaces it)
disable-cloud-controller: true # disable cloud controller since we are onprem.
tls-san: ["$FQDN", "$LB_HOSTNAME"]
EOF

  # Cilium debug
  # check if bpf is enabled
  # bpftool feature  | zgrep CONFIG_BPF /proc/config.gz if available.
  # verify cilium ebpf config is enabled:
  # kubectl -n kube-system exec -it ds/cilium -- cilium status --verbose
  # check cilium status
  # kubectl -n kube-system exec -it ds/cilium -- cilium status
  # show existing BPF tunnels
  # kubectl -n kube-system exec -it ds/cilium -- cilium-dbg bpf tunnel list

  cat <<EOF | sudo tee /var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-cilium
  namespace: kube-system
spec:
  valuesContent: |-
    kubeProxyReplacement: true
    k8sServiceHost: "localhost"
    k8sServicePort: "6443"
    hubble:
      enabled: true
      relay:
        enabled: true
      ui:
        enabled: true
EOF

  # Enable and start RKE2 server
  echo "⚙️  Starting RKE2 server..."
  sudo systemctl enable --now rke2-server || { echo "❌ RKE2 Server node bootstrap failed."; return 1; }
  echo "✅ RKE2 Server node bootstrapped."
}

# TODO: After server is fully tested refactor this function.
install_rke2_agent() {
  # purpose: bootstrap a RKE2 agent node
  # usage: install_rke2_agent [-l <loadbalancer-hostname>]
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
  echo "⬇️  Downloading and installing RKE2..."
  curl -sfL https://get.rke2.io | sudo sh - || { echo "❌ Failed to download RKE2. Exiting."; return 1; }

  # Ensure the config directory exists
  sudo mkdir -p /etc/rancher/rke2

  # Write configuration to /etc/rancher/rke2/config.yaml
  # https://docs.rke2.io/reference/linux_agent_config
  cat <<EOF | sudo tee /etc/rancher/rke2/config.yaml
server: "https://$LB_HOSTNAME:9345"
token:
node-label:
  - "environment=production"
  - "arch=${ARCH}"
  - "purpose=$PURPOSE"
tls-san: ["$FQDN", "$LB_HOSTNAME"]
EOF

  # Enable and start RKE2 agent
  echo "⚙️  Starting RKE2 agent..."
  sudo systemctl enable --now rke2-agent || { echo "❌ RKE2 Agent node bootstrap failed."; return 1; }
  echo "✅ RKE2 Agent node bootstrapped."
}

configure_rke2_bash() {
  # purpose: configure the shell for administration on an RKE2 bootstrapped node
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
  # purpose: perform default bootstrap configurations required on each RKE2 node.
  # TODO: maybe write to a file after config to check if already configured. When running another command that calls this command.
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

  # Load br_netfilter kernel module
  echo "🛠️  Loading br_netfilter kernel module..."
  sudo modprobe br_netfilter || { echo "❌ Failed to load br_netfilter kernel module. Exiting."; return 1; }
  lsmod | grep br_netfilter
  # make the config persistent
  echo "br_netfilter" | sudo tee /etc/modules-load.d/br_netfilter.conf

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
  # purpose: configure the firewall for a RKE2 server node
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
  # purpose: configure the firewall for a RKE2 agent node
  # Allow kubelet metrics (10250) from all nodes
  sudo ufw allow proto tcp from any to any port 10250 comment "kubelet metrics"

  # Allow NodePort range (30000-32767) between all nodes
  sudo ufw allow proto tcp from any to any port 30000:32767 comment "Kubernetes NodePort range"

  echo "✅ UFW rules configured for RKE2 Agent Node."
}

purge_rke2(){
  # Remove everything related to RKE2
  # TODO: check here what is running
  sudo systemctl stop rke2-server
  sudo systemctl disable rke2-server
  sudo systemctl stop rke2-agent
  sudo systemctl disable rke2-agent
  # remove binary
  sudo rm -rf /usr/local/bin/rke2* /var/lib/rancher/rke2
  # remove systemd unit files
  sudo rm -f /etc/systemd/system/rke2*.service
  sudo rm -f /etc/systemd/system/rke2*.env
  # remove kubernetes data
  sudo rm -rf /etc/rancher /var/lib/kubelet /var/lib/etcd
  # reload systemd and cleanup
  sudo systemctl daemon-reload
  sudo systemctl reset-failed
  # verify : which rke2 | rke2 --version
}