import 'package:flutter/material.dart';
import 'dart:async';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:app_fitness/view/on_boarding/started_view.dart';
import 'package:app_fitness/view/on_boarding/on_boarding_view.dart';
import 'package:app_fitness/view/login/complete_profile_view.dart';
import 'package:app_fitness/view/login/what_your_goal_view.dart';
import 'package:app_fitness/view/login/welcome_view.dart';
import 'package:app_fitness/view/main_tab/main_tab_view.dart';
import 'package:flutter/services.dart';
import 'common/color_extension.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown, // optional, allows upside-down portrait
  ]);

  // Capture framework errors (will help diagnose release black screen)
  FlutterError.onError = (FlutterErrorDetails details) {
    // ignore: avoid_print
    print('[FlutterError] ${details.exceptionAsString()}');
    FlutterError.dumpErrorToConsole(details);
  };

  await runZonedGuarded<Future<void>>(
    () async {
      try {
        // Initialize Awesome Notifications with the 'basic_channel'
        await AwesomeNotifications().initialize(
          // Provide a proper notification icon (add ic_stat_notify to drawable). Null may cause issues on some OEMs in release.
          'resource://drawable/ic_stat_notify',
          [
            NotificationChannel(
              channelGroupKey: 'basic_channel_group',
              channelKey: 'basic_channel',
              channelName: 'Basic Notifications',
              channelDescription: 'General notifications',
              defaultColor: const Color(0xFF9D50DD),
              ledColor: const Color(0xFFFFFFFF),
              importance: NotificationImportance.High,
              channelShowBadge: true,
              enableVibration: true,
              enableLights: true,
              playSound: true,
              soundSource: 'resource://raw/fitness',
            ),
          ],
          channelGroups: [
            NotificationChannelGroup(
              channelGroupKey: 'basic_channel_group',
              channelGroupName: 'Basic Group',
            ),
          ],
          debug: false,
        );

        // Ask permission once at startup (safe guard)
        bool allowed = await AwesomeNotifications().isNotificationAllowed();
        if (!allowed) {
          await AwesomeNotifications().requestPermissionToSendNotifications();
        }
      } catch (e, st) {
        // ignore: avoid_print
        print('[InitError] $e\n$st');
      }

      runApp(const MyApp());
    },
    (error, stack) {
      // ignore: avoid_print
      print('[ZoneError] $error\n$stack');
    },
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _onboardingComplete = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
      _loading = false;
    });
  }

  Future<void> _setOnboardingComplete() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    setState(() {
      _onboardingComplete = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fitness 3 in 1',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: TColor.primaryColor1,
        fontFamily: "Poppins",
      ),
      home: _loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : (_onboardingComplete
                ? const MainTabView()
                : _OnboardingFlow(onComplete: _setOnboardingComplete)),
    );
  }
}

class _OnboardingFlow extends StatefulWidget {
  final VoidCallback onComplete;
  const _OnboardingFlow({required this.onComplete});

  @override
  State<_OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<_OnboardingFlow> {
  int _step = 0;

  void _nextStep() {
    setState(() {
      _step++;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case 0:
        return StartedView(
          key: const ValueKey('StartedView'),
          onNext: _nextStep,
        );
      case 1:
        return OnBoardingView(
          key: const ValueKey('OnBoardingView'),
          onNext: _nextStep,
        );
      case 2:
        return CompleteProfileView(
          key: const ValueKey('CompleteProfileView'),
          onNext: _nextStep,
        );
      case 3:
        return WhatYourGoalView(
          key: const ValueKey('WhatYourGoalView'),
          onNext: _nextStep,
        );
      case 4:
        return WelcomeView(
          key: const ValueKey('WelcomeView'),
          onNext: () {
            widget.onComplete();
          },
        );
      default:
        return const MainTabView();
    }
  }
}
