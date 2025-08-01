#!/system/bin/sh
set -x # Enable verbose debug logging to stderr (STILL CRUCIAL FOR LOGCAT DEBUGGING)

#
# Magisk Module Helper Script: Boot Values Configuration
#
# This script sets specific global settings and system properties at boot.
# It is designed to be called by the main service.sh script.
#
# Log file for this functionality is reset/cleared on every device reboot.
#
# Author: elmendezz
# Date: 2025-07-13
#

# --- Path and Value Configurations ---
# Placing log back in /data/local/tmp as it proved writable
BOOT_VALUES_LOG_DIR="/data/local/tmp" # This directory already exists
BOOT_VALUES_LOG_FILE="${BOOT_VALUES_LOG_DIR}/boot_values_log.txt"


# Values for Boot Configuration
# Restricted Networking Mode logic has been moved to network_fix.sh
# TARGET_RESTRICTED_NETWORKING_MODE="0"
# GLOBAL_RESTRICTED_NETWORKING_KEY="restricted_networking_mode"

TARGET_OVERLAY_DEVINPUTJACK="true"
PERSIST_OVERLAY_DEVINPUTJACK_KEY="persist.sys.overlay.devinputjack"

# --- Helper Function (Highly Robust Logging) ---

# Function to log messages with timestamp to the Boot Values log file
log_boot() {
    local message="$1"
    local logfile="$BOOT_VALUES_LOG_FILE"

    if [ ! -f "$logfile" ] || [ "$(stat -c %a "$logfile" 2>/dev/null)" != "666" ]; then
        rm -f "$logfile" 2>/dev/null
        cat /dev/null > "$logfile" 2>/dev/null
        chmod 666 "$logfile" 2>/dev/null
    fi
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$logfile"
}


# Function to initialize the Boot Values log file (clears content on each boot)
initialize_boot_values_log() {
    local logfile="$BOOT_VALUES_LOG_FILE"

    rm -f "$logfile" 2>/dev/null
    cat /dev/null > "$logfile" 2>/dev/null
    chmod 666 "$logfile" 2>/dev/null

    log_boot "----------------------------------------------------"
    log_boot "Primary Log Initialized for this boot (at $BOOT_VALUES_LOG_FILE)."
}


# Function to check and set persistent system values
set_boot_values() {
    initialize_boot_values_log

    log_boot "Boot Values Configuration Started."
    log_boot "Checking and setting boot values..."

    # --- Value #1: global restricted_networking_mode ---
    # This logic has been moved to network_fix.sh
    log_boot "Restricted Networking Mode logic moved to network_fix.sh."


    # --- Value #2: persist.sys.overlay.devinputjack ---
    log_boot "Attempting to get current value for $PERSIST_OVERLAY_DEVINPUTJACK_KEY."
    current_overlay_devinputjack=$(getprop "$PERSIST_OVERLAY_DEVINPUTJACK_KEY" 2>/dev/null)
    log_boot "Current $PERSIST_OVERLAY_DEVINPUTJACK_KEY: '$current_overlay_devinputjack'"
    if [ "$current_overlay_devinputjack" != "$TARGET_OVERLAY_DEVINPUTJACK" ]; then
        log_boot "Value differs. Setting $PERSIST_OVERLAY_DEVINPUTJACK_KEY to $TARGET_OVERLAY_DEVINPUTJACK (was '$current_overlay_devinputjack')."
        setprop "$PERSIST_OVERLAY_DEVINPUTJACK_KEY" "$TARGET_OVERLAY_DEVINPUTJACK" 2>/dev/null
        if [ $? -eq 0 ]; then
            log_boot "$PERSIST_OVERLAY_DEVINPUTJACK_KEY set successfully."
        else
            log_boot "ERROR: Failed to set $PERSIST_OVERLAY_DEVINPUTJACK_KEY. Exit code: $?."
        fi
    else
        log_boot "$PERSIST_OVERLAY_DEVINPUTJACK_KEY already set to $TARGET_OVERLAY_DEVINPUTJACK."
    fi
    log_boot "Boot Values Check/Set Finished."
    log_boot "Boot Values Script Finished its execution."
}

# --- Main Logic for this Script ---

set_boot_values # Execute the main function of this script.

# This script does not need a 'while true' loop as it performs actions only at boot.
# It will execute once and then exit.