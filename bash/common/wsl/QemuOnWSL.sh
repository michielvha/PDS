#!/bin/bash

# Function: install_qemu_on_wsl
# Description: Installs QEMU and Virt-Manager on WSL2 with Debian or Ubuntu
# Note: Must be run as root/sudo
install_qemu_on_wsl() {
    echo "Installing QEMU and Virt-Manager on WSL2..."
    
    # Update package list
    sudo apt-get update
    
    # Install QEMU and related packages
    sudo apt install -y qemu qemu-kvm libvirt-clients libvirt-daemon-system bridge-utils virt-manager
    sudo apt install -y x11-apps
    
    echo "✅ QEMU packages installed successfully"
    echo "⚠️  Next steps:"
    echo "   1. Enable systemd in WSL by running: configure_wsl_systemd"
    echo "   2. Restart WSL instance"
    echo "   3. Enable services by running: enable_libvirt_services"
}

# Function: configure_wsl_systemd
# Description: Configure WSL to use systemd on boot
configure_wsl_systemd() {
    echo "Configuring WSL to use systemd..."
    
    sudo bash -c 'cat > /etc/wsl.conf << EOF
[boot]
systemd=true
EOF'
    
    echo "✅ WSL systemd configuration complete"
    echo "⚠️  Please restart your WSL instance with: wsl --shutdown"
}

# Function: enable_libvirt_services
# Description: Enable libvirt services (run after WSL restart)
enable_libvirt_services() {
    echo "Enabling libvirt services..."
    
    sudo systemctl enable --now libvirtd
    sudo systemctl enable --now virtlogd
    
    echo "✅ Libvirt services enabled"
    echo "💡 You can now run 'virt-manager' to start the virtual machine manager"
}

# Function: create_debian_vm
# Description: Create a Debian test VM using virt-install
# Usage: create_debian_vm [iso_path]
create_debian_vm() {
    local iso_path="${1:-/var/lib/iso/debian-11.5.0-amd64-netinst.iso}"
    
    echo "Creating Debian VM..."
    
    # Check if ISO exists
    if [[ ! -f "$iso_path" ]]; then
        echo "❌ ISO file not found: $iso_path"
        echo "Please download the Debian ISO and provide the correct path"
        return 1
    fi
    
    # Create VM
    sudo virt-install \
        --name=debian-vm \
        --os-type=Linux \
        --os-variant=debian10 \
        --vcpu=2 \
        --ram=2048 \
        --disk path=/var/lib/libvirt/images/Debian.img,size=15 \
        --graphics spice \
        --cdrom="$iso_path"
    
    echo "✅ Debian VM creation initiated"
# # TODO: Rework this old snippet to current standards.
# # This script installs QEMU and Virt-Manager on WSL2 with Debian or Ubuntu.
# #!/bin/bash
# # RUN AS ROOT
# apt-get update

# sudo apt install qemu qemu-kvm libvirt-clients libvirt-daemon-system bridge-utils virt-manager
# apt install x11-apps

# #make debian use systemd on boot
# sudo echo '[boot]
# systemd=true' > /etc/wsl.conf

# wsl --shutdown -d "your distribution name"

# #####################################
# #   --- restart the instance ---   #
# #####################################

# sudo systemctl enable --now libvirtd
# sudo systemctl enable --now virtlogd

# virt-manager

# #make debian test vm
#  sudo virt-install --name=debian-vm \
#  --os-type=Linux \
#  --os-variant=debian10 \
#  --vcpu=2 \
#  --ram=2048 \
#  --disk path=/var/lib/libvirt/images/Debian.img,size=15 \
#  --graphics spice \
#  --cdrom=/var/lib/iso/debian-11.5.0-amd64-netinst.iso
