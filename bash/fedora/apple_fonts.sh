git clone https://github.com/sahibjotsaggu/San-Francisco-Pro-Fonts.git
cd San-Francisco-Pro-Fonts
mkdir -p ~/.local/share/fonts/sf-pro
cp *.otf ~/.local/share/fonts/sf-pro/
fc-cache -fv

# TODO: add progammatic set of fonts