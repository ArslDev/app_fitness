import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class testNotification extends StatefulWidget {
  const testNotification({super.key});

  @override
  State<testNotification> createState() => _testNotificationState();
}

class _testNotificationState extends State<testNotification> {
  static const String _switchPrefKey = 'notification_switch_on';
  bool _switchOn = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Initialize Awesome Notifications channel if not already done
    AwesomeNotifications().initialize(null, [
      NotificationChannel(
        channelKey: 'alerts',
        channelName: 'Alerts',
        channelDescription: 'Notification tests as alerts',
        playSound: true,
        importance: NotificationImportance.High,
        defaultPrivacy: NotificationPrivacy.Private,
        defaultColor: Colors.deepPurple,
        ledColor: Colors.deepPurple,
        soundSource: 'resource://raw/fitness'
      ),
    ], debug: true);

    // Initialize time zones
    tz.initializeTimeZones();

    // Load persisted switch state
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_switchPrefKey) ?? false;

    if (mounted) {
      setState(() {
        _switchOn = saved;
        _loading = false;
      });
    }

    // If it was ON previously you may choose to schedule again (optional).
    // Uncomment below if you want to re-schedule when coming back and it was ON.
    // if (_switchOn) {
    //   _scheduleNotification();
    // }
  }

  Future<void> _persistSwitch(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_switchPrefKey, value);
  }

  Future<void> _scheduleNotification() async {
    final permissionStatus = await Permission.notification.request();
    if (!permissionStatus.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification permission denied')),
        );
      }
      return;
    }

    final now = tz.TZDateTime.now(tz.local);
    final scheduledDate = now.add(const Duration(seconds: 5));

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        channelKey: 'alerts',
        title: 'Test Notification',
        body: 'This is a test notification using Awesome Notifications!',
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar(
        year: scheduledDate.year,
        month: scheduledDate.month,
        day: scheduledDate.day,
        hour: scheduledDate.hour,
        minute: scheduledDate.minute,
        second: scheduledDate.second,
        timeZone: tz.local.name,
        repeats: false,
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification scheduled in 20 seconds')),
      );
    }
  }

  Future<void> _cancelScheduled() async {
    // Cancel all scheduled (and optionally displayed) notifications for this channel
    await AwesomeNotifications().cancelNotificationsByChannelKey('alerts');
    // Or to cancel everything: await AwesomeNotifications().cancelAll();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Notifications cancelled')));
    }
  }

  Future<void> _onSwitchChanged(bool value) async {
    setState(() {
      _switchOn = value;
    });
    await _persistSwitch(value);

    if (value) {
      // Turned ON: schedule a notification
      await _scheduleNotification();
    } else {
      // Turned OFF: cancel any scheduled notifications
      await _cancelScheduled();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Notification')),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Notifications'),
                  const SizedBox(width: 12),
                  Switch(value: _switchOn, onChanged: _onSwitchChanged),
                ],
              ),
      ),
    );
  }
}
