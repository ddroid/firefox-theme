#!/usr/bin/env bash

# Catppuccin Firefox Theme Installer
# Discovers the active Firefox profile and links userChrome.css and userContent.css

set -e

THEME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIREFOX_FOLDER=""
PROFILE_NAME=""
ALL_PROFILES=false

usage() {
    cat << EOF
Catppuccin Firefox Theme Installer

Usage: $(basename "$0") [OPTIONS]

Options:
  -f <path>        Set custom Firefox root directory (e.g. ~/.mozilla/firefox)
  -p <profile>     Install to a specific profile name or directory
  -a, --all        Install to all discovered profiles
  -h, --help       Show this help message

By default, the script automatically discovers your Firefox installation and
installs into the active (default) profile.
EOF
    exit 0
}

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--firefox-dir)
            FIREFOX_FOLDER="$2"
            shift 2
            ;;
        -p|--profile)
            PROFILE_NAME="$2"
            shift 2
            ;;
        -a|--all)
            ALL_PROFILES=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Error: Unknown argument: $1" >&2
            usage
            ;;
    esac
done

# Potential Firefox installation root directories
candidate_firefox_dirs() {
    local dirs=()
    if [[ -n "$FIREFOX_FOLDER" ]]; then
        dirs+=("$FIREFOX_FOLDER")
    else
        dirs+=(
            "${XDG_CONFIG_HOME:-$HOME/.config}/mozilla/firefox"
            "$HOME/.mozilla/firefox"
            "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox"
            "$HOME/snap/firefox/common/.mozilla/firefox"
            # LibreWolf
            "${XDG_CONFIG_HOME:-$HOME/.config}/librewolf"
            "$HOME/.librewolf"
            "$HOME/.var/app/io.gitlab.librewolf-community/.librewolf"
            # Floorp
            "$HOME/.floorp"
            "$HOME/.var/app/one.ablaze.floorp/.floorp"
            # Waterfox
            "$HOME/.waterfox"
            "$HOME/.var/app/net.waterfox.waterfox/.waterfox"
            # macOS
            "$HOME/Library/Application Support/Firefox"
            # Windows / MSYS / Git Bash
            "${APPDATA:-$HOME/AppData/Roaming}/Mozilla/Firefox"
        )
    fi

    for dir in "${dirs[@]}"; do
        if [[ -d "$dir" && -f "$dir/profiles.ini" ]]; then
            echo "$dir"
        fi
    done
}

# Discover the active profile in a Firefox directory
find_active_profile() {
    local ff_dir="$1"
    local prof_arg="$2"
    local profiles_ini="$ff_dir/profiles.ini"
    local installs_ini="$ff_dir/installs.ini"

    # 1. User specified profile name or path
    if [[ -n "$prof_arg" ]]; then
        if [[ -d "$ff_dir/$prof_arg" ]]; then
            echo "$ff_dir/$prof_arg"
            return 0
        elif [[ -d "$prof_arg" ]]; then
            echo "$prof_arg"
            return 0
        fi

        # Match Name=<prof_arg> in profiles.ini
        local matched_path
        matched_path=$(awk -F= -v target="$prof_arg" '
            /^\[Profile/ { in_sec=1; matched=0; path="" }
            in_sec && $1 == "Name" && $2 == target { matched=1 }
            in_sec && $1 == "Path" { path=$2 }
            in_sec && /^$/ { if (matched && path != "") print path; in_sec=0 }
            END { if (matched && path != "") print path }
        ' "$profiles_ini" | head -n1)

        if [[ -n "$matched_path" ]]; then
            if [[ "$matched_path" = /* ]]; then
                echo "$matched_path"
            else
                echo "$ff_dir/$matched_path"
            fi
            return 0
        fi
        echo "Error: Profile '$prof_arg' not found in $ff_dir" >&2
        return 1
    fi

    local active_rel_path=""

    # 2. Check installs.ini for Default=...
    if [[ -f "$installs_ini" ]]; then
        active_rel_path=$(awk -F= '
            /^\[Install/ { in_inst=1 }
            in_inst && $1 == "Default" { print $2; exit }
        ' "$installs_ini")
    fi

    # 3. Check profiles.ini [Install...] sections for Default=...
    if [[ -z "$active_rel_path" && -f "$profiles_ini" ]]; then
        active_rel_path=$(awk -F= '
            /^\[Install/ { in_inst=1 }
            in_inst && $1 == "Default" { print $2; exit }
        ' "$profiles_ini")
    fi

    # 4. Check profiles.ini [Profile...] sections for Default=1
    if [[ -z "$active_rel_path" && -f "$profiles_ini" ]]; then
        active_rel_path=$(awk -F= '
            /^\[Profile/ {
                if (is_default && path != "") { print path; found=1; exit }
                is_default=0; path=""
            }
            $1 == "Default" && $2 == "1" { is_default=1 }
            $1 == "Path" { path=$2 }
            END {
                if (!found && is_default && path != "") print path
            }
        ' "$profiles_ini")
    fi

    # Verify candidate from installs.ini / profiles.ini
    if [[ -n "$active_rel_path" ]]; then
        local candidate
        if [[ "$active_rel_path" = /* ]]; then
            candidate="$active_rel_path"
        else
            candidate="$ff_dir/$active_rel_path"
        fi
        if [[ -d "$candidate" ]]; then
            echo "$candidate"
            return 0
        fi
    fi

    # 5. Fallback: Find profile folder with the most recent activity
    local best_profile=""
    local best_mtime=0
    local paths=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && paths+=("$line")
    done < <(grep -E "^Path=" "$profiles_ini" | cut -d= -f2-)

    for p in "${paths[@]}"; do
        local full_p
        if [[ "$p" = /* ]]; then
            full_p="$p"
        else
            full_p="$ff_dir/$p"
        fi

        if [[ -d "$full_p" ]]; then
            local mtime=0
            for tf in "$full_p/places.sqlite" "$full_p/prefs.js" "$full_p/sessionstore.jsonlz4" "$full_p"; do
                if [[ -e "$tf" ]]; then
                    local t
                    t=$(stat -c %Y "$tf" 2>/dev/null || stat -f %m "$tf" 2>/dev/null || echo 0)
                    if [[ "$t" -gt "$mtime" ]]; then
                        mtime="$t"
                    fi
                fi
            done
            if [[ "$mtime" -gt "$best_mtime" || -z "$best_profile" ]]; then
                best_mtime="$mtime"
                best_profile="$full_p"
            fi
        fi
    done

    if [[ -n "$best_profile" && -d "$best_profile" ]]; then
        echo "$best_profile"
        return 0
    fi

    return 1
}

# Link a single file or directory with backup handling
link_item() {
    local source="$1"
    local dest="$2"

    if [[ -L "$dest" ]]; then
        local current_target
        current_target=$(readlink "$dest")
        if [[ "$current_target" == "$source" ]]; then
            echo "    [OK] Already linked: $(basename "$dest")"
            return 0
        fi
        rm -f "$dest"
    elif [[ -e "$dest" ]]; then
        local backup="${dest}.backup.$(date +%Y%m%d%H%M%S)"
        echo "    [i] Backing up existing $(basename "$dest") to $(basename "$backup")"
        mv "$dest" "$backup"
    fi

    ln -s "$source" "$dest"
    echo "    [+] Linked $(basename "$dest") -> $source"
}

# Update or insert a preference in user.js
set_pref() {
    local file="$1"
    local pref="$2"
    local val="$3"

    if [[ ! -f "$file" ]]; then
        echo "user_pref(\"$pref\", $val);" > "$file"
    else
        if grep -q "user_pref(\"$pref\"" "$file"; then
            sed -i.bak -E "s|user_pref\(\"$pref\",\s*[^)]+\);|user_pref(\"$pref\", $val);|g" "$file" && rm -f "${file}.bak"
        else
            echo "user_pref(\"$pref\", $val);" >> "$file"
        fi
    fi
}

install_to_profile() {
    local profile_path="$1"
    echo "==> Installing Catppuccin theme to profile:"
    echo "    $profile_path"

    local chrome_dir="$profile_path/chrome"
    mkdir -p "$chrome_dir"

    # Link stylesheets and theme assets
    link_item "$THEME_DIR/userChrome.css" "$chrome_dir/userChrome.css"
    link_item "$THEME_DIR/userContent.css" "$chrome_dir/userContent.css"
    link_item "$THEME_DIR/theme" "$chrome_dir/theme"
    if [[ -f "$THEME_DIR/icon.svg" ]]; then
        link_item "$THEME_DIR/icon.svg" "$chrome_dir/icon.svg"
    fi

    # Ensure custom override files exist so user imports do not error
    if [[ ! -f "$chrome_dir/customChrome.css" ]]; then
        cat << 'EOF' > "$chrome_dir/customChrome.css"
/* Add custom userChrome overrides here. This file is preserved across theme updates. */
EOF
    fi

    if [[ ! -f "$chrome_dir/customContent.css" ]]; then
        cat << 'EOF' > "$chrome_dir/customContent.css"
/* Add custom userContent overrides here. This file is preserved across theme updates. */
EOF
    fi

    # Configure user.js
    local userjs="$profile_path/user.js"
    echo "    [*] Configuring required preferences in user.js..."
    set_pref "$userjs" "toolkit.legacyUserProfileCustomizations.stylesheets" "true"
    set_pref "$userjs" "svg.context-properties.content.enabled" "true"
    set_pref "$userjs" "browser.uidensity" "0"

    echo "    [✓] Profile setup complete."
}

# Main discovery loop
mapfile -t FOUND_DIRS < <(candidate_firefox_dirs)

if [[ ${#FOUND_DIRS[@]} -eq 0 ]]; then
    echo "Error: No Firefox installation directory with 'profiles.ini' was found." >&2
    echo "Specify your Firefox directory manually using: $0 -f /path/to/firefox" >&2
    exit 1
fi

PROFILES_INSTALLED=0

for ff_dir in "${FOUND_DIRS[@]}"; do
    echo "Found Firefox installation: $ff_dir"

    if $ALL_PROFILES; then
        # Install to all profiles
        while IFS= read -r rel_p; do
            local full_p
            if [[ "$rel_p" = /* ]]; then
                full_p="$rel_p"
            else
                full_p="$ff_dir/$rel_p"
            fi
            if [[ -d "$full_p" ]]; then
                install_to_profile "$full_p"
                PROFILES_INSTALLED=$((PROFILES_INSTALLED + 1))
            fi
        done < <(grep -E "^Path=" "$ff_dir/profiles.ini" | cut -d= -f2-)
    else
        # Install to discovered active profile
        if active_prof=$(find_active_profile "$ff_dir" "$PROFILE_NAME"); then
            install_to_profile "$active_prof"
            PROFILES_INSTALLED=$((PROFILES_INSTALLED + 1))
        else
            echo "  Warning: Could not determine active profile in $ff_dir" >&2
        fi
    fi
done

if [[ $PROFILES_INSTALLED -gt 0 ]]; then
    echo ""
    echo "Done! Installed to $PROFILES_INSTALLED profile(s)."
    echo "Please restart Firefox for changes to take effect."
    echo "If styles do not load, verify that 'toolkit.legacyUserProfileCustomizations.stylesheets' is true in about:config."
else
    echo "Error: No profiles could be configured." >&2
    exit 1
fi
