#!/bin/sh
source ./utils.sh

###############################################################################
# TRMNL.sh (using FBInk instead of eips [i found it more reliable for image display])
###############################################################################

# ----------------------------- USER SETTINGS -------------------------------- #
API_KEY=$(cat apikey.txt)
BASE_URL="https://trmnl.app"
RSSI="0"
USER_AGENT="trmnl-display/0.1.1"
DEBUG_MODE=false

# FBInk Path (may need a utility to find this later, for now hardcode)
FBINK="/mnt/us/extensions/MRInstaller/bin/KHF/fbink"

# Tmp folder for assets and all that
TMP_DIR="/tmp/trmnl-kindle"
mkdir -p "$TMP_DIR"

# Image Settings
# FBInk handles rotation via the -r flag
# -r 1 = 90deg, -r 2 = 180deg, -r 3 = 270deg
ROTATION=1

PNG_WIDTH=$(get_kindle_height)
PNG_HEIGHT=$(get_kindle_width)

MAC_ADDRESS=$(get_mac_address)

# ---------------------------------------------------------------------------- #

# Stub for local testing
if [ ! -f "$FBINK" ]; then
  fbink() {
    echo "[FBInk STUB] $*"
  }
else
  fbink() {
    "$FBINK" "$@"
  }
fi

# Helper for debug lines
DEBUG_Y=0

eips_debug() {
  if [ "$DEBUG_MODE" = true ]; then
    # -y: row, -t: top-aligned, -m: message
    fbink -y "$DEBUG_Y" -m "$1"
    echo "$1"
    DEBUG_Y=$((DEBUG_Y+1))
  fi
}

while true; do
  if [ "$DEBUG_MODE" = true ]; then
    fbink -c  # Clear screen
    sleep 1
  fi

  DEBUG_Y=0

  eips_debug "TRMNL Kindle Debug Script"
  eips_debug "Fetching JSON..."

  BATTERY_VOLTAGE=$(get_kindle_battery)
  RESPONSE="$(
    curl -s \
      -H "access-token: $API_KEY" \
      -H "battery-voltage: $BATTERY_VOLTAGE" \
      -H "png-width: $PNG_WIDTH" \
      -H "png-height: $PNG_HEIGHT" \
      -H "rssi: $RSSI" \
      -H "ID: $MAC_ADDRESS" \
      -A "$USER_AGENT" \
      "${BASE_URL}/api/display"
  )"

  if [ -z "$RESPONSE" ]; then
    eips_debug "Error: No JSON response."
    sleep 60
    continue
  fi

  IMAGE_URL=$(echo "$RESPONSE" | sed -n 's/.*"image_url":"\([^"]*\)".*/\1/p' | sed 's/\\u0026/\&/g')
  REFRESH_RATE=$(echo "$RESPONSE" | sed -n 's/.*"refresh_rate":\([^,}]*\).*/\1/p')
  [ -z "$REFRESH_RATE" ] && REFRESH_RATE="60"

  if [ -z "$IMAGE_URL" ]; then
    eips_debug "Error: No image_url."
    sleep 60
    continue
  fi

  FILENAME=$(echo "$RESPONSE" | sed -n 's/.*"filename":"\([^"]*\)".*/\1/p')
  if [ -z "$FILENAME" ]; then
    FILENAME=$(echo "$IMAGE_URL" | sed -n 's/.*\/\([^?/]*\)\?.*/\1/p')
    [ -z "$FILENAME" ] && FILENAME="display.png"
  fi

  IMAGE_PATH="$TMP_DIR/$FILENAME"
  rm -f "$IMAGE_PATH"

  curl -s -o "$IMAGE_PATH" -A "$USER_AGENT" "$IMAGE_URL"

  if [ ! -s "$IMAGE_PATH" ]; then
    eips_debug "Error: Download failed!"
    sleep 60
    continue
  fi

  # Display image now via FBInk
  # -c: clear, -g: image file, -r: rotation, -f: flash/refresh
  fbink -c -f
  fbink -i "$IMAGE_PATH"

  if [ "$DEBUG_MODE" = true ]; then
    fbink -y 25 -m "URL: $IMAGE_URL"
    fbink -y 26 -m "File: $IMAGE_PATH"
  fi

  sleep "$REFRESH_RATE"
done
