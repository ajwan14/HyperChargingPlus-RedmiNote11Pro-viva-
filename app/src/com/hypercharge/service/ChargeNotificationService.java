package com.hypercharge.service;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Intent;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;

public class ChargeNotificationService extends Service {
    private static final String CHANNEL_ID = "hypercharge_channel";
    private static final int NOTIFICATION_ID = 1;
    private NotificationManager notificationManager;
    private final Handler handler = new Handler(Looper.getMainLooper());

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
        if (mode == null) mode = "INACTIVE";

        // CRITICAL FIX: If disconnected or inactive, immediately stop foreground & terminate service!
        if ("INACTIVE".equalsIgnoreCase(mode) || "STOP".equalsIgnoreCase(mode) || "DISCONNECTED".equalsIgnoreCase(mode)) {
            stopForegroundService();
            return START_NOT_STICKY;
        }

        final String finalMode = mode;
        final int temp = intent.getIntExtra("temp", 0);
        final int battery = intent.getIntExtra("battery", 0);
        final int current = intent.getIntExtra("current", 0);
        final String appName = intent.getStringExtra("appname");
        final int remaining = intent.getIntExtra("remaining", 0);
        final int timeLeft = intent.getIntExtra("timeleft", 0);

        handler.post(() -> {
            try {
                Notification notification = buildNotification(finalMode, temp, battery, current, appName, remaining, timeLeft);
                startForeground(NOTIFICATION_ID, notification);
            } catch (Exception ignored) {}
        });

        return START_NOT_STICKY;
    }

    private void stopForegroundService() {
        handler.post(() -> {
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
        });
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                "Hyper Charging+ status notifications",
                NotificationManager.IMPORTANCE_LOW
            );
            channel.setDescription("Real-time battery and fast charging status notifications");
            channel.setShowBadge(false);
            channel.enableVibration(false);
            channel.enableLights(false);
            channel.setSound(null, null);
            if (notificationManager != null) {
                notificationManager.createNotificationChannel(channel);
            }
        }
    }

    private Notification buildNotification(String mode, int temp, int battery, int current, String appName, int remaining, int timeLeft) {
        String title;
        String subTitle;
        String contentText;
        int icon;

        boolean isGame = "GAME".equalsIgnoreCase(mode);
        boolean isFull = "FULL".equalsIgnoreCase(mode);
        boolean isSwitchGame = "SWITCHING_GAME".equalsIgnoreCase(mode);
        boolean isSwitchNormal = "SWITCHING_NORMAL".equalsIgnoreCase(mode);

        if (isGame) {
            title = "Bypass Active" + (appName != null && !appName.isEmpty() ? " — " + appName : "");
            subTitle = "Hyper Charging+🎮";
            String timeStr = formatTime(remaining);
            contentText = battery + "%  •  " + temp + "°C" + (!timeStr.isEmpty() ? "  •  ⏱️ " + timeStr : "");
            icon = R.drawable.ic_game;
        } else if (isFull) {
            title = "Battery Full — Charging Stopped";
            subTitle = "Hyper Charging+⚡";
            contentText = battery + "%  •  " + temp + "°C  •  🔋 Full";
            icon = R.drawable.ic_notification;
        } else if (isSwitchGame) {
            title = "Activating Bypass Charging⚡";
            subTitle = "Hyper Charging+⚡";
            contentText = battery + "%  •  " + temp + "°C";
            icon = R.drawable.ic_game;
        } else if (isSwitchNormal) {
            title = "Activating Fast Charging";
            subTitle = "Hyper Charging+⚡";
            contentText = battery + "%  •  " + temp + "°C";
            icon = R.drawable.ic_notification;
        } else {
            // NORMAL Fast Charging
            title = "Fast Charging Active";
            subTitle = "Hyper Charging+⚡";
            String timeStr = formatTime(remaining);
            contentText = battery + "%  •  " + temp + "°C  •  ⚡ " + current + "mA" + (!timeStr.isEmpty() ? "  •  ⏱️ " + timeStr : "");
            icon = R.drawable.ic_notification;
        }

        Notification.Builder builder;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            builder = new Notification.Builder(this, CHANNEL_ID);
        } else {
            builder = new Notification.Builder(this);
        }

        builder.setSmallIcon(icon)
            .setContentTitle(title)
            .setContentText(contentText)
            .setSubText(subTitle)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setCategory(Notification.CATEGORY_SERVICE);

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
