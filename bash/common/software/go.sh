#!/bin/bash
# Function: install_go
# Description: Installs the latest version of Golang and configures the environment for the current user.
# Usage: install_go
# Arguments: none
# Returns:
#   0 - Success
#   1 - Failure (e.g., unable to fetch the latest version, download issues, or installation errors)

# Function: set_go_env
# Description: Configures the Go environment variables for the current user.
# Usage: set_go_env
# Arguments: none
# Returns:
#   0 - Success

# TODO: allow to manually specify which version ?
install_go () {
  echo "🚀 Fetching the latest Go version..."

  # Get the latest Go version dynamically from the official site + Extract just the version number (e.g., go1.21.5 -> 1.21.5)
  GO_VERSION=$(curl -s https://go.dev/VERSION?m=text | head -n 1 | awk '{print $1}' | sed 's/go//')

  # Validate version extraction
  if [[ -z "$GO_VERSION" ]]; then
    echo "❌ Failed to retrieve the latest Go version."
    exit 1
  fi

  # Define download URL and filename
  GO_TARBALL="go${GO_VERSION}.linux-amd64.tar.gz"
  DOWNLOAD_URL="https://go.dev/dl/${GO_TARBALL}"

  echo "📥 Downloading Go ${GO_VERSION} from ${DOWNLOAD_URL}..."
  curl -LO "${DOWNLOAD_URL}"

  echo "📦 Extracting Go ${GO_VERSION}..."
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf "${GO_TARBALL}"
  rm "${GO_TARBALL}"  # Remove tarball after installation

  echo "✅ Go ${GO_VERSION} installed successfully!"

  # Set up GOPATH and GOBIN
  echo "🔧 Configuring Go environment variables..."

  echo 'export GOPATH=$HOME/go' >> ~/.bashrc
  echo 'export GOBIN=$GOPATH/bin' >> ~/.bashrc
  echo 'export PATH=$GOBIN:/usr/local/go/bin:$PATH' >> ~/.bashrc
  source ~/.bashrc  # Apply changes

  echo "🚀 Go installed! Run 'go version' to check."
}

set_go_env () {
  echo "🔧 Setting Go environment variables for user: $USER"

  {
    echo ''
    echo '# Go environment setup'
    echo 'export GOPATH=$HOME/go'
    echo 'export GOBIN=$GOPATH/bin'
    echo 'export PATH=$GOBIN:/usr/local/go/bin:$PATH'
  } >> ~/.bashrc

  # Apply it immediately
  export GOPATH=$HOME/go
  export GOBIN=$GOPATH/bin
  export PATH=$GOBIN:/usr/local/go/bin:$PATH

  mkdir -p "$GOBIN"

  echo "✅ Go environment set up. Run 'go version' to check."
}