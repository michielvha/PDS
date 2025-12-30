#!/bin/bash
# Common cloud-related functions for Cloudflare
# This module contains functions for managing Cloudflare Tunnel configurations
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/cloud/cloudflare.sh) `
#
# ============================================================================
# CLOUDFLARE TUNNEL SETUP GUIDE
# ============================================================================
#
# Complete workflow to set up a Cloudflare Tunnel:
#
# STEP 1: Install cloudflared
#   source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/software/install_cloudflared.sh)
#   install_cloudflared
#
# STEP 2: Authenticate with Cloudflare
#   cloudflared tunnel login
#   (This opens a browser to authenticate with your Cloudflare account)
#
# STEP 3: Create a tunnel
#   cloudflared tunnel create <tunnel-name>
#   Example: cloudflared tunnel create api-tunnel
#   (This creates a credentials file at ~/.cloudflared/<tunnel-id>.json)
#
# STEP 4: List your tunnels (optional)
#   cloudflared tunnel list
#   (Note the tunnel ID and name for reference)
#
# STEP 5: Create a DNS record (optional, can be done via Cloudflare dashboard)
#   cloudflared tunnel route dns <tunnel-name> <hostname>
#   Example: cloudflared tunnel route dns api-tunnel api.yourdomain.com
#   Or create it manually in Cloudflare dashboard:
#   - Go to DNS > Records
#   - Add CNAME record: api -> <tunnel-id>.cfargotunnel.com
#
# STEP 6: Create your config file
#   Create a YAML file (e.g., cloudflare-tunnel-config.yml) with:
#   ---
#   tunnel: <tunnel-name>
#   credentials-file: /root/.cloudflared/<tunnel-id>.json
#   ingress:
#     - hostname: api.yourdomain.com
#       service: http://localhost:8080
#     - service: http_status:404
#   ---
#
# STEP 7: Deploy the config
#   source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/cloud/cloudflare.sh)
#   deploy_cloudflare_tunnel_config ./cloudflare-tunnel-config.yml api-tunnel --enable-service
#
#   Options:
#     --system          : Deploy to /etc/cloudflared/ (system-wide) instead of ~/.cloudflared/
#     --enable-service  : Create and enable a systemd service for automatic startup
#
# STEP 8: Start the tunnel (if not using --enable-service)
#   cloudflared tunnel run <tunnel-name>
#
# Or if using systemd service:
#   sudo systemctl start cloudflared@<tunnel-name>.service
#   sudo systemctl status cloudflared@<tunnel-name>.service
#
# ============================================================================
# MANUAL SETUP (Alternative to using deploy function)
# ============================================================================
#
# 1. Copy config file manually:
#    mkdir -p ~/.cloudflared
#    cp cloudflare-tunnel-config.yml ~/.cloudflared/config.yml
#
# 2. Copy credentials file (if needed):
#    cp ~/.cloudflared/<tunnel-id>.json ~/.cloudflared/
#
# 3. Update credentials-file path in config.yml to match actual location
#
# 4. Test the config:
#    cloudflared tunnel --config ~/.cloudflared/config.yml ingress validate
#
# 5. Run the tunnel:
#    cloudflared tunnel run <tunnel-name>
#
# 6. For systemd service (manual):
#    sudo mkdir -p /etc/cloudflared
#    sudo cp config.yml /etc/cloudflared/config.yml
#    sudo cp <tunnel-id>.json /etc/cloudflared/
#    # Create service file at /etc/systemd/system/cloudflared@<tunnel-name>.service
#    sudo systemctl daemon-reload
#    sudo systemctl enable cloudflared@<tunnel-name>.service
#    sudo systemctl start cloudflared@<tunnel-name>.service
#
# ============================================================================
# TROUBLESHOOTING
# ============================================================================
#
# - Check tunnel status: cloudflared tunnel info <tunnel-name>
# - View logs: sudo journalctl -u cloudflared@<tunnel-name>.service -f
# - Test config: cloudflared tunnel --config <config-path> ingress validate
# - List tunnels: cloudflared tunnel list
# - Delete tunnel: cloudflared tunnel delete <tunnel-name>
#
# ============================================================================

# Function: deploy_cloudflare_tunnel_config
# Description: Deploys a persisted Cloudflare tunnel configuration file to the system
# Usage: deploy_cloudflare_tunnel_config [config_file] [tunnel_name] [--system] [--enable-service]
# Arguments:
#   config_file: Path to the tunnel config file (default: searches for config.yml in current directory)
#   tunnel_name: Name of the tunnel (required if --enable-service is used)
#   --system: Deploy to system-wide location (/etc/cloudflared/) instead of user location (~/.cloudflared/)
#   --enable-service: Create and enable a systemd service for the tunnel (Linux only)
# Example:
#   deploy_cloudflare_tunnel_config ./my-tunnel-config.yml my-tunnel --enable-service
#   deploy_cloudflare_tunnel_config ./config.yml --system
deploy_cloudflare_tunnel_config() {
    local config_file=""
    local tunnel_name=""
    local system_wide=false
    local enable_service=false
    local config_dir=""
    local config_path=""
    local os_type=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --system)
                system_wide=true
                shift
                ;;
            --enable-service)
                enable_service=true
                shift
                ;;
            -*)
                echo "❌ Unknown option: $1"
                echo "Usage: deploy_cloudflare_tunnel_config [config_file] [tunnel_name] [--system] [--enable-service]"
                return 1
                ;;
            *)
                if [[ -z "$config_file" ]]; then
                    config_file="$1"
                elif [[ -z "$tunnel_name" ]]; then
                    tunnel_name="$1"
                else
                    echo "❌ Too many arguments"
                    echo "Usage: deploy_cloudflare_tunnel_config [config_file] [tunnel_name] [--system] [--enable-service]"
                    return 1
                fi
                shift
                ;;
        esac
    done

    # Detect OS type
    case "$(uname -s)" in
        Linux*)
            os_type="linux"
            ;;
        Darwin*)
            os_type="darwin"
            ;;
        *)
            os_type="unknown"
            ;;
    esac

    # Check if cloudflared is installed
    if ! command -v cloudflared &> /dev/null; then
        echo "❌ cloudflared is not installed"
        echo "💡 Install it first: source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/software/install_cloudflared.sh) && install_cloudflared"
        return 1
    fi

    # Determine config file location
    if [[ -z "$config_file" ]]; then
        # Try to find config.yml in current directory
        if [[ -f "./config.yml" ]]; then
            config_file="./config.yml"
        elif [[ -f "./cloudflared-config.yml" ]]; then
            config_file="./cloudflared-config.yml"
        else
            echo "❌ No config file specified and no config.yml found in current directory"
            echo "Usage: deploy_cloudflare_tunnel_config [config_file] [tunnel_name] [--system] [--enable-service]"
            return 1
        fi
    fi

    # Validate config file exists
    if [[ ! -f "$config_file" ]]; then
        echo "❌ Config file not found: $config_file"
        return 1
    fi

    # Validate config file is readable
    if [[ ! -r "$config_file" ]]; then
        echo "❌ Config file is not readable: $config_file"
        return 1
    fi

    # Determine deployment location
    if [[ "$system_wide" == true ]]; then
        config_dir="/etc/cloudflared"
        config_path="$config_dir/config.yml"
    else
        config_dir="$HOME/.cloudflared"
        config_path="$config_dir/config.yml"
    fi

    echo "=== Deploying Cloudflare Tunnel Configuration ==="
    echo "Config file: $config_file"
    echo "Target location: $config_path"
    echo ""

    # Create config directory
    if [[ "$system_wide" == true ]]; then
        if [[ ! -d "$config_dir" ]]; then
            echo "📁 Creating system config directory: $config_dir"
            sudo mkdir -p "$config_dir"
        fi
    else
        if [[ ! -d "$config_dir" ]]; then
            echo "📁 Creating user config directory: $config_dir"
            mkdir -p "$config_dir"
        fi
    fi

    # Backup existing config if it exists
    if [[ -f "$config_path" ]]; then
        local backup_path="${config_path}.backup.$(date +%Y%m%d_%H%M%S)"
        echo "💾 Backing up existing config to: $backup_path"
        if [[ "$system_wide" == true ]]; then
            sudo cp "$config_path" "$backup_path"
        else
            cp "$config_path" "$backup_path"
        fi
    fi

    # Deploy config file
    echo "📋 Deploying configuration..."
    if [[ "$system_wide" == true ]]; then
        sudo cp "$config_file" "$config_path"
        sudo chmod 644 "$config_path"
        sudo chown root:root "$config_path"
    else
        cp "$config_file" "$config_path"
        chmod 600 "$config_path"
    fi

    echo "✅ Configuration deployed successfully to: $config_path"
    echo ""

    # Handle tunnel credential files if they exist in the source directory
    local source_dir
    if command -v realpath &> /dev/null; then
        source_dir=$(dirname "$(realpath "$config_file")")
    else
        # Fallback for systems without realpath
        if [[ "$config_file" = /* ]]; then
            source_dir=$(dirname "$config_file")
        else
            source_dir=$(dirname "$(pwd)/$config_file")
        fi
    fi
    local cred_files
    cred_files=$(find "$source_dir" -maxdepth 1 -name "*.json" -type f 2>/dev/null)

    if [[ -n "$cred_files" ]]; then
        echo "🔑 Found tunnel credential files, deploying..."
        local main_cred_file=""
        while IFS= read -r cred_file; do
            local cred_filename
            cred_filename=$(basename "$cred_file")
            local target_cred="$config_dir/$cred_filename"
            
            if [[ "$system_wide" == true ]]; then
                sudo cp "$cred_file" "$target_cred"
                sudo chmod 600 "$target_cred"
                sudo chown root:root "$target_cred"
            else
                cp "$cred_file" "$target_cred"
                chmod 600 "$target_cred"
            fi
            
            # Store the first credential file to update config path
            if [[ -z "$main_cred_file" ]]; then
                main_cred_file="$target_cred"
            fi
            
            echo "  ✅ Deployed: $cred_filename"
        done <<< "$cred_files"
        
        # Update credentials-file path in the deployed config
        if [[ -n "$main_cred_file" ]]; then
            echo "🔧 Updating credentials-file path in config..."
            if [[ "$system_wide" == true ]]; then
                sudo sed -i "s|credentials-file:.*|credentials-file: $main_cred_file|" "$config_path"
            else
                sed -i "s|credentials-file:.*|credentials-file: $main_cred_file|" "$config_path"
            fi
            echo "  ✅ Updated credentials-file path to: $main_cred_file"
        fi
        echo ""
    fi

    # Validate config file syntax
    echo "🔍 Validating configuration..."
    if cloudflared tunnel --config "$config_path" ingress validate &>/dev/null; then
        echo "✅ Configuration is valid"
    else
        echo "⚠️  Configuration validation failed or cloudflared validation not available"
        echo "💡 You can test manually with: cloudflared tunnel --config $config_path ingress validate"
    fi
    echo ""

    # Create systemd service if requested (Linux only)
    if [[ "$enable_service" == true ]]; then
        if [[ "$os_type" != "linux" ]]; then
            echo "⚠️  Systemd service creation is only supported on Linux"
            echo "💡 On macOS, use launchd or run manually: cloudflared tunnel run $tunnel_name"
            return 0
        fi

        if [[ -z "$tunnel_name" ]]; then
            echo "❌ Tunnel name is required when using --enable-service"
            echo "Usage: deploy_cloudflare_tunnel_config [config_file] [tunnel_name] [--system] [--enable-service]"
            return 1
        fi

        # Check if systemd is available
        if ! command -v systemctl &> /dev/null; then
            echo "⚠️  systemctl not found, cannot create systemd service"
            return 0
        fi

        echo "🔧 Creating systemd service for tunnel: $tunnel_name"
        
        local service_name="cloudflared@${tunnel_name}.service"
        local service_file
        local systemctl_cmd
        local start_cmd
        local status_cmd
        local logs_cmd
        
        # Determine config path for service
        local service_config_path="$config_path"
        
        # Find cloudflared binary path
        local cloudflared_path
        cloudflared_path=$(command -v cloudflared)
        if [[ -z "$cloudflared_path" ]]; then
            echo "❌ Could not find cloudflared binary in PATH"
            return 1
        fi

        if [[ "$system_wide" == true ]]; then
            # System-wide service
            service_file="/etc/systemd/system/$service_name"
            systemctl_cmd="sudo systemctl"
            start_cmd="sudo systemctl start $service_name"
            status_cmd="sudo systemctl status $service_name"
            logs_cmd="sudo journalctl -u $service_name -f"
            
            # Create systemd service file
            sudo tee "$service_file" > /dev/null <<EOF
[Unit]
Description=Cloudflare Tunnel for ${tunnel_name}
After=network.target

[Service]
Type=simple
User=root
ExecStart=${cloudflared_path} tunnel --config ${service_config_path} run ${tunnel_name}
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
            
            # Reload systemd
            sudo systemctl daemon-reload
            
            # Enable service
            echo "🔌 Enabling service: $service_name"
            sudo systemctl enable "$service_name"
        else
            # User service
            local user_service_dir="$HOME/.config/systemd/user"
            mkdir -p "$user_service_dir"
            service_file="$user_service_dir/$service_name"
            systemctl_cmd="systemctl --user"
            start_cmd="systemctl --user start $service_name"
            status_cmd="systemctl --user status $service_name"
            logs_cmd="journalctl --user -u $service_name -f"
            
            # Create user systemd service file
            tee "$service_file" > /dev/null <<EOF
[Unit]
Description=Cloudflare Tunnel for ${tunnel_name}
After=network.target

[Service]
Type=simple
ExecStart=${cloudflared_path} tunnel --config ${service_config_path} run ${tunnel_name}
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=default.target
EOF
            
            # Reload user systemd
            systemctl --user daemon-reload
            
            # Enable service
            echo "🔌 Enabling user service: $service_name"
            systemctl --user enable "$service_name"
            
            # Enable lingering for user services to run at boot
            sudo loginctl enable-linger "$USER" 2>/dev/null || true
        fi
        
        echo "✅ Systemd service created and enabled"
        echo ""
        echo "💡 To start the service: $start_cmd"
        echo "💡 To check status: $status_cmd"
        echo "💡 To view logs: $logs_cmd"
    fi

    echo ""
    echo "✅ Cloudflare tunnel configuration deployment complete!"
    echo ""
    echo "📝 Next steps:"
    if [[ "$enable_service" != true ]]; then
        if [[ -n "$tunnel_name" ]]; then
            echo "   • Run tunnel: cloudflared tunnel run $tunnel_name"
        else
            echo "   • Run tunnel: cloudflared tunnel run <tunnel-name>"
        fi
    fi
    echo "   • View config: cat $config_path"
    echo "   • Test config: cloudflared tunnel --config $config_path ingress validate"
}

# examples
# deploy_cloudflare_tunnel_config ./config.yml my-tunnel --enable-service
# deploy_cloudflare_tunnel_config ./config.yml my-tunnel --system
# deploy_cloudflare_tunnel_config ./config.yml my-tunnel --enable-service --system
# deploy_cloudflare_tunnel_config ./config.yml my-tunnel --enable-service --system --config-file ./config.yml
# deploy_cloudflare_tunnel_config ./config.yml my-tunnel --enable-service --system --config-file ./config.yml