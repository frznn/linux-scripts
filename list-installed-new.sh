#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# list-installed-new.sh
#
# Lists user-installed software across APT, Snap, AppImage, npm, and pip.
# Filters out system/infrastructure packages from the APT list and adds
# a short description for each entry.
#
# USAGE
#   list-installed [apt|snap|appimage|npm|pip]
#   With no argument, all sections are shown.
#
# INSTALL AS COMMAND
#   chmod +x ~/dev/frznn/linux-scripts/list-installed-new.sh
#   sudo ln -s "$HOME/dev/frznn/linux-scripts/list-installed-new.sh" \
#              /usr/local/bin/list-installed
# ─────────────────────────────────────────────────────────────────────────────

# ── Filtering ─────────────────────────────────────────────────────────────────

# Package name prefixes/patterns that indicate system/infrastructure packages
readonly SYSTEM_PATTERN='^(fonts-|linux-(modules|image|headers|firmware|generic|virtual|signed|tools|oem|lowlatency)|gir[0-9]|language-(pack|selector)|yaru-theme-|gnome-(shell$|settings-daemon|session-|initial-setup|getting-started|accessibility-|shell-extension-|keyring$|control-center$|bluetooth$|menus$|sushi$)|ubuntu-(minimal|standard|session|settings|report|wallpapers|release|docs|drivers|restricted)|branding-ubuntu|grub-|plymouth-|xserver-xorg-video-|alsa-|gstreamer1|bluez(-|$)|avahi-|cups(-|$)|foomatic|openprinting|printer-driver-|fwupd(-|$)|ibus(-|$)|speech-dispatcher|network-manager(-|$)|wpasupplicant|gsettings-ubuntu|apt-config-|debian-archive)'

# Snap names that are base/runtime snaps, not user-installed apps
readonly SNAP_BASES='^(bare$|core$|core[0-9]+|snapd$|snap-store$|gnome-[0-9]|gtk-common-themes$|mesa-[0-9])'

is_system_pkg() {
    local raw="$1"
    local pkg="${raw%%:*}"  # strip :arch suffix

    # Skip :i386 packages (32-bit libs for Wine/Steam)
    [[ "$raw" == *:i386 ]] && return 0

    # Skip lib* except libreoffice-* and *-dev (keep dev headers)
    if [[ "$pkg" == lib* ]] && [[ "$pkg" != libreoffice* ]] && [[ "$pkg" != *-dev ]]; then
        return 0
    fi

    # Skip by name pattern
    [[ "$pkg" =~ $SYSTEM_PATTERN ]] && return 0

    # Skip specific known system packages
    case "$pkg" in
        at-spi2-core|anacron|apport-gtk|appstream|base-passwd|bc|binutils|brltty|\
        ca-certificates|cdrdao|dash|dbus-x11|dirmngr|dmz-cursor-theme|dkms|\
        file|findutils|fwupd-signed|gdm3|gpg|gpg-agent|grep|grub2-common|\
        gvfs-fuse|gzip|hostname|hyphen-en-us|im-config|init|inputattach|\
        kerneloops|laptop-detect|libnotify-bin|libnss-mdns|libpam-gnome-keyring|\
        libsasl2-modules|libu2f-udev|lsb-release|mokutil|mousetweaks|\
        mythes-en-us|ncurses-base|ncurses-bin|openssl|orca|os-prober|\
        packagekit|pcmciautils|perl|policykit-desktop-privileges|rfkill|\
        snapd|update-manager|update-notifier|usb-creator-gtk|util-linux|\
        whoopsie|wireless-tools|xcursor-themes|xkb-data|xorg|xul-ext-ubufox|\
        xz-utils|yelp|zenity|openprinting-ppds|net.downloadhelper.coapp|\
        unzip|zip|wget|curl|gnupg)
            return 0 ;;
    esac

    return 1
}

# ── Helpers ───────────────────────────────────────────────────────────────────

pkg_desc() {
    dpkg-query -W -f='${binary:Summary}' "${1%%:*}" 2>/dev/null || true
}

section() {
    printf "\n\033[1m━━━ %s ━━━\033[0m\n\n" "$1"
}

# ── Sections ──────────────────────────────────────────────────────────────────

show_apt() {
    section "APT packages"
    local n=1
    while IFS= read -r pkg; do
        is_system_pkg "$pkg" && continue
        local desc
        desc=$(pkg_desc "$pkg")
        printf "%3d. %-35s %s\n" "$n" "${pkg%%:*}" "$desc"
        n=$(( n + 1 ))
    done < <(apt-mark showmanual 2>/dev/null | sort)
}

show_snap() {
    section "Snap packages"
    snap list 2>/dev/null | tail -n +2 | \
    while read -r name version _rev _track _pub _notes; do
        [[ "$name" =~ $SNAP_BASES ]] && continue
        printf "  %-30s %s\n" "$name" "$version"
    done
}

show_appimage() {
    section "AppImages (~/Applications)"
    local -a found
    mapfile -t found < <(find ~/Applications -maxdepth 1 -name "*.AppImage" 2>/dev/null | sort)
    if (( ${#found[@]} == 0 )); then
        echo "  (none found)"
    else
        for f in "${found[@]}"; do
            echo "  $(basename "$f")"
        done
    fi
}

show_npm() {
    section "npm global packages"
    if command -v npm &>/dev/null; then
        npm list -g --depth=0 2>/dev/null | tail -n +2
    else
        echo "  npm not installed"
    fi
}

show_pip() {
    section "pip packages"
    if command -v pip3 &>/dev/null; then
        pip3 list 2>/dev/null
    else
        echo "  pip3 not installed"
    fi
}

# ── Main ──────────────────────────────────────────────────────────────────────

case "${1:-all}" in
    apt)      show_apt ;;
    snap)     show_snap ;;
    appimage) show_appimage ;;
    npm)      show_npm ;;
    pip)      show_pip ;;
    all)
        show_apt
        show_snap
        show_appimage
        show_npm
        show_pip
        ;;
    *)
        echo "Usage: $(basename "$0") [apt|snap|appimage|npm|pip]"
        exit 1
        ;;
esac

echo ""
