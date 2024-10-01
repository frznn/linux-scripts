#!/bin/bash

# Function to display APT packages
show_apt_packages() {
    echo "===== APT Manually Installed Packages ====="
    if command -v apt-mark &> /dev/null; then
        apt-mark showmanual
        echo ""
        echo "To remove an APT package and purge its data, use:"
        echo "  sudo apt remove --purge <package-name>"
        echo "  sudo apt autoremove"
    else
        echo "APT is not installed or available on this system."
    fi
    echo ""
}

# Function to display Snap packages
show_snap_packages() {
    echo "===== Snap Installed Packages ====="
    if command -v snap &> /dev/null; then
        snap list
        echo ""
        echo "To remove a Snap package and purge its data, use:"
        echo "  sudo snap remove --purge <package-name>"
    else
        echo "Snap is not installed or available on this system."
    fi
    echo ""
}

# Function to display npm packages
show_npm_packages() {
    echo "===== npm Global Packages ====="
    if command -v npm &> /dev/null; then
        npm list -g --depth=0
        echo ""
        echo "To remove a global npm package, use:"
        echo "  sudo npm uninstall -g <package-name>"
    else
        echo "npm is not installed or available on this system."
    fi
    echo ""
}

# Function to display pip packages
show_pip_packages() {
    echo "===== pip Global Packages ====="
    if command -v pip3 &> /dev/null; then
        pip3 list
        echo ""
        echo "To remove a global pip package, use:"
        echo "  sudo pip3 uninstall <package-name>"
    else
        echo "pip is not installed or available on this system."
    fi
    echo ""
}

# Function to search for AppImage files in common directories
show_appimage_packages() {
    echo "===== AppImage Files ====="
    common_dirs=("$HOME/Applications" "$HOME/Downloads" "$HOME/Desktop" "/opt" "/usr/local/bin")

    found=false
    for dir in "${common_dirs[@]}"; do
        if [ -d "$dir" ]; then
            find "$dir" -name "*.AppImage" 2>/dev/null | while read -r appimage; do
                echo "$appimage"
                found=true
            done
        fi
    done

    if ! $found; then
        echo "No AppImage files found in common directories."
    fi

    echo ""
    echo "To remove an AppImage, simply delete the file:"
    echo "  rm <path-to-appimage>"
    echo ""
}

# Check if an argument is passed
if [[ -n $1 ]]; then
    case "$1" in
        apt)
            show_apt_packages
            ;;
        snap)
            show_snap_packages
            ;;
        npm)
            show_npm_packages
            ;;
        pip)
            show_pip_packages
            ;;
        appimage)
            show_appimage_packages
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Usage: $0 [apt|snap|npm|pip|appimage]"
            ;;
    esac
else
    # If no argument is passed, show all
    show_apt_packages
    show_snap_packages
    show_npm_packages
    show_pip_packages
    show_appimage_packages
fi

