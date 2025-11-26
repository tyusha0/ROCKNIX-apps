#!/bin/bash
# Rocknix FreeTube Installer (aarch64) — AppImage + Chromium runtime bundle
# - Main FreeTube.sh uses full GPTK mapping (D-pad, A/B, etc.)
# - Includes a minimal hotkey-only mapping file (Alt+F4) for reuse if you add kiosk launchers later

set -euo pipefail

# --- Paths & URLs ---
APP_DIR="/storage/Applications/freetube"
PORTS_DIR="/storage/roms/ports"
LAUNCH_SCRIPT_DIR="$PORTS_DIR"
PROFILE_DIR="/storage/.freetube"

GPTK_FULL="$PORTS_DIR/freetube.gptk"            # full mapping
GPTK_HOTKEY="$PORTS_DIR/freetube_hotkey.gptk"   # hotkey-only mapping
FREETUBE_LAUNCHER="$PORTS_DIR/FreeTube.sh"

FREETUBE_URL="https://github.com/FreeTubeApp/FreeTube/releases/download/v0.23.12-beta/freetube-0.23.12-beta-amd64.AppImage"
RUNTIME_URL="https://github.com/profork/ROCKNIX-apps/releases/download/r1/chromium-runtime.tar.gz"

FREETUBE_APPIMAGE="${APP_DIR}/FreeTube.AppImage"
RUNTIME_TGZ="${APP_DIR}/chromium-runtime.tar.gz"
RUNTIME_DIR_LINK="${APP_DIR}/chromium-runtime"

echo "🧭 FreeTube installer for Rocknix (aarch64)…"
sleep 1

# --- Guardrails ---
arch="$(uname -m || true)"
if [ "$arch" != "aarch64" ] && [ "$arch" != "arm64" ]; then
  echo "❌ This installer is for aarch64 only. Detected: $arch"
  exit 1
fi

mkdir -p "$APP_DIR" "$PORTS_DIR" "$PROFILE_DIR" "$LAUNCH_SCRIPT_DIR"
cd "$APP_DIR"

# --- Fetch FreeTube AppImage ---
echo "🔽 Downloading FreeTube AppImage…"
rm -f "$FREETUBE_APPIMAGE"
if ! wget -O "$FREETUBE_APPIMAGE" "$FREETUBE_URL"; then
  echo "wget failed, trying curl"
  curl -L -o "$FREETUBE_APPIMAGE" "$FREETUBE_URL"
fi
chmod +x "$FREETUBE_APPIMAGE"

# --- Fetch Chromium runtime bundle ---
echo "🔽 Downloading Chromium runtime bundle…"
rm -f "$RUNTIME_TGZ"
if ! wget -O "$RUNTIME_TGZ" "$RUNTIME_URL"; then
  echo "wget failed, trying curl"
  curl -L -o "$RUNTIME_TGZ" "$RUNTIME_URL"
fi

echo "📦 Extracting runtime…"
tar -xzf "$RUNTIME_TGZ" -C "$APP_DIR"

RUNTIME_DIR_FOUND="$(find "$APP_DIR" -type f -name 'libnss3.so' 2>/dev/null | head -n1 || true)"
if [ -z "$RUNTIME_DIR_FOUND" ]; then
  echo "❌ Could not locate runtime 'libnss3.so' after extraction."
  exit 1
fi
RUNTIME_DIR_FOUND="$(dirname "$RUNTIME_DIR_FOUND")/.."
rm -f "$RUNTIME_DIR_LINK"
ln -snf "$RUNTIME_DIR_FOUND" "$RUNTIME_DIR_LINK"
rm -f "$RUNTIME_TGZ"

# --- GPTK mappings ---
echo "🎮 Writing GPTK mappings…"

# Full map (for couch navigation)
cat > "$GPTK_FULL" <<'EOF'
up = up
down = down
left = left
right = right
a = enter
b = esc
x = ctrl+w
y = ctrl+t
start = enter
select = esc
left_analog_up = up
left_analog_down = down
left_analog_left = left
left_analog_right = right
hotkey = start+select:KEY_LEFTALT+KEY_F4
EOF

# HOTKEY-ONLY map (handy if you add kiosk launchers later)
cat > "$GPTK_HOTKEY" <<'EOF'
hotkey = start+select:KEY_LEFTALT+KEY_F4
EOF

# --- Main FreeTube launcher (full GPTK) ---
echo "🚀 Creating FreeTube launcher…"
cat > "$FREETUBE_LAUNCHER" <<EOF
#!/bin/bash
trap 'pkill -f "gptokeyb -p FreeTube"' EXIT

export DISPLAY=:0.0
export HOME="$PROFILE_DIR"

export LD_LIBRARY_PATH="$RUNTIME_DIR_LINK/lib:\${LD_LIBRARY_PATH}"
export SSL_CERT_FILE="$RUNTIME_DIR_LINK/certs/ca-certificates.crt"
export SSL_CERT_DIR="\$(dirname "\$SSL_CERT_FILE")"
export APPIMAGE_EXTRACT_AND_RUN=1

# Chromium flags that tend to be needed on Rocknix/Batocera
EXTRA_FLAGS="--no-sandbox --password-store=basic --enable-gamepad --force-dark-mode"
# If GPU is flaky on some devices, uncomment:
EXTRA_FLAGS="\$EXTRA_FLAGS --disable-gpu --use-gl=swiftshader"

# Full mapping for couch use
gptokeyb -p "FreeTube" -c "$GPTK_FULL" -k freetube &>/dev/null &
sleep 1

"$FREETUBE_APPIMAGE" \$EXTRA_FLAGS "\$@"
EOF
chmod +x "$FREETUBE_LAUNCHER"

echo
echo "✅ FreeTube installed."
echo "▶️ Launch from: $FREETUBE_LAUNCHER"
echo "   (Runtime: $RUNTIME_DIR_LINK)"
echo "🎮 Start+Select = Alt+F4"
