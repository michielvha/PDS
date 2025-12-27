#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/ui/setup_gnome_extras.sh) `

# Function: setup_gnome_extras
# Description: Installs GNOME Tweaks and useful shell extensions
setup_gnome_extras() {
	echo "🔧 Installing GNOME Tweaks and useful shell extensions..."

	# Base tools
	sudo apt update
	sudo apt install -y gnome-tweaks gnome-shell-extensions gnome-shell-extension-prefs curl jq

	# Enable User Themes extension (required for custom Shell themes in Tweaks)
	echo "🎨 Enabling User Themes extension..."
	gnome-extensions enable user-theme@gnome-shell-extensions.gcampax.github.com 2>/dev/null || \
	gnome-extensions enable user-theme 2>/dev/null || \
	echo "⚠️  Could not enable User Themes extension (may need to be enabled manually)"

	declare -A extensions=(
		["dash-to-dock@micxgx.gmail.com"]=307
		["blur-my-shell@aunetx"]=3193
		["appindicatorsupport@rgcjonas.gmail.com"]=615
		["clipboard-history@alexsaveau.dev"]=4839
		["just-perfection-desktop@just-perfection"]=3843
		["top-bar-organizer@julian.gse.jsts.xyz"]=4356
	)

	GNOME_VERSION=$(gnome-shell --version | awk '{print $3}' | cut -d '.' -f1)

	tmp_dir=$(mktemp -d)
	cd "$tmp_dir" || exit 1

	for uuid in "${!extensions[@]}"; do
		ext_id=${extensions[$uuid]}
		echo "⬇️  Installing $uuid (ID: $ext_id)"

		ext_info=$(wget -qO- "https://extensions.gnome.org/extension-info/?pk=$ext_id")
		version_tag=$(echo "$ext_info" | jq -r --arg ver "$GNOME_VERSION" '.shell_version_map[$ver].pk')

		if [[ -z "$version_tag" || "$version_tag" == "null" ]]; then
			echo "⚠️  No compatible version found for GNOME Shell $GNOME_VERSION and $uuid"
			continue
		fi

		zip_file="${uuid}.zip"
		wget -q --show-progress -O "$zip_file" "https://extensions.gnome.org/download-extension/${uuid}.shell-extension.zip?version_tag=$version_tag"

		if [[ $? -ne 0 || ! -s "$zip_file" ]]; then
			echo "❌ Failed to download $uuid"
			continue
		fi

		install_dir="$HOME/.local/share/gnome-shell/extensions/$uuid"
		rm -rf "$install_dir"
		mkdir -p "$install_dir"
		unzip -qqo "$zip_file" -d "$install_dir"

		gnome-extensions enable "$uuid" && echo "✅ Installed and enabled $uuid"
	done

	rm -rf "$tmp_dir"
	echo "🎉 All extensions installed. Restart GNOME Shell (Alt+F2 → r or logout) to apply them."

	# verify
	# gsettings get org.gnome.shell enabled-extensions
}
