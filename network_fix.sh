#!/system/bin/sh
set -x # Enable verbose debug logging to stderr for logcat

#
# Magisk Module Helper Script: Network Settings Fix
#
# This script specifically targets the 'restricted_networking_mode' global setting.
# It is designed to be called by service.sh AFTER a significant delay
# to ensure Android services are fully initialized.
#
# Log file for this functionality is reset/cleared on every device reboot.
#
# Author: elmendezz
# Date: 2025-07-13
#

# --- Path and Value Configurations ---
NETWORK_FIX_LOG_DIR="/data/local/tmp" # Using known writable location
NETWORK_FIX_LOG_FILE="${NETWORK_FIX_LOG_DIR}/network_fix_log.txt"

TARGET_RESTRICTED_NETWORKING_MODE="0"
GLOBAL_RESTRICTED_NETWORKING_KEY="restricted_networking_mode"
GLOBAL_SETTINGS_DB="/data/data/com.android.providers.settings/databases/settings.db" # Standard path
SQLITE3_BIN="/system/bin/sqlite3" # Common path, adjust if 'which sqlite3' gives a different path


# --- Helper Function (Logging) ---

# Function to log messages with timestamp to the Network Fix log file
log_network_fix() {
    local message="$1"
    local logfile="$NETWORK_FIX_LOG_FILE"

    # Ensure log file is writable. Redirect stderr to /dev/null for setup commands.
    if [ ! -f "$logfile" ] || [ "$(stat -c %a "$logfile" 2>/dev/null)" != "666" ]; then
        rm -f "$logfile" 2>/dev/null
        cat /dev/null > "$logfile" 2>/dev/null
        chmod 666 "$logfile" 2>/dev/null
    fi
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$logfile"
}


# Function to initialize the Network Fix log file (clears content on each boot)
initialize_network_fix_log() {
    local logfile="$NETWORK_FIX_LOG_FILE"

    rm -f "$logfile" 2>/dev/null
    cat /dev/null > "$logfile" 2>/dev/null
    chmod 666 "$logfile" 2>/dev/null

    log_network_fix "----------------------------------------------------"
    log_network_fix "Network Fix Script Initialized for this boot (at $NETWORK_FIX_LOG_FILE)."
}


# --- Main Logic for Network Fix ---
initialize_network_fix_log
log_network_fix "Starting network_fix.sh execution."

log_network_fix "Attempting to get current value for $GLOBAL_RESTRICTED_NETWORKING_KEY."
current_restricted_networking_mode=$(/system/bin/settings get global "$GLOBAL_RESTRICTED_NETWORKING_KEY" 2>/dev/null)

# If 'settings' command failed, try direct sqlite3 access for reading.
if [ "$?" -ne 0 ] || [ -z "$current_restricted_networking_mode" ]; then
    log_network_fix "WARNING: 'settings get' failed or returned empty. Attempting to read via sqlite3."
    if [ -f "$GLOBAL_SETTINGS_DB" ] && [ -x "$SQLITE3_BIN" ]; then
        current_restricted_networking_mode=$("$SQLITE3_BIN" "$GLOBAL_SETTINGS_DB" "SELECT value FROM global WHERE name='$GLOBAL_RESTRICTED_NETWORKING_KEY';" 2>/dev/null)
        log_network_fix "Read from sqlite3: '$current_restricted_networking_mode'"
    else
        log_network_fix "ERROR: sqlite3 binary or settings database not found/accessible for reading."
        current_restricted_networking_mode="<unknown>" # Set a placeholder to ensure the script tries to set it.
    fi
fi

log_network_fix "Current $GLOBAL_RESTRICTED_NETWORKING_KEY: '$current_restricted_networking_mode'"

if [ "$current_restricted_networking_mode" != "$TARGET_RESTRICTED_NETWORKING_MODE" ]; then
    log_network_fix "Value differs. Setting $GLOBAL_RESTRICTED_NETWORKING_KEY to $TARGET_RESTRICTED_NETWORKING_MODE (was '$current_restricted_networking_mode')."
    
    # Try the 'settings' command as it's the standard way
    /system/bin/settings put global "$GLOBAL_RESTRICTED_NETWORKING_KEY" "$TARGET_RESTRICTED_NETWORKING_MODE" 2>/dev/null
    if [ $? -eq 0 ]; then
        log_network_fix "$GLOBAL_RESTRICTED_NETWORKING_KEY set successfully using 'settings'."
    else
        log_network_fix "WARNING: 'settings put' failed (Exit code: $?). Attempting to set via sqlite3."
        # If 'settings put' failed, try direct sqlite3 modification
        if [ -f "$GLOBAL_SETTINGS_DB" ] && [ -x "$SQLITE3_BIN" ]; then
            # Check if the key exists before attempting to update/insert
            EXISTING_ROW=$("$SQLITE3_BIN" "$GLOBAL_SETTINGS_DB" "SELECT COUNT(*) FROM global WHERE name='$GLOBAL_RESTRICTED_NETWORKING_KEY';" 2>/dev/null)
            
            if [ "$EXISTING_ROW" -gt 0 ]; then
                "$SQLITE3_BIN" "$GLOBAL_SETTINGS_DB" "UPDATE global SET value='$TARGET_RESTRICTED_NETWORKING_MODE' WHERE name='$GLOBAL_RESTRICTED_NETWORKING_KEY';" 2>/dev/null
            else
                "$SQLITE3_BIN" "$GLOBAL_SETTINGS_DB" "INSERT INTO global (name, value) VALUES ('$GLOBAL_RESTRICTED_NETWORKING_KEY', '$TARGET_RESTRICTED_NETWORKING_MODE');" 2>/dev/null
            fi

            if [ $? -eq 0 ]; then
                log_network_fix "$GLOBAL_RESTRICTED_NETWORKING_KEY set successfully using sqlite3."
            else
                log_network_fix "ERROR: Failed to set $GLOBAL_RESTRICTED_NETWORKING_KEY using sqlite3. Exit code: $?."
            fi
        else
            log_network_fix "ERROR: sqlite3 binary or settings database not found/accessible for writing. Could not set $GLOBAL_RESTRICTED_NETWORKING_KEY."
        fi
    fi
else
    log_network_fix "$GLOBAL_RESTRICTED_NETWORKING_KEY already set to $TARGET_RESTRICTED_NETWORKING_MODE."
fi

log_network_fix "Network Fix Script Finished its execution."