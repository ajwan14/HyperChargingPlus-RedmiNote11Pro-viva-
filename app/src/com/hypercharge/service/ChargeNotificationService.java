package com.hypercharge.service;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.os.Build;
import android.os.IBinder;

public class ChargeNotificationService extends Service {
    private static final String CHANNEL_ID = "hypercharge_channel";
    private static final int NOTIFICATION_ID = 1;
    private NotificationManager notificationManager;

    @Override
    public void onCreate() {
        super.onCreate();
        notificationManager = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
        createNotificationChannel();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent == null) {
            stopForegroundService();
            return START_NOT_STICKY;
        }

        String mode = intent.getStringExtra("mode");
        if (mode == null || mode.trim().isEmpty()) {
            mode = "NORMAL";
        }

        // When disconnected or inactive, immediately drop notification and terminate service
        if ("INACTIVE".equalsIgnoreCase(mode) || "STOP".equalsIgnoreCase(mode) || "DISCONNECTED".equalsIgnoreCase(mode)) {
            stopForegroundService();
            return START_NOT_STICKY;
        }

        final int temp = intent.getIntExtra("temp", 0);
        final int battery = intent.getIntExtra("battery", 0);
        final int current = intent.getIntExtra("current", 0);
        final String appName = intent.getStringExtra("appname");
        final int remaining = intent.getIntExtra("remaining", 0);
        final int timeLeft = intent.getIntExtra("timeleft", 0);

        try {
            createNotificationChannel();
            Notification notification = buildNotification(mode, temp, battery, current, appName, remaining, timeLeft);
            startForeground(NOTIFICATION_ID, notification);
        } catch (Exception ignored) {}

        return START_NOT_STICKY;
    }

    private void stopForegroundService() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE);
            } else {
                stopForeground(true);
            }
            if (notificationManager != null) {
                notificationManager.cancel(NOTIFICATION_ID);
            }
        } catch (Exception ignored) {}
        stopSelf();
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && notificationManager != null) {
            NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                "Hyper Charging+ Status",
                NotificationManager.IMPORTANCE_DEFAULT
            );
            channel.setDescription("Real-time battery and fast charging status notifications");
            channel.setShowBadge(true);
            channel.enableVibration(false);
            channel.enableLights(false);
            channel.setSound(null, null);
            channel.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);
            notificationManager.createNotificationChannel(channel);
        }
    }

    private Notification buildNotification(String mode, int temp, int battery, int current, String appName, int remaining, int timeLeft) {
        String title;
        String subTitle;
        String contentText;

        boolean isGame = "GAME".equalsIgnoreCase(mode);
        boolean isFull = "FULL".equalsIgnoreCase(mode);
        boolean isSwitchGame = "SWITCHING_GAME".equalsIgnoreCase(mode);
        boolean isSwitchNormal = "SWITCHING_NORMAL".equalsIgnoreCase(mode);

        if (isGame) {
            title = "Bypass Active" + (appName != null && !appName.isEmpty() ? " — " + appName : "");
            subTitle = "Hyper Charging+🎮";
            String timeStr = formatTime(remaining);
            contentText = battery + "%  •  " + temp + "°C" + (!timeStr.isEmpty() ? "  •  ⏱️ " + timeStr : "");
        } else if (isFull) {
            title = "Battery Full — Charging Stopped";
            subTitle = "Hyper Charging+⚡";
            contentText = battery + "%  •  " + temp + "°C  •  🔋 Full";
        } else if (isSwitchGame) {
            title = "Activating Bypass Charging⚡";
            subTitle = "Hyper Charging+⚡";
            contentText = battery + "%  •  " + temp + "°C";
        } else if (isSwitchNormal) {
            title = "Activating Fast Charging";
            subTitle = "Hyper Charging+⚡";
            contentText = battery + "%  •  " + temp + "°C";
        } else {
            // NORMAL Fast Charging
            title = "Fast Charging Active";
            subTitle = "Hyper Charging+⚡";
            String timeStr = formatTime(remaining);
            contentText = battery + "%  •  " + temp + "°C  •  ⚡ " + current + "mA" + (!timeStr.isEmpty() ? "  •  ⏱️ " + timeStr : "");
        }

        Notification.Builder builder;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            builder = new Notification.Builder(this, CHANNEL_ID);
        } else {
            builder = new Notification.Builder(this);
        }

        builder.setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(contentText)
            .setSubText(subTitle)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setPriority(Notification.PRIORITY_HIGH)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setCategory(Notification.CATEGORY_STATUS);

        try {
            Intent clickIntent = new Intent(Intent.ACTION_POWER_USAGE_SUMMARY);
            clickIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            PendingIntent pi = PendingIntent.getActivity(
                this, 0, clickIntent,
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ? PendingIntent.FLAG_IMMUTABLE : 0
            );
            builder.setContentIntent(pi);
        } catch (Exception ignored) {}

        return builder.build();
    }

    private String formatTime(int minutes) {
        if (minutes <= 0) return "";
        int h = minutes / 60;
        int m = minutes % 60;
        if (h > 0) {
            return h + "h " + m + "m left";
        } else {
            return m + "m left";
        }
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public void onDestroy() {
        stopForegroundService();
        super.onDestroy();
    }
}
