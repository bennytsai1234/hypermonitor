import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:window_manager/window_manager.dart';
import 'ui/dashboard_screen.dart';
import 'ui/mobile_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop: window setup
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.linux)) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 720),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: "Hyperliquid Monitor",
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // Android: Initialize foreground task for background persistence
  if (defaultTargetPlatform == TargetPlatform.android) {
    FlutterForegroundTask.initCommunicationPort();
    _initForegroundTask();
  }

  runApp(const MyApp());
}

/// Configure the foreground service notification
void _initForegroundTask() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'hyper_monitor_service',
      channelName: '超級印鈔機 背景服務',
      channelDescription: '持續監控 Hyperliquid 數據',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    iosNotificationOptions: const IOSNotificationOptions(),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(10000), // 10 seconds
      autoRunOnBoot: true,     // Auto-start after phone reboot
      autoRunOnMyPackageReplaced: true, // Auto-start after app update
      allowWakeLock: true,     // Prevent CPU from sleeping
      allowWifiLock: true,     // Keep WiFi active
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    bool isMobile = defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

    return MaterialApp(
      title: 'Hyperliquid 實時監控',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: isMobile ? const MobileDashboardScreen() : const DashboardScreen(),
    );
  }
}
