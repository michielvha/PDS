#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/security/install_cert.sh) `

# Function: install_cert
# Description: Installs a PEM certificate into the system trust store so all tools (curl, git, apt, etc.) trust it.
# Usage: install_cert <path-to-cert.pem> [cert-name]
install_cert() {
  local cert_path="$1"
  local cert_name="${2:-custom-ca}"

  # Validate input
  [[ -z "$cert_path" ]] && { echo "Usage: install_cert <path-to-cert.pem> [cert-name]"; return 1; }
  [[ ! -f "$cert_path" ]] && { echo "❌ Certificate file not found: $cert_path"; return 1; }

  # Source distro detection
  source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/utils/detect_distro.sh)
  local distro
  distro=$(detect_distro)


  echo "🔐 Installing certificate '$cert_name' from: $cert_path"

  if [[ "$distro" == "debian" ]]; then
    sudo cp "$cert_path" "/usr/local/share/ca-certificates/${cert_name}.crt"
    sudo update-ca-certificates && echo "✅ Certificate installed (Debian/Ubuntu)."

  elif [[ "$distro" == "rhel" ]]; then
    sudo cp "$cert_path" "/etc/pki/ca-trust/source/anchors/${cert_name}.pem"
    sudo update-ca-trust extract && echo "✅ Certificate installed (RHEL/CentOS/Fedora)."

  else
    echo "❌ Unsupported distribution: $distro"
    return 1
  fi
}
