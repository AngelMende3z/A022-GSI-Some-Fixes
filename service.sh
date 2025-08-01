#!/system/bin/sh
set -x # Enable verbose debug logging to stderr (crucial for logcat)

#
# Magisk Module Service Script: TSP Fix for Samsung Galaxy A02
#
# This script monitors screen brightness changes and attempts to
# re-initialize the Touch Sensor Panel (TSP) when a change is detected,
# INCLUDING transitions to or from zero brightness.
#
# The TSP fix will ONLY trigger when the device is on the lock screen.
#
# This script also calls 'services_boot_values.sh' to set specific system
# values at boot time, and 'network_fix.sh' after a delay for network settings.
#
# Log file for this functionality is reset/cleared on every device reboot.
#
# Author: elmendezz
# Date: 2025-07-13
#

# --- Path Configurations ---
TSP_CMD_PATH="/sys/class/sec/tsp/cmd"
TSP_RESULT_PATH="/sys/class/sec/tsp/cmd_result"
BRIGHTNESS_PATH="/sys/class/backlight/panel/brightness"

# Primary Log File
TSP_LOG_FILE="/data/local/tmp/tsp_fix_log.txt"
# NEW Debug Log File for 'set -x' output from called scripts
DEBUG_LOG_FILE="/data/local/tmp/DebugLogTSP.log.txt"

# Fallback for MODPATH if it's not set by Magisk (as observed previously)
if [ -z "$MODPATH" ]; then
    MODULE_BASE_DIR="/data/adb/modules/tsp_fix_a022m" # !!! IMPORTANT: Ensure this matches your module's ID in module.prop !!!
else
    MODULE_BASE_DIR="$MODPATH"
fi

# --- Helper Functions for TSP Log (simplified for direct log file writes) ---

# Function to log messages with timestamp to the TSP log file
log_tsp() {
    local message="$1"
    local logfile="$TSP_LOG_FILE"

    if [ ! -f "$logfile" ] || [ "$(stat -c %a "$logfile" 2>/dev/null)" != "666" ]; then
        rm -f "$logfile" 2>/dev/null
        cat /dev/null > "$logfile" 2>/dev/null
        chmod 666 "$logfile" 2>/dev/null
    fi
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$logfile"
}

# Function to log messages with timestamp to the Debug Log file
log_debug() {
    local message="$1"
    local logfile="$DEBUG_LOG_FILE"

    if [ ! -f "$logfile" ] || [ "$(stat -c %a "$logfile" 2>/dev/null)" != "666" ]; then
        rm -f "$logfile" 2>/dev/null
        cat /dev/null > "$logfile" 2>/dev/null
        chmod 666 "$logfile" 2>/dev/null
    fi
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$logfile"
}


# Function to initialize a SPECIFIC log file (will reset/cleared on each run)
initialize_tsp_log_file() {
    local logfile="$1"

    rm -f "$logfile"
    cat /dev/null > "$logfile"
    chmod 666 "$logfile"

    log_tsp "----------------------------------------------------"
    log_tsp "Primary Log initialized for this boot."
}

# Function to initialize the Debug Log file (clears content on each boot)
initialize_debug_log_file() {
    local logfile="$1"

    rm -f "$logfile"
    cat /dev/null > "$logfile"
    chmod 666 "$logfile"

    log_debug "----------------------------------------------------"
    log_debug "Debug Log initialized for this boot."
}


# Function to attempt to re-initialize the TSP connection
perform_tsp_fix() {
    log_tsp "Attempting TSP fix: Writing 'check_connection' to $TSP_CMD_PATH"
    if echo "check_connection" > "$TSP_CMD_PATH"; then
        log_tsp "Successfully wrote to TSP command file."
        TSP_RESULT=$(cat "$TSP_RESULT_PATH" 2>&1)
        if [ $? -eq 0 ]; then
            log_tsp "TSP command result: $TSP_RESULT"
        else
            log_tsp "ERROR: Failed to read TSP command result. Error: $TSP_RESULT"
        fi
        return 0
    else
        log_tsp "ERROR: Failed to write to TSP command file ($TSP_CMD_PATH). Check permissions or path."
        return 1
    fi
}

# Check if the device is currently on the lock screen
is_lockscreen_active() {
    if dumpsys activity activities | grep -q "mDreamingLockscreen=true"; then
        return 0 # True (lock screen is active)
    else
        return 1 # False (lock screen is not active)
    fi
}

# --- Main Script Logic ---

# 1. Initialize TSP log file and Debug log file
initialize_tsp_log_file "$TSP_LOG_FILE"
initialize_debug_log_file "$DEBUG_LOG_FILE"

log_tsp "----------------------------------------------------"
log_tsp "TSP Fix Script Started (Magisk Service - Lock Screen Specific)."


# 2. Execute the boot values script (general system properties)
BOOT_VALUES_SCRIPT="${MODULE_BASE_DIR}/services_boot_values.sh"

log_tsp "DEBUG: MODPATH (resolved) is: $MODULE_BASE_DIR"
log_tsp "DEBUG: Expected path for services_boot_values.sh: $BOOT_VALUES_SCRIPT"

if [ -f "$BOOT_VALUES_SCRIPT" ]; then
    log_tsp "DEBUG: services_boot_values.sh file found at path. Attempting to execute."
    # Redirect all output from services_boot_values.sh to DebugLogTSP.log.txt
    sh "$BOOT_VALUES_SCRIPT" >> "$DEBUG_LOG_FILE" 2>&1
    EXIT_CODE_SH=$?

    log_tsp "DEBUG: Command 'sh $BOOT_VALUES_SCRIPT' finished. Exit code from 'sh' command: $EXIT_CODE_SH. (Details in DebugLogTSP.log.txt)"

    if [ "$EXIT_CODE_SH" -ne 0 ]; then
        log_tsp "WARNING: Command 'sh $BOOT_VALUES_SCRIPT' returned non-zero exit code: $EXIT_CODE_SH."
        log_tsp "STATUS: services_boot_values.sh did NOT run successfully or had an issue starting."
    else
        log_tsp "STATUS: services_boot_values.sh completed successfully. Check DebugLogTSP.log.txt for content."
    fi
else
    log_tsp "ERROR: Boot values script NOT found at $BOOT_VALUES_SCRIPT."
    log_tsp "STATUS: services_boot_values.sh was NOT found to execute."
fi
log_tsp "DEBUG: Finished attempt to call services_boot_values.sh."


# 3. Get initial brightness for TSP monitoring
old_brightness=$(cat "$BRIGHTNESS_PATH" 2>/dev/null)
if [ -z "$old_brightness" ]; then
    log_tsp "ERROR: Could not read initial brightness from $BRIGHTNESS_PATH. Exiting script."
    exit 1
fi
log_tsp "Initial brightness for TSP monitoring: $old_brightness"

# 4. Asynchronously call network_fix.sh after a significant delay
NETWORK_FIX_SCRIPT="${MODULE_BASE_DIR}/network_fix.sh"
if [ -f "$NETWORK_FIX_SCRIPT" ]; then
    log_tsp "DEBUG: Starting network_fix.sh in background with a 30-second delay."
    # Execute network_fix.sh in the background after a delay.
    # Redirect all output from network_fix.sh to DebugLogTSP.log.txt
    ( sleep 30 && sh "$NETWORK_FIX_SCRIPT" >> "$DEBUG_LOG_FILE" 2>&1 ) &
    log_tsp "DEBUG: network_fix.sh scheduled for delayed execution. Check DebugLogTSP.log.txt for its output."
else
    log_tsp "ERROR: network_fix.sh script NOT found at $NETWORK_FIX_SCRIPT. Cannot schedule network fix."
fi


# 5. Start brightness monitoring loop (continuous background process)
log_tsp "Starting brightness monitoring loop..."
while true; do
    sleep 0.6 # Monitoring interval

    current_brightness=$(cat "$BRIGHTNESS_PATH" 2>/dev/null)

    # Check if brightness read was successful
    if [ -z "$current_brightness" ]; then
        log_tsp "WARNING: Could not read current brightness from $BRIGHTNESS_PATH. Skipping current cycle."
        sleep 5
        continue
    fi

    # Logic to activate TSP fix:
    # 1. If brightness has changed
    # 2. AND the device is currently on the lock screen
    if [ "$old_brightness" != "$current_brightness" ]; then
        if is_lockscreen_active; then
            log_tsp "Brightness changed from $old_brightness to $current_brightness. Device IS on lock screen. Triggering TSP fix."
            perform_tsp_fix
        else
            log_tsp "Brightness changed from $old_brightness to $current_brightness. Device IS NOT on lock screen. Skipping TSP fix."
        fi
    fi

    # Update old brightness value for the next iteration
    old_brightness=$current_brightness
done

log_tsp "TSP Fix Script Finished Unexpectedly."