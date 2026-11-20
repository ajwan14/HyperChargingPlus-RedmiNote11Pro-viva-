package com.hypercharge.service;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public class CommandReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (context == null || intent == null) return;
        if ("com.hypercharge.service.UPDATE_NOTIFICATION".equals(intent.getAction())) {
            String mode = intent.getStringExtra("mode");
            if (mode == null) mode = "INACTIVE";

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
                    context.startForegroundService(serviceIntent);
                }
            } catch (Exception ignored) {}
        }
    }
}
