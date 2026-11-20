package com.hypercharge.service;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.BatteryManager;

public class BootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (context == null || intent == null) return;
        String action = intent.getAction();
        if (Intent.ACTION_BOOT_COMPLETED.equals(action) ||
            "android.intent.action.LOCKED_BOOT_COMPLETED".equals(action) ||
            "android.intent.action.QUICKBOOT_POWERON".equals(action) ||
            "com.htc.intent.action.QUICKBOOT_POWERON".equals(action)) {

            // Check battery plugged status before starting service
            Intent batteryStatus = context.registerReceiver(null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
            int plugged = batteryStatus != null ? batteryStatus.getIntExtra(BatteryManager.EXTRA_PLUGGED, -1) : 0;

            // Only start service if device is actively plugged into a charger at boot
            if (plugged > 0) {
                Intent serviceIntent = new Intent(context, ChargeNotificationService.class);
                serviceIntent.putExtra("mode", "NORMAL");
                try {
                    context.startForegroundService(serviceIntent);
                } catch (Exception ignored) {}
            }
        }
    }
}
