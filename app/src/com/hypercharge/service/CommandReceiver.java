package com.hypercharge.service;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

public class CommandReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (context == null || intent == null) return;
        if ("com.hypercharge.service.UPDATE_NOTIFICATION".equals(intent.getAction())) {
            String mode = intent.getStringExtra("mode");
            if (mode == null || mode.trim().isEmpty()) mode = "NORMAL";

            Intent serviceIntent = new Intent(context, ChargeNotificationService.class);
            serviceIntent.putExtra("mode", mode);
            serviceIntent.putExtra("temp", intent.getIntExtra("temp", 0));
            serviceIntent.putExtra("battery", intent.getIntExtra("battery", 0));
            serviceIntent.putExtra("current", intent.getIntExtra("current", 0));
            serviceIntent.putExtra("appname", intent.getStringExtra("appname"));
            serviceIntent.putExtra("remaining", intent.getIntExtra("remaining", 0));
            serviceIntent.putExtra("timeleft", intent.getIntExtra("timeleft", 0));

            try {
                if ("INACTIVE".equalsIgnoreCase(mode) || "STOP".equalsIgnoreCase(mode) || "DISCONNECTED".equalsIgnoreCase(mode)) {
                    context.startService(serviceIntent);
                } else {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(serviceIntent);
                    } else {
                        context.startService(serviceIntent);
                    }
                }
            } catch (Exception ignored) {}
        }
    }
}
