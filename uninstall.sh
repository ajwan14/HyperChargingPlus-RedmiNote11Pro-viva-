#!/system/bin/sh
# Uninstaller for Hyper Charging+ (viva Edition)

# Stop and kill companion app/services
am stopservice --user 0 -n com.hypercharge.service/.ChargeNotificationService 2>/dev/null
am stopservice --user 0 -n com.hypercharge.service/.NotificationService 2>/dev/null
am force-stop com.hypercharge.service 2>/dev/null
am kill com.hypercharge.service 2>/dev/null

pkill -9 -f "com.hypercharge" 2>/dev/null
pkill -9 -f "service.sh" 2>/dev/null

# Reset battery state in Android system server
dumpsys battery reset 2>/dev/null

# Restore kernel charging nodes to factory defaults
for NODE in \
  /sys/class/power_supply/battery/input_suspend \
  /sys/class/power_supply/usb/input_suspend \
  /sys/class/power_supply/ac/input_suspend \
  /sys/class/power_supply/main/input_suspend \
  /sys/class/power_supply/battery/parallel_disable
do
  [ -e "$NODE" ] && echo 0 > "$NODE" 2>/dev/null
done

echo 1 > /sys/class/power_supply/battery/charging_enabled 2>/dev/null
echo 1 > /sys/class/power_supply/battery/battery_charging_enabled 2>/dev/null
echo 0 > /sys/class/power_supply/battery/input_current_limited 2>/dev/null
echo 1 > /sys/class/power_supply/battery/step_charging_enabled 2>/dev/null

# MediaTek command restore
if [ -f /proc/mtk_battery_cmd/current_cmd ]; then
  echo 0 0 > /proc/mtk_battery_cmd/current_cmd 2>/dev/null
fi

# Clean companion APK and settings if installed
dumpsys deviceidle whitelist -com.hypercharge.service 2>/dev/null
pm revoke com.hypercharge.service android.permission.POST_NOTIFICATIONS 2>/dev/null
pm revoke com.hypercharge.service android.permission.FOREGROUND_SERVICE 2>/dev/null
pm revoke com.hypercharge.service android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS 2>/dev/null
cmd notification delete_channel com.hypercharge.service 2>/dev/null
pm uninstall --user 0 com.hypercharge.service 2>/dev/null
pm uninstall com.hypercharge.service 2>/dev/null

rm -rf /data/app/*com.hypercharge.service* 2>/dev/null
rm -rf /data/data/com.hypercharge.service 2>/dev/null
rm -rf /data/user_de/0/com.hypercharge.service 2>/dev/null

# Clean logs & temporary scripts
rm -f /sdcard/hyper_charge.log 2>/dev/null
rm -f /data/local/tmp/hc_cleanup.sh 2>/dev/null
rm -rf /data/adb/hypercharge 2>/dev/null

exit 0
