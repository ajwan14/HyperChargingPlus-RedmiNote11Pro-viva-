#!/system/bin/sh
# ==============================================================================
# Hyper Charging+ v2.1 (Redmi Note 11 Pro 4G viva Edition)
# Hardware: MediaTek Helio G96 (MT6781) | 5000mAh | 67W Xiaomi Turbo Charge
# Compatible with: Magisk, KernelSU, APatch
# ==============================================================================

# Robust MODDIR resolution
MODDIR="${0%/*}"
[ "$MODDIR" = "$0" ] || [ -z "$MODDIR" ] && MODDIR="/data/adb/modules/hypercharging"

LOG_FILE="/sdcard/hyper_charge.log"
MAX_LOG_SIZE=102400

# Wait for Android boot completed
until [ "$(getprop sys.boot_completed)" = "1" ]; do
  sleep 2
done

# Initialize log
echo "$(date '+%Y-%m-%d %H:%M:%S') - Hyper Charging+ viva initialized" > "$LOG_FILE"

# ------------------------------------------------------------------------------
# User Configuration
# ------------------------------------------------------------------------------
CONFIG_FILE="/data/adb/hypercharge/config.prop"
MAX_CHARGE_LIMIT=100
RECHARGE_THRESHOLD=94
MAX_TEMP_CUTOFF=480
RESTORE_TEMP=440
GAME_BYPASS_ENABLED=1

load_config() {
  if [ -f "$CONFIG_FILE" ]; then
    _VAL=$(grep -E '^MAX_CHARGE_LIMIT=' "$CONFIG_FILE" | cut -d= -f2 | tr -d ' \r\n')
    [ -n "$_VAL" ] && [ "$_VAL" -ge 60 ] && [ "$_VAL" -le 100 ] && MAX_CHARGE_LIMIT="$_VAL"
    
    _VAL=$(grep -E '^RECHARGE_THRESHOLD=' "$CONFIG_FILE" | cut -d= -f2 | tr -d ' \r\n')
    [ -n "$_VAL" ] && [ "$_VAL" -ge 50 ] && [ "$_VAL" -le 98 ] && RECHARGE_THRESHOLD="$_VAL"
    
    _VAL=$(grep -E '^MAX_TEMP_CUTOFF=' "$CONFIG_FILE" | cut -d= -f2 | tr -d ' \r\n')
    [ -n "$_VAL" ] && [ "$_VAL" -ge 420 ] && [ "$_VAL" -le 520 ] && MAX_TEMP_CUTOFF="$_VAL"

    _VAL=$(grep -E '^RESTORE_TEMP=' "$CONFIG_FILE" | cut -d= -f2 | tr -d ' \r\n')
    [ -n "$_VAL" ] && [ "$_VAL" -ge 380 ] && [ "$_VAL" -le 460 ] && RESTORE_TEMP="$_VAL"

    _VAL=$(grep -E '^GAME_BYPASS_ENABLED=' "$CONFIG_FILE" | cut -d= -f2 | tr -d ' \r\n')
    [ -n "$_VAL" ] && GAME_BYPASS_ENABLED="$_VAL"
  fi
}
load_config

# Battery capacity locked to Redmi Note 11 Pro 4G specification
BATTERY_CAPACITY_MAH=5000

# ------------------------------------------------------------------------------
# 67W Xiaomi Turbo Current Profiles (uA)
# ------------------------------------------------------------------------------
TURBO_CURRENT=6200000     # 6.2A Max Turbo (< 38.0°C)
HIGH_CURRENT=5200000      # 5.2A High Speed (38.0°C - 40.5°C)
BALANCED_CURRENT=4200000  # 4.2A Balanced (40.5°C - 42.5°C)
WARM_CURRENT=3200000      # 3.2A Warm (42.5°C - 44.5°C)
COOLING_CURRENT=2000000   # 2.0A Cooling (44.5°C - 46.5°C)
THROTTLE_CURRENT=1200000  # 1.2A Safety Cap (46.5°C - 47.9°C)
TRICKLE_CURRENT=1000000   # 1.0A Trickle (>= 99%)

# Taper limits based on battery percentage
CAP_85_CURRENT=4200000
CAP_90_CURRENT=3200000
CAP_95_CURRENT=2000000

# ------------------------------------------------------------------------------
# State Variables
# ------------------------------------------------------------------------------
LAST_MODE="DISCONNECTED"
NOTIF_ACTIVE=0
TEMP_CUTOFF=0
CHARGING_STOPPED=0
FULL_SINCE=0
FULL_CHARGE_STOP_DELAY=120
LAST_TIER=""
LAST_CAP=0
LAST_TEMP_C=0
LAST_CUR_MA=0
LAST_BROADCAST_TIME=0
LAST_BROADCAST_MODE=""
BYPASS_START=0
BYPASS_MAX_SECONDS=14400
BYPASS_MIN_BATTERY=20
CACHED_FG_PKG=""
CACHED_FG_LABEL=""
LOG_COUNTER=0
HAS_APK=0

[ -f "$MODDIR/game_list.sh" ] && . "$MODDIR/game_list.sh"
[ -f "/data/adb/hypercharge/custom_games.txt" ] && GAME_PACKAGES="$GAME_PACKAGES $(cat /data/adb/hypercharge/custom_games.txt 2>/dev/null)"

get_uptime_sec() {
  _UP=$(cat /proc/uptime 2>/dev/null)
  echo "${_UP%%.*}"
}

write_node() { [ -e "$1" ] && echo "$2" > "$1" 2>/dev/null; }
read_node()  { [ -f "$1" ] && cat "$1" 2>/dev/null; }

read_node_fb() {
  for _N in "$@"; do
    _V=$(read_node "$_N")
    if [ -n "$_V" ]; then
      echo "$_V"
      return
    fi
  done
}

# ------------------------------------------------------------------------------
# MediaTek MT6781 Fast Charge Unlocks (Xiaomi Specific)
# ------------------------------------------------------------------------------
enable_mtk_fastcharge() {
  write_node /sys/class/power_supply/battery/fast_charge 1
  write_node /sys/class/power_supply/battery/charging_enabled 1
  write_node /sys/class/power_supply/battery/battery_charging_enabled 1
  write_node /sys/class/power_supply/battery/input_current_limited 0
  write_node /sys/class/power_supply/battery/step_charging_enabled 0
  write_node /sys/class/power_supply/battery/thermal_charge_level 0
  write_node /sys/class/power_supply/battery/thermal_input_current_limit 0
  write_node /sys/class/power_supply/battery/charge_control_limit 0
  write_node /sys/class/power_supply/battery/system_temp_level 0
  write_node /sys/class/power_supply/battery/sub_charger_fast_charge 1
  write_node /sys/class/power_supply/battery/input_suspend 0
  write_node /sys/class/power_supply/usb/input_suspend 0
  write_node /sys/class/power_supply/main/input_suspend 0
  if [ -f /proc/mtk_battery_cmd/current_cmd ]; then
    echo 0 0 > /proc/mtk_battery_cmd/current_cmd 2>/dev/null
  fi
}

apply_current() {
  _TARGET="$1"
  # Apply to battery & main nodes
  write_node /sys/class/power_supply/battery/current_max "$_TARGET"
  write_node /sys/class/power_supply/battery/constant_charge_current_max "$_TARGET"
  write_node /sys/class/power_supply/battery/batt_tune_fast_charge_current "$_TARGET"
  write_node /sys/class/power_supply/battery/batt_tune_input_charge_current "$_TARGET"
  write_node /sys/class/power_supply/main/current_max "$_TARGET"
  write_node /sys/class/power_supply/main/constant_charge_current_max "$_TARGET"
  write_node /sys/class/power_supply/usb/current_max "$_TARGET"
  write_node /sys/class/power_supply/ac/current_max "$_TARGET"
}

stop_charging() {
  write_node /sys/class/power_supply/battery/input_suspend 1
  write_node /sys/class/power_supply/usb/input_suspend 1
  write_node /sys/class/power_supply/main/input_suspend 1
  write_node /sys/class/power_supply/battery/charging_enabled 0
  if [ -f /proc/mtk_battery_cmd/current_cmd ]; then
    echo 0 1 > /proc/mtk_battery_cmd/current_cmd 2>/dev/null
  fi
}

start_charging() {
  write_node /sys/class/power_supply/battery/input_suspend 0
  write_node /sys/class/power_supply/usb/input_suspend 0
  write_node /sys/class/power_supply/main/input_suspend 0
  write_node /sys/class/power_supply/battery/charging_enabled 1
  write_node /sys/class/power_supply/battery/battery_charging_enabled 1
  if [ -f /proc/mtk_battery_cmd/current_cmd ]; then
    echo 0 0 > /proc/mtk_battery_cmd/current_cmd 2>/dev/null
  fi
  enable_mtk_fastcharge
  dumpsys battery reset >/dev/null 2>&1
}

# ------------------------------------------------------------------------------
# Notification Lifecycle (Clean: Only Active When Plugged In)
# ------------------------------------------------------------------------------
check_companion_apk() {
  if pm path com.hypercharge.service >/dev/null 2>&1; then
    HAS_APK=1
  else
    HAS_APK=0
  fi
}
check_companion_apk

start_notification_service() {
  if [ "$HAS_APK" = "1" ]; then
    am start-foreground-service --user 0 -n com.hypercharge.service/.ChargeNotificationService >/dev/null 2>&1 || \
    am start-foreground-service --user 0 -n com.hypercharge.service/.NotificationService >/dev/null 2>&1
    NOTIF_ACTIVE=1
  fi
}

stop_notification_service() {
  if [ "$NOTIF_ACTIVE" = "1" ] || [ "$HAS_APK" = "1" ]; then
    am stopservice --user 0 -n com.hypercharge.service/.ChargeNotificationService >/dev/null 2>&1
    am stopservice --user 0 -n com.hypercharge.service/.NotificationService >/dev/null 2>&1
    NOTIF_ACTIVE=0
  fi
}

send_notification_update() {
  _MODE="$1"
  _TEMP_C="$2"
  _BAT="$3"
  _CUR_MA="$4"
  _APP_NAME="${5:-}"
  _REMAINING="${6:-0}"
  _TIME_LEFT="${7:-0}"

  [ "$NOTIF_ACTIVE" = "0" ] && return

  am broadcast --user 0 \
    -a com.hypercharge.service.UPDATE_NOTIFICATION \
    -n com.hypercharge.service/.CommandReceiver \
    --es mode "$_MODE" --ei temp "$_TEMP_C" --ei battery "$_BAT" \
    --ei current "${_CUR_MA:-0}" --es appname "${_APP_NAME:-}" \
    --ei remaining "${_REMAINING:-0}" --ei timeleft "${_TIME_LEFT:-0}" >/dev/null 2>&1
}

# ------------------------------------------------------------------------------
# Hardware Query Helpers
# ------------------------------------------------------------------------------
is_screen_on() {
  dumpsys power 2>/dev/null | grep -qE 'mWakefulness=Awake|mWakefulnessRaw=Awake'
}

get_foreground_pkg() {
  # Priority 1: dumpsys activity (fastest & ignores volume sliders/overlays)
  _PKG=$(dumpsys activity activities 2>/dev/null | grep -m1 "topResumedActivity" | grep -oE '[a-z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)+/' | cut -d/ -f1)
  # Priority 2: dumpsys window mCurrentFocus
  if [ -z "$_PKG" ]; then
    _PKG=$(dumpsys window 2>/dev/null | grep -m1 "mCurrentFocus" | grep -oE '[a-z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)+/' | cut -d/ -f1)
  fi
  # Priority 3: fallback
  if [ -z "$_PKG" ]; then
    _PKG=$(dumpsys window 2>/dev/null | grep -E "mCurrentFocus|mFocusedApp" | head -1 | grep -oE '[a-z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)+' | head -1)
  fi
  echo "$_PKG"
}

get_app_label() {
  _PKG="$1"
  [ -z "$_PKG" ] && echo "" && return
  if [ "$_PKG" = "$CACHED_FG_PKG" ] && [ -n "$CACHED_FG_LABEL" ]; then
    echo "$CACHED_FG_LABEL"
    return
  fi
  _LABEL=$(echo "$_PKG" | awk -F. '{print $NF}')
  CACHED_FG_PKG="$_PKG"
  CACHED_FG_LABEL="$_LABEL"
  echo "$_LABEL"
}

is_game_active() {
  [ "$GAME_BYPASS_ENABLED" != "1" ] && return 1
  _FG=$(get_foreground_pkg)
  [ -z "$_FG" ] && return 1
  echo "$GAME_PACKAGES" | grep -qx "$_FG"
}

# Clean cleanup on exit
_exit_handler() {
  stop_notification_service
  start_charging
  exit 0
}
trap '_exit_handler' EXIT TERM INT HUP

# Initial cleanup of any stuck previous states
stop_notification_service

# ==============================================================================
# Main Event Loop
# ==============================================================================
while true; do
  NOW=$(get_uptime_sec)
  [ -z "$NOW" ] && NOW=0

  # Log maintenance every ~100 loops
  LOG_COUNTER=$((LOG_COUNTER + 1))
  if [ "$LOG_COUNTER" -ge 100 ]; then
    LOG_COUNTER=0
    load_config
    check_companion_apk
    if [ -f "$LOG_FILE" ]; then
      LOG_SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null)
      [ -n "$LOG_SIZE" ] && [ "$LOG_SIZE" -gt "$MAX_LOG_SIZE" ] && \
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Log rotated" > "$LOG_FILE"
    fi
  fi

  # 1. Read battery status & cable connection
  BATT_STATUS=$(read_node /sys/class/power_supply/battery/status)
  USB_ONLINE=$(read_node /sys/class/power_supply/usb/online)
  AC_ONLINE=$(read_node /sys/class/power_supply/ac/online)
  MAIN_ONLINE=$(read_node /sys/class/power_supply/main/online)
  USB_PRESENT=$(read_node /sys/class/power_supply/usb/present)

  USB_ON=0
  if [ "$USB_ONLINE" = "1" ] || [ "$AC_ONLINE" = "1" ] || [ "$MAIN_ONLINE" = "1" ] || [ "$USB_PRESENT" = "1" ] || [ "$BATT_STATUS" = "Charging" ] || [ "$BATT_STATUS" = "Full" ]; then
    USB_ON=1
  fi

  # ----------------------------------------------------------------------------
  # UNPLUGGED STATE: Immediate Dismissal & Deep Sleep
  # ----------------------------------------------------------------------------
  if [ "$USB_ON" = "0" ]; then
    if [ "$NOTIF_ACTIVE" = "1" ] || [ "$LAST_MODE" != "DISCONNECTED" ]; then
      stop_notification_service
      dumpsys battery reset >/dev/null 2>&1
      LAST_MODE="DISCONNECTED"
      LAST_TIER=""
      CHARGING_STOPPED=0
      TEMP_CUTOFF=0
      FULL_SINCE=0
      BYPASS_START=0
      echo "$(date '+%H:%M:%S') - Cable disconnected: notification dismissed, entering sleep mode" >> "$LOG_FILE"
    fi

    # When unplugged: Sleep 10s. No dumpsys. Allows CPU Deep Sleep!
    sleep 10
    continue
  fi

  # ----------------------------------------------------------------------------
  # PLUGGED IN STATE: Active Fast Charging & Monitoring
  # ----------------------------------------------------------------------------
  if [ "$LAST_MODE" = "DISCONNECTED" ]; then
    echo "$(date '+%H:%M:%S') - Charger connected (67W Viva Engine)" >> "$LOG_FILE"
    start_charging
    start_notification_service
    LAST_MODE="NORMAL"
    LAST_BROADCAST_TIME=0
  fi

  # Read Temperature with Auto-Scaling (supports milli-Celsius & tenths)
  TEMP_RAW=$(read_node_fb /sys/class/power_supply/battery/temp /sys/class/power_supply/bms/temp)
  [ -z "$TEMP_RAW" ] && TEMP_RAW=300

  if [ "$TEMP_RAW" -gt 10000 ]; then
    TEMP_TENTHS=$((TEMP_RAW / 100))
  elif [ "$TEMP_RAW" -lt 100 ]; then
    TEMP_TENTHS=$((TEMP_RAW * 10))
  else
    TEMP_TENTHS="$TEMP_RAW"
  fi
  TEMP_C=$((TEMP_TENTHS / 10))
  TEMP_DEC=$((TEMP_TENTHS % 10))

  # Read Capacity (%)
  CAP=$(read_node_fb /sys/class/power_supply/battery/capacity /sys/class/power_supply/bms/capacity)
  [ -z "$CAP" ] && CAP=50

  # Read Current (mA)
  CUR_RAW=$(read_node_fb /sys/class/power_supply/battery/current_now /sys/class/power_supply/bms/current_now)
  [ -z "$CUR_RAW" ] && CUR_RAW=0
  CUR_ABS=${CUR_RAW#-}
  if [ "$CUR_ABS" -lt 10000 ] && [ "$CUR_ABS" -gt 0 ]; then
    CUR_ABS=$((CUR_ABS * 1000))
  fi
  CUR_MA=$((CUR_ABS / 1000))

  # Estimated Time to Full (minutes)
  TIME_REMAINING=0
  if [ "$CUR_MA" -gt 200 ] && [ "$CAP" -lt "$MAX_CHARGE_LIMIT" ]; then
    REMAINING_MAH=$(( (MAX_CHARGE_LIMIT - CAP) * BATTERY_CAPACITY_MAH / 100 ))
    TIME_REMAINING=$(( REMAINING_MAH * 60 / CUR_MA ))
    [ "$TIME_REMAINING" -gt 240 ] && TIME_REMAINING=240
  fi

  # ----------------------------------------------------------------------------
  # Safety 1: Thermal Cutoff & Restore
  # ----------------------------------------------------------------------------
  if [ "$TEMP_TENTHS" -ge "$MAX_TEMP_CUTOFF" ]; then
    if [ "$TEMP_CUTOFF" = "0" ]; then
      stop_charging
      TEMP_CUTOFF=1
      echo "$(date '+%H:%M:%S') - CRITICAL TEMP: ${TEMP_C}.${TEMP_DEC}°C! Charging stopped" >> "$LOG_FILE"
      send_notification_update "INACTIVE" "$TEMP_C" "$CAP" "0" "" "0" "0"
    fi
    sleep 3
    continue
  elif [ "$TEMP_CUTOFF" = "1" ]; then
    if [ "$TEMP_TENTHS" -le "$RESTORE_TEMP" ]; then
      start_charging
      TEMP_CUTOFF=0
      echo "$(date '+%H:%M:%S') - Temperature restored to ${TEMP_C}.${TEMP_DEC}°C. Resuming charging" >> "$LOG_FILE"
    else
      sleep 3
      continue
    fi
  fi

  # ----------------------------------------------------------------------------
  # Safety 2: 100% Full Charge & Anti Micro-Cycling Protection
  # ----------------------------------------------------------------------------
  if [ "$CAP" -ge "$MAX_CHARGE_LIMIT" ]; then
    if [ "$FULL_SINCE" -eq 0 ]; then
      FULL_SINCE="$NOW"
      echo "$(date '+%H:%M:%S') - Reached max limit (${CAP}%). Starting stop timer" >> "$LOG_FILE"
    fi
    if [ $((NOW - FULL_SINCE)) -ge "$FULL_CHARGE_STOP_DELAY" ]; then
      if [ "$CHARGING_STOPPED" = "0" ]; then
        stop_charging
        CHARGING_STOPPED=1
        echo "$(date '+%H:%M:%S') - Full charge reached: charging safely stopped to preserve battery" >> "$LOG_FILE"
      fi
      send_notification_update "FULL" "$TEMP_C" "$CAP" "0" "" "0" "0"
      sleep 3
      continue
    fi
  else
    FULL_SINCE=0
    # Anti micro-cycling: Do NOT recharge at 99%! Wait until threshold (e.g. 94%)
    if [ "$CHARGING_STOPPED" = "1" ]; then
      if [ "$CAP" -le "$RECHARGE_THRESHOLD" ]; then
        start_charging
        CHARGING_STOPPED=0
        echo "$(date '+%H:%M:%S') - Battery dropped to ${CAP}% (<= ${RECHARGE_THRESHOLD}%). Resuming charge" >> "$LOG_FILE"
      else
        sleep 3
        continue
      fi
    fi
  fi

  # ----------------------------------------------------------------------------
  # Mode 3: Game Bypass Mode (MediaTek Hardware Suspend)
  # ----------------------------------------------------------------------------
  if [ "$GAME_BYPASS_ENABLED" = "1" ] && [ "$CAP" -gt "$BYPASS_MIN_BATTERY" ] && is_screen_on && is_game_active; then
    FG_PKG=$(get_foreground_pkg)
    FG_LABEL=$(get_app_label "$FG_PKG")

    if [ "$LAST_MODE" != "GAME" ]; then
      echo "$(date '+%H:%M:%S') - Entering Game Bypass for $FG_LABEL ($FG_PKG)" >> "$LOG_FILE"
      stop_charging
      LAST_MODE="GAME"
      BYPASS_START="$NOW"
    fi

    BYPASS_ELAPSED=$((NOW - BYPASS_START))
    BYPASS_MIN_LEFT=$(( (BYPASS_MAX_SECONDS - BYPASS_ELAPSED) / 60 ))
    [ "$BYPASS_MIN_LEFT" -lt 0 ] && BYPASS_MIN_LEFT=0

    send_notification_update "GAME" "$TEMP_C" "$CAP" "$CUR_MA" "$FG_LABEL" "$BYPASS_MIN_LEFT" "0"
    sleep 1.5
    continue
  elif [ "$LAST_MODE" = "GAME" ]; then
    echo "$(date '+%H:%M:%S') - Exiting Game Bypass. Restoring 67W charging" >> "$LOG_FILE"
    start_charging
    LAST_MODE="NORMAL"
    LAST_TIER=""
    sleep 1
  fi

  # ----------------------------------------------------------------------------
  # Mode 4: 67W Turbo Thermal Ladder with State Machine Hysteresis (0.8°C anti-flap)
  # ----------------------------------------------------------------------------
  determine_tier() {
    _T="$1"
    _P="$2"
    case "$_P" in
      TURBO)
        [ "$_T" -ge 380 ] && echo "HIGH" && return
        echo "TURBO"
        ;;
      HIGH)
        [ "$_T" -lt 372 ] && echo "TURBO" && return
        [ "$_T" -ge 405 ] && echo "BALANCED" && return
        echo "HIGH"
        ;;
      BALANCED)
        [ "$_T" -lt 397 ] && echo "HIGH" && return
        [ "$_T" -ge 425 ] && echo "WARM" && return
        echo "BALANCED"
        ;;
      WARM)
        [ "$_T" -lt 417 ] && echo "BALANCED" && return
        [ "$_T" -ge 445 ] && echo "COOLING" && return
        echo "WARM"
        ;;
      COOLING)
        [ "$_T" -lt 437 ] && echo "WARM" && return
        [ "$_T" -ge 465 ] && echo "THROTTLE" && return
        echo "COOLING"
        ;;
      THROTTLE)
        [ "$_T" -lt 457 ] && echo "COOLING" && return
        echo "THROTTLE"
        ;;
      *)
        if [ "$_T" -lt 380 ]; then echo "TURBO"
        elif [ "$_T" -lt 405 ]; then echo "HIGH"
        elif [ "$_T" -lt 425 ]; then echo "BALANCED"
        elif [ "$_T" -lt 445 ]; then echo "WARM"
        elif [ "$_T" -lt 465 ]; then echo "COOLING"
        else echo "THROTTLE"
        fi
        ;;
    esac
  }

  TARGET_TIER=$(determine_tier "$TEMP_TENTHS" "$LAST_TIER")
  case "$TARGET_TIER" in
    TURBO)    TARGET_CUR=$TURBO_CURRENT ;;
    HIGH)     TARGET_CUR=$HIGH_CURRENT ;;
    BALANCED) TARGET_CUR=$BALANCED_CURRENT ;;
    WARM)     TARGET_CUR=$WARM_CURRENT ;;
    COOLING)  TARGET_CUR=$COOLING_CURRENT ;;
    THROTTLE) TARGET_CUR=$THROTTLE_CURRENT ;;
    *)        TARGET_CUR=$BALANCED_CURRENT ;;
  esac

  # Battery percentage tapering
  if [ "$CAP" -ge 99 ]; then
    [ "$TARGET_CUR" -gt "$TRICKLE_CURRENT" ] && TARGET_CUR=$TRICKLE_CURRENT
  elif [ "$CAP" -ge 95 ]; then
    [ "$TARGET_CUR" -gt "$CAP_95_CURRENT" ] && TARGET_CUR=$CAP_95_CURRENT
  elif [ "$CAP" -ge 90 ]; then
    [ "$TARGET_CUR" -gt "$CAP_90_CURRENT" ] && TARGET_CUR=$CAP_90_CURRENT
  elif [ "$CAP" -ge 85 ]; then
    [ "$TARGET_CUR" -gt "$CAP_85_CURRENT" ] && TARGET_CUR=$CAP_85_CURRENT
  fi

  # Apply parameters if tier changed
  if [ "$TARGET_TIER" != "$LAST_TIER" ]; then
    echo "$(date '+%H:%M:%S') - Tier switch: $LAST_TIER -> $TARGET_TIER ($((TARGET_CUR/1000))mA @ ${TEMP_C}.${TEMP_DEC}°C)" >> "$LOG_FILE"
    LAST_TIER="$TARGET_TIER"
    enable_mtk_fastcharge
    apply_current "$TARGET_CUR"
  fi

  # Send notification update (throttled to avoid IPC spam)
  TIME_SINCE_BC=$((NOW - LAST_BROADCAST_TIME))
  if [ "$LAST_TEMP_C" -gt 0 ]; then
    if [ "$TEMP_C" -ge "$LAST_TEMP_C" ]; then
      TEMP_DIFF=$((TEMP_C - LAST_TEMP_C))
    else
      TEMP_DIFF=$((LAST_TEMP_C - TEMP_C))
    fi
  else
    TEMP_DIFF=99
  fi

  if [ "$TIME_SINCE_BC" -ge 4 ] || [ "$CAP" != "$LAST_CAP" ] || [ "$TEMP_DIFF" -ge 1 ] || [ "$LAST_BROADCAST_MODE" != "NORMAL" ]; then
    send_notification_update "NORMAL" "$TEMP_C" "$CAP" "$CUR_MA" "" "$TIME_REMAINING" "0"
    LAST_CAP="$CAP"
    LAST_TEMP_C="$TEMP_C"
    LAST_CUR_MA="$CUR_MA"
    LAST_BROADCAST_TIME="$NOW"
    LAST_BROADCAST_MODE="NORMAL"
  fi

  # Steady charging polling interval (2.5 seconds)
  sleep 2.5
done
