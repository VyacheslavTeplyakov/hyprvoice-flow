#!/bin/bash
set -euo pipefail

# ==============================================================================
# hyprvoice-flow installer
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Installing hyprvoice-flow..."

# 1. Dependency checks
echo "--> Checking dependencies..."
MISSING_DEPS=()
for cmd in hyprctl wtype wl-copy wl-paste playerctl wpctl jq; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        MISSING_DEPS+=("$cmd")
    fi
done

if ! command -v hyprvoice >/dev/null 2>&1; then
    echo "  [!] hyprvoice not found in PATH."
    echo "      Install it via AUR (e.g. paru -S hyprvoice-bin) or from GitHub:"
    echo "      https://github.com/leonardotrapani/hyprvoice"
fi

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo "  [!] Missing utilities: ${MISSING_DEPS[*]}"
    echo "      On Arch/CachyOS: sudo pacman -S wtype wl-clipboard playerctl wireplumber jq"
fi

# 2. Install wtype wrapper to ~/.local/bin/
echo "--> Installing wtype wrapper to ~/.local/bin/wtype..."
mkdir -p "$HOME/.local/bin"
if [ -f "$HOME/.local/bin/wtype" ]; then
    cp "$HOME/.local/bin/wtype" "$HOME/.local/bin/wtype.bak.$(date +%s)"
fi
cp "$SCRIPT_DIR/bin/wtype" "$HOME/.local/bin/wtype"
chmod +x "$HOME/.local/bin/wtype"

# Ensure ~/.local/bin is in PATH check
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo "  [NOTE] Ensure ~/.local/bin is in your PATH ahead of /usr/bin in your shell rc!"
fi

# 3. Install controller script to ~/.config/hypr/scripts/
echo "--> Installing hyprvoice_talk.sh to ~/.config/hypr/scripts/..."
mkdir -p "$HOME/.config/hypr/scripts"
cp "$SCRIPT_DIR/scripts/hyprvoice_talk.sh" "$HOME/.config/hypr/scripts/hyprvoice_talk.sh"
chmod +x "$HOME/.config/hypr/scripts/hyprvoice_talk.sh"

# 4. Configure hyprvoice
mkdir -p "$HOME/.config/hyprvoice"
if [ -f "$HOME/.config/hyprvoice/config.toml" ]; then
    echo "--> Existing ~/.config/hyprvoice/config.toml found: keeping untouched (API key preserved)."
else
    echo "--> No config.toml found. Setting up from template..."
    if [ -n "${GROQ_API_KEY:-}" ]; then
        sed "s/YOUR_GROQ_API_KEY_HERE/$GROQ_API_KEY/" "$SCRIPT_DIR/config/config.toml.example" > "$HOME/.config/hyprvoice/config.toml"
        echo "  [+] Configured with GROQ_API_KEY from environment."
    else
        read -rp "Enter your Groq API key (leave empty to configure manually later): " user_key
        if [ -n "$user_key" ]; then
            sed "s/YOUR_GROQ_API_KEY_HERE/$user_key/" "$SCRIPT_DIR/config/config.toml.example" > "$HOME/.config/hyprvoice/config.toml"
            echo "  [+] API key saved to ~/.config/hyprvoice/config.toml."
        else
            cp "$SCRIPT_DIR/config/config.toml.example" "$HOME/.config/hyprvoice/config.toml"
            echo "  [!] Remember to edit ~/.config/hyprvoice/config.toml and insert your Groq API key!"
        fi
    fi
    chmod 600 "$HOME/.config/hyprvoice/config.toml"
fi

# 5. Install systemd user service
echo "--> Installing systemd service..."
mkdir -p "$HOME/.config/systemd/user"
cp "$SCRIPT_DIR/systemd/hyprvoice.service" "$HOME/.config/systemd/user/hyprvoice.service"
systemctl --user daemon-reload
if systemctl --user is-enabled hyprvoice >/dev/null 2>&1 || [ -f "$HOME/.config/systemd/user/default.target.wants/hyprvoice.service" ]; then
    systemctl --user restart hyprvoice.service || true
else
    systemctl --user enable --now hyprvoice.service || true
fi

# 6. Optional ChatGPT / Codex flags
if [ -d "$HOME/.config" ]; then
    if [ ! -f "$HOME/.config/chatgpt-flags.conf" ]; then
        cp "$SCRIPT_DIR/config/chatgpt-flags.conf" "$HOME/.config/chatgpt-flags.conf"
        echo "--> Installed ~/.config/chatgpt-flags.conf (forces native Wayland for ChatGPT/Codex)."
    fi
fi

echo ""
echo "======================================================================"
echo " [SUCCESS] hyprvoice-flow successfully installed!"
echo "======================================================================"
echo ""
echo "Next step: Add keybindings to your ~/.config/hypr/hyprland.conf:"
echo ""
echo "  # Side mouse button (Push-to-Talk on hold, Hands-free on click):"
echo "  bind  = , mouse:275, exec, ~/.config/hypr/scripts/hyprvoice_talk.sh start"
echo "  bindr = , mouse:275, exec, ~/.config/hypr/scripts/hyprvoice_talk.sh stop"
echo ""
echo "Then reload Hyprland config (hyprctl reload)."
