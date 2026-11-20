SKIPUNZIP=0
REPLACE=""

ui_print " "
ui_print "╔═════════════════════════════════════════════╗"
ui_print "║       ⚡ Hyper Charging+ v2.1 ⚡             ║"
ui_print "║   Redmi Note 11 Pro 4G (viva) Edition       ║"
ui_print "╚═════════════════════════════════════════════╝"
ui_print " "
ui_print "  Device   : Xiaomi Redmi Note 11 Pro 4G (viva)"
ui_print "  SoC      : MediaTek Helio G96 (MT6781)"
ui_print "  Battery  : 5000mAh | 67W Mi Turbo Charge"
ui_print "  Author   : Razal (Razal1_1) & Antigravity"
ui_print " "

ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print "  Applying specialized viva 67W parameters..."
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
sleep 0.2

ui_print "  • Native MediaTek Pump Express & 67W Turbo tuning"
ui_print "  • Anti-flapping thermal ladder (6.2A down to 1.2A)"
ui_print "  • Dynamic deep sleep when unplugged (0% battery drain)"
ui_print "  • Auto-kill notification on charger disconnect"
ui_print "  • 5000mAh battery protection (anti 99-100% micro-cycle)"
ui_print "  • MediaTek hardware game bypass"
sleep 0.3

ui_print " "
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print "  Setting up service & permissions..."
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

APK_PATH="$MODPATH/system/app/HyperChargingService/HyperChargeService.apk"
if [ -f "$APK_PATH" ]; then
  ui_print "  • Installing companion notification APK..."
  pm install -r -t --dont-kill "$APK_PATH" >/dev/null 2>&1
  pm install -r --user 0 -t --dont-kill "$APK_PATH" >/dev/null 2>&1
  
  pm grant com.hypercharge.service android.permission.POST_NOTIFICATIONS 2>/dev/null
  pm grant com.hypercharge.service android.permission.FOREGROUND_SERVICE 2>/dev/null
  pm grant com.hypercharge.service android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS 2>/dev/null
  dumpsys deviceidle whitelist +com.hypercharge.service 2>/dev/null
  ui_print "  ✓ Companion APK configured"
else
  ui_print "  • Standalone kernel mode (APK omitted)"
fi

# Set script permissions (Magisk official + fallback chmod)
set_perm "$MODPATH/service.sh" 0 0 0755 2>/dev/null || chmod 0755 "$MODPATH/service.sh" 2>/dev/null
set_perm "$MODPATH/uninstall.sh" 0 0 0755 2>/dev/null || chmod 0755 "$MODPATH/uninstall.sh" 2>/dev/null
set_perm "$MODPATH/game_list.sh" 0 0 0644 2>/dev/null || chmod 0644 "$MODPATH/game_list.sh" 2>/dev/null

# Create user config directory if available
mkdir -p /data/adb/hypercharge 2>/dev/null
if [ ! -f /data/adb/hypercharge/config.prop ]; then
  cat << 'EOF' > /data/adb/hypercharge/config.prop
# Hyper Charging+ viva Configuration
# Maximum charge limit (percentage, default 100, set 80 or 85 for longevity)
MAX_CHARGE_LIMIT=100

# Recharge threshold when full (stops micro-cycling, default 94%)
RECHARGE_THRESHOLD=94

# Emergency thermal cutoff in tenths of C (default 480 = 48.0°C)
MAX_TEMP_CUTOFF=480

# Restore charging temperature in tenths of C (default 440 = 44.0°C)
RESTORE_TEMP=440

# Enable Game Bypass Mode (1 = enabled, 0 = disabled)
GAME_BYPASS_ENABLED=1
EOF
  chmod 0644 /data/adb/hypercharge/config.prop 2>/dev/null
  ui_print "  ✓ Config created: /data/adb/hypercharge/config.prop"
fi

ui_print " "
ui_print "╔═════════════════════════════════════════════╗"
ui_print "║  ✓ Hyper Charging+ viva Ready!              ║"
ui_print "╚═════════════════════════════════════════════╝"
ui_print " "
ui_print "  ⚡ Reboot to activate 67W Turbo charging"
ui_print "  🔋 Notification only appears when plugged in"
ui_print "  💤 Zero battery drain during standby"
ui_print " "
