#!/bin/bash
# Zsh uses %x for the defining source file; Bash uses BASH_SOURCE.
# shellcheck disable=SC2296
# Local function collection: use the PDS package or a complete checkout.

# Debian/Ubuntu update policy is maintained beside its platform-specific helpers.
# shellcheck source=../../debian/admin/automatic_updates.sh
if [[ -r "$(dirname -- "${BASH_SOURCE[0]:-${ZSH_VERSION:+${(%):-%x}}}")/../../debian/admin/automatic_updates.sh" ]]; then
    source "$(dirname -- "${BASH_SOURCE[0]:-${ZSH_VERSION:+${(%):-%x}}}")/../../debian/admin/automatic_updates.sh"
fi

# Function: setup_auto_update_weekly_debian
# Description: Configure system to auto-update weekly using /etc/cron.weekly
#              This uses anacron (if installed) to ensure updates run even if
#              the system was off at the scheduled time.
setup_auto_update_weekly_debian() {
    local script_path="/etc/cron.weekly/auto-system-update"

    echo "Configuring weekly system updates..."

    # Create the script
    # We use 'cat' with a heredoc to write the content.
    # DEBIAN_FRONTEND=noninteractive prevents prompts (like config file overwrites)
    cat <<EOF | sudo tee "$script_path" > /dev/null
#!/bin/bash
# Auto-generated system update script

# Ensure non-interactive mode to prevent hangs
export DEBIAN_FRONTEND=noninteractive

# Update package list && Upgrade packages
apt update -y && apt upgrade -y

# Clean up
apt autoremove -y && apt autoclean -y
EOF

    # Make executable
    sudo chmod +x "$script_path"

    echo "✅ Weekly auto-update script created at: $script_path"
}

# Function: setup_auto_update_weekly_fedora
# Description: Configure system to auto-update weekly using /etc/cron.weekly
#              This uses anacron (if installed) to ensure updates run even if
#              the system was off at the scheduled time.
setup_auto_update_weekly_fedora() {
    local script_path="/etc/cron.weekly/auto-system-update"

    echo "Configuring weekly system updates..."

    # Create the script
    # We use 'cat' with a heredoc to write the content.
    # DNF_FRONTEND=noninteractive prevents prompts (like config file overwrites)
    cat <<EOF | sudo tee "$script_path" > /dev/null
#!/bin/bash
# Auto-generated system update script

# Ensure non-interactive mode to prevent hangs
export DNF_FRONTEND=noninteractive

# Update package list && Upgrade packages
dnf update -y && dnf upgrade -y

# Clean up
dnf autoremove -y && dnf clean all
EOF

    # Make executable
    sudo chmod +x "$script_path"

    echo "✅ Weekly auto-update script created at: $script_path"
}


# Function: full_upgrade
# Description: Full system upgrade with one command
full_upgrade() {
    sudo apt update -y && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt autoclean -y # && sudo apt dist-upgrade -y
}

# The validated sudoers implementation lives in common/shell.
# Keep this import local: loading PDS never downloads or installs anything.
if [[ -r "$(dirname -- "${BASH_SOURCE[0]:-${ZSH_VERSION:+${(%):-%x}}}")/../shell/set_sudo_nopasswd.sh" ]]; then
    # shellcheck source=../shell/set_sudo_nopasswd.sh
    source "$(dirname -- "${BASH_SOURCE[0]:-${ZSH_VERSION:+${(%):-%x}}}")/../shell/set_sudo_nopasswd.sh"
fi

set_sudo_nopasswd_current() {
    set_sudo_nopasswd "$(id -un)"
}

# Function: auto_pull_cron_entry
# Description: Auto pull a git repository every minute
# Usage: auto_pull_cron_entry "/path/to/repo"
auto_pull_cron_entry() {
    local repo_path="$1"  # Accepts the repo path as an argument

    if [[ -z "$repo_path" ]]; then
        echo "Error: No repository path provided."
        return 1
    fi

    # Ensure the path is valid
    if [[ ! -d "$repo_path" ]]; then
        echo "Error: Directory '$repo_path' does not exist."
        return 1
    fi

    # Check if the cron job already exists
    sudo grep -q "cd $repo_path && git pull" /etc/crontab || \
    echo "* * * * * $USER cd $repo_path && git pull" | sudo tee -a /etc/crontab > /dev/null
}

# Function: set_fractional_scaling
# Description: Enable fractional scaling for Wayland sessions
set_fractional_scaling() {
    # Check if the system is running Wayland
    if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
        gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer']"
    else
        echo "This script is intended for Wayland sessions only."
    fi
}


# Keep the existing import path while sharing one SSH policy implementation.
# shellcheck source=ssh_security.sh
if [[ -r "$(dirname -- "${BASH_SOURCE[0]:-${ZSH_VERSION:+${(%):-%x}}}")/ssh_security.sh" ]]; then
    source "$(dirname -- "${BASH_SOURCE[0]:-${ZSH_VERSION:+${(%):-%x}}}")/ssh_security.sh"
fi

# Function: system_cleanup
# Description: Safe cross-platform system cleanup supporting multiple package managers
# Usage: system_cleanup [--aggressive]
#        Default mode is safe (preserves recent files, interactive Docker cleanup)
#        --aggressive mode includes Docker system prune -a and removes kernel packages
system_cleanup() {
    local aggressive=false

    # Parse arguments
    if [[ "$1" == "--aggressive" ]]; then
        aggressive=true
        echo "⚠️  Running in AGGRESSIVE mode"
    fi

    # Source the detect_distro functions if not already available
    if ! command -v get_package_manager &>/dev/null; then
        if [[ -f /tmp/detect_distro.sh ]]; then
            source /tmp/detect_distro.sh
        else
            curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/utils/detect_distro.sh -o /tmp/detect_distro.sh
            source /tmp/detect_distro.sh
        fi
    fi

    local pkg_mgr
    pkg_mgr=$(get_package_manager)

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🧹 System Cleanup Utility"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Detected package manager: $pkg_mgr"
    echo ""

    # 1. Docker cleanup (if Docker is installed)
    if command -v docker &>/dev/null; then
        echo "🐳 Cleaning Docker resources..."

        if [[ "$aggressive" == true ]]; then
            # Aggressive: Remove all unused images, not just dangling ones
            echo "  - Removing all unused Docker resources (images, containers, networks, volumes)..."
            if sudo docker system prune -a -f --volumes; then
                echo "  ✓ Docker cleanup completed"
            else
                echo "  ⚠ Docker cleanup failed (this is non-critical)"
            fi
        else
            # Safe: Interactive cleanup, only dangling images
            echo "  - Removing stopped containers, unused networks, dangling images..."
            if sudo docker system prune -f; then
                echo "  ✓ Docker cleanup completed"
            else
                echo "  ⚠ Docker cleanup failed (this is non-critical)"
            fi
        fi
        echo ""
    fi

    # 2. Systemd journal cleanup
    echo "📋 Cleaning systemd journal logs (keeping last 7 days)..."
    if sudo journalctl --vacuum-time=7d 2>/dev/null; then
        echo "  ✓ Journal logs cleaned"
    else
        echo "  ⚠ Journal cleanup skipped (journalctl not available or failed)"
    fi
    echo ""

    # 3. Package manager specific cleanup
    case "$pkg_mgr" in
        dnf)
            echo "📦 Cleaning DNF package cache..."

            # Show current cache size
            if [[ -d /var/cache/dnf ]]; then
                echo "  Current DNF cache size: $(du -sh /var/cache/dnf 2>/dev/null | cut -f1)"
            fi

            # Remove old kernels (only in aggressive mode)
            if [[ "$aggressive" == true ]]; then
                echo "  - Removing old kernel versions (keeping last 2)..."
                if rpm -q kernel-core &>/dev/null; then
                    # Fedora/RHEL 8+
                    sudo dnf remove --oldinstallonly --setopt installonly_limit=2 kernel-core -y 2>/dev/null || true
                elif rpm -q kernel-uek &>/dev/null; then
                    # Oracle Linux
                    sudo dnf remove --oldinstallonly --setopt installonly_limit=2 kernel-uek -y 2>/dev/null || true
                elif rpm -q kernel &>/dev/null; then
                    # Generic kernel package
                    sudo dnf remove --oldinstallonly --setopt installonly_limit=2 kernel -y 2>/dev/null || true
                fi
                echo "  ✓ Old kernels removed"
            fi

            # Clean DNF caches
            echo "  - Cleaning all DNF caches..."
            sudo dnf clean all -y
            echo "  ✓ DNF cache cleaned"

            # Remove unused packages
            echo "  - Removing unused packages..."
            sudo dnf autoremove -y
            echo "  ✓ Unused packages removed"

            # Show final cache size
            if [[ -d /var/cache/dnf ]]; then
                echo "  Final DNF cache size: $(du -sh /var/cache/dnf 2>/dev/null | cut -f1)"
            fi
            ;;

        apt)
            echo "📦 Cleaning APT package cache..."

            # Show current cache size
            if [[ -d /var/cache/apt/archives ]]; then
                echo "  Current APT cache size: $(du -sh /var/cache/apt/archives 2>/dev/null | cut -f1)"
            fi

            # Remove old kernels (only in aggressive mode)
            if [[ "$aggressive" == true ]]; then
                echo "  - Removing old kernel versions (keeping current + 1 previous)..."
                sudo apt autoremove --purge -y 2>/dev/null || true
            else
                # Safe autoremove
                echo "  - Removing unused packages..."
                sudo apt autoremove -y
            fi
            echo "  ✓ Unused packages removed"

            # Clean package cache
            echo "  - Cleaning APT cache..."
            sudo apt autoclean -y
            if [[ "$aggressive" == true ]]; then
                sudo apt clean -y
            fi
            echo "  ✓ APT cache cleaned"

            # Show final cache size
            if [[ -d /var/cache/apt/archives ]]; then
                echo "  Final APT cache size: $(du -sh /var/cache/apt/archives 2>/dev/null | cut -f1)"
            fi
            ;;

        yum)
            echo "📦 Cleaning YUM package cache..."

            # Remove unused packages
            echo "  - Removing unused packages..."
            sudo yum autoremove -y
            echo "  ✓ Unused packages removed"

            # Clean YUM caches
            echo "  - Cleaning all YUM caches..."
            sudo yum clean all -y
            echo "  ✓ YUM cache cleaned"
            ;;

        pacman)
            echo "📦 Cleaning Pacman package cache..."

            # Remove unused packages
            echo "  - Removing orphaned packages..."
            local -a orphaned_packages=()
            mapfile -t orphaned_packages < <(pacman -Qtdq)
            if (( ${#orphaned_packages[@]} )); then
                sudo pacman -Rns "${orphaned_packages[@]}" --noconfirm
            else
                echo "  No orphaned packages found"
            fi

            # Clean package cache
            if [[ "$aggressive" == true ]]; then
                echo "  - Removing all cached packages..."
                sudo pacman -Scc --noconfirm
            else
                echo "  - Removing uninstalled package cache..."
                sudo pacman -Sc --noconfirm
            fi
            echo "  ✓ Pacman cache cleaned"
            ;;

        zypper)
            echo "📦 Cleaning Zypper package cache..."

            # Remove unused packages
            echo "  - Removing unused packages..."
            sudo zypper packages --unneeded | awk -F'|' 'NR>5 {print $3}' | xargs -r sudo zypper remove --clean-deps -y 2>/dev/null || true

            # Clean zypper cache
            echo "  - Cleaning Zypper cache..."
            sudo zypper clean --all
            echo "  ✓ Zypper cache cleaned"
            ;;

        *)
            echo "⚠️  Package manager '$pkg_mgr' not supported for cleanup"
            echo "  Supported: dnf, yum, apt, pacman, zypper"
            ;;
    esac
    echo ""

    # 4. Temporary files cleanup (safe mode)
    echo "🗑️  Cleaning temporary files..."

    # Only clean files older than 7 days to avoid breaking running processes
    echo "  - Cleaning /tmp files older than 7 days..."
    sudo find /tmp -type f -atime +7 -delete 2>/dev/null || echo "  ⚠ /tmp cleanup skipped (permission denied or find failed)"

    echo "  - Cleaning /var/tmp files older than 7 days..."
    sudo find /var/tmp -type f -atime +7 -delete 2>/dev/null || echo "  ⚠ /var/tmp cleanup skipped (permission denied or find failed)"

    # In aggressive mode, also clean empty directories
    if [[ "$aggressive" == true ]]; then
        echo "  - Removing empty directories in /tmp and /var/tmp..."
        sudo find /tmp -type d -empty -delete 2>/dev/null || true
        sudo find /var/tmp -type d -empty -delete 2>/dev/null || true
    fi
    echo "  ✓ Temporary files cleaned"
    echo ""

    # 5. Show disk space summary
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "💾 Disk Space Summary"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    df -h / 2>/dev/null || df -h
    echo ""
    echo "✅ System cleanup completed!"
}
