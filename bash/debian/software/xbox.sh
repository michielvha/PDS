#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/software/xbox.sh) `

# Function: install_xbox_controller
# Description: Installs the Xbox controller driver on Debian-based systems
# Reference: https://github.com/dlundqvist/xone
install_xbox_controller() {
    echo "📦 installing xbox controller support"
    git clone https://github.com/dlundqvist/xone
    cd xone
    sudo ./install.sh
    cd install
    chmod +x firmware.sh
    sudo ./firmware.sh

    sudo depmod -a
    sudo modprobe xone-gip
    sudo modprobe xone-dongle
    lsmod | grep xone
    echo "✅ Xbox controller support installed successfully."
}

# Function: troubleshoot_xbox_controller
# Description: Troubleshoots Xbox controller wireless connectivity issues
troubleshoot_xbox_controller() {
    echo "🔍 Troubleshooting Xbox wireless connectivity issues..."
    
    # Check if modules are loaded
    echo "📊 Checking if Xbox modules are loaded:"
    lsmod | grep xone
    
    # Check kernel logs for Xbox related messages
    echo "📋 Checking kernel logs for Xbox controller messages:"
    journalctl -k | grep -i "xbox\|xone\|controller" | tail -n 50
    
    # Check USB device connections
    echo "🔌 Checking USB devices:"
    lsusb | grep -i "xbox\|microsoft"
    
    # Check Bluetooth devices if using Bluetooth
    echo "📶 Checking Bluetooth devices:"
    bluetoothctl devices
    
    # Check hardware status
    echo "💻 Checking hardware status:"
    dmesg | grep -i "xbox\|xone\|controller\|bluetooth\|wireless" | tail -n 50
    
    # Reload modules
    echo "🔄 Reloading Xbox modules (may help resolve issues):"
    sudo modprobe -r xone-gip xone-dongle
    sudo modprobe xone-gip
    sudo modprobe xone-dongle
    
    echo "✅ Troubleshooting complete. Check the output above for potential issues."
    echo "📝 Tip: If your controller is still not connecting, try restarting the bluetooth service with: sudo systemctl restart bluetooth"
}

# Function: pair_xbox_controller
# Description: Helps pair an Xbox wireless controller with the wireless adapter
pair_xbox_controller() {
    echo "🎮 Starting Xbox controller pairing process..."
    
    # Check if dongle is connected
    if ! lsusb | grep -i "xbox acc" > /dev/null; then
        echo "❌ Xbox wireless adapter not detected. Please connect it first."
        return 1
    fi
    
    # Check if modules are loaded
    if ! lsmod | grep xone_dongle > /dev/null; then
        echo "⚠️ Xbox modules not loaded. Loading them now..."
        sudo modprobe xone-gip
        sudo modprobe xone-dongle
    fi
    
    # Enable pairing mode on the adapter
    echo "📲 Enabling pairing mode on the Xbox wireless adapter..."
    echo "1" | sudo tee /sys/bus/usb/drivers/xone-dongle/*/pairing > /dev/null
    
    echo "🔄 Adapter is now in pairing mode for 20 seconds."
    echo "🎮 Press and hold the Xbox button on your controller until it starts flashing rapidly."
    echo "⏳ Waiting for pairing process..."
    
    # Wait for 20 seconds while pairing happens
    for i in {20..1}; do
        echo -ne "⏱️ $i seconds remaining...\\r"
        sleep 1
    done
    
    # Turn off pairing mode
    echo "0" | sudo tee /sys/bus/usb/drivers/xone-dongle/*/pairing > /dev/null
    
    echo -e "\n✅ Pairing attempt complete. Checking for connected controllers..."
    
    # Check if any controllers are connected
    sudo dmesg | grep -i "xbox controller\|xone\|gip" | tail -n 10
    
    echo "📝 If your controller is flashing but did not connect:"
    echo "  1. Make sure it has fresh batteries"
    echo "  2. Try running the pairing process again (run 'pair_xbox_controller' again)"
    echo "  3. Try power cycling the controller (remove and reinsert batteries)"
    echo "  4. Make sure your controller is within range of the adapter"
}

# Function: fix_xbox_pairing
# Description: Advanced troubleshooting for persistent Xbox wireless pairing issues
fix_xbox_pairing() {
    echo "🔧 Advanced Xbox controller pairing troubleshooting..."
    
    # Reset the USB port
    echo "🔌 Resetting USB port for Xbox wireless adapter..."
    
    # Find the Xbox adapter bus and device numbers
    XBOX_USB=$(lsusb | grep -i "xbox acc")
    if [ -z "$XBOX_USB" ]; then
        echo "❌ Xbox wireless adapter not found. Please connect it first."
        return 1
    fi
    
    BUS=$(echo $XBOX_USB | awk '{print $2}')
    DEVICE=$(echo $XBOX_USB | awk '{print $4}' | sed 's/://')
    
    echo "📋 Found Xbox adapter on Bus $BUS Device $DEVICE"
    
    # Reset the USB device
    echo "🔄 Resetting USB device..."
    sudo sh -c "echo 0 > /sys/bus/usb/devices/$BUS-$DEVICE/authorized"
    sleep 2
    sudo sh -c "echo 1 > /sys/bus/usb/devices/$BUS-$DEVICE/authorized"
    
    # Reload modules
    echo "🔄 Reloading kernel modules..."
    sudo modprobe -r xone-dongle xone-gip
    sleep 2
    sudo modprobe xone-gip
    sudo modprobe xone-dongle
    
    # Clear kernel ring buffer
    sudo dmesg -C
    
    echo "🎮 Please now try pairing your controller again using the pair_xbox_controller function."
    echo "📝 If issues persist, you can try connecting the controller via USB cable temporarily"
    echo "   to see if it needs a firmware update."
}