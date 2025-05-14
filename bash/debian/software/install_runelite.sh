#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/software/install_runelite.sh) `

# Description: Installs runelite on Debian-based systems
# Function: install_runelite
install_runelite() {
    # Check if runelite is already installed
    [ -f "/usr/local/bin/RuneLite.jar" ] && { echo "Runelite is already installed."; return; }

    install_jre

    sudo wget -O /usr/local/bin/RuneLite.jar https://github.com/runelite/launcher/releases/download/2.7.4/RuneLite.jar
    sudo chmod 755 /usr/local/bin/RuneLite.jar

    create_alias
    create_application
    
    # Create a simple launcher script for quick access
    create_launcher_script
    
    echo "RuneLite installation complete!"
    echo "You can run RuneLite in the following ways:"
    echo "1. Using the desktop shortcut"
    echo "2. Using the 'runelite' command in terminal"
    echo "3. Using the '~/run_runelite.sh' script"
}

# Description: Installs Java Runtime Environment (JRE) on Debian-based systems
# Function: install_jre
install_jre(){
    sudo apt update
    sudo apt install default-jre -y

    # if you already have java installed, you can choose which one with the following command
    # sudo update-alternatives --config java
}

# Description: Creates an alias for launching RuneLite with 4k monitor support
# Function: create_alias
create_alias() {
    # Check if the alias already exists
    grep -q "alias runelite" ~/.bashrc || echo 'alias runelite="java -Dsun.java2d.uiScale=2.0 -Dswing.aatext=true -Dawt.useSystemAAFontSettings=on -Drunelite.scale=2 -Xmx4g -XX:+UseG1GC -jar /usr/local/bin/RuneLite.jar --scale=2"' | sudo tee --append /etc/bash.bashrc && echo "Alias added to /etc/bash.bashrc"
}

# Description: Creates a simple launcher script for RuneLite enabling 4K monitor with 2x zoom
# Function: create_application
create_application() {
    echo "Fetching RuneLite icon and creating desktop entry..."
    sudo wget -O /usr/local/share/RuneLite.png https://oldschool.runescape.wiki/images/RuneLite_icon.png?ef286 || { echo "Failed to fetch RuneLite icon"; return 1;}

    cat <<EOF | sudo tee /usr/share/applications/runelite.desktop
[Desktop Entry]
Encoding=UTF-8
Type=Application
Exec=java -Dsun.java2d.uiScale=2.0 -Dswing.aatext=true -Dawt.useSystemAAFontSettings=on -Drunelite.scale=2 -Xmx4g -XX:+UseG1GC -jar /usr/local/bin/RuneLite.jar --scale=2
Name=RuneLite
Comment=RuneLite launcher
Icon=/usr/local/share/RuneLite.png
Categories=Game
EOF
}