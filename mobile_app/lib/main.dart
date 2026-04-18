import 'package:flutter/material.dart';
import 'config/api_config.dart';
import 'screens/agent/agent_home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/user/available_agents/available_agents_screen.dart';
import 'screens/user/transactions/my_requests_screen.dart';
import 'services/available_agents_context_store.dart';
import 'services/local_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalNotificationService.instance.init();
  final baseUrl = ApiConfig.baseUrl;
  print('API URL: $baseUrl');
  runApp(const MyApp());
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    LocalNotificationService.instance.onNotificationTap.listen((payload) {
      _handleNotificationPayload(payload);
    });
  }

  void _handleNotificationPayload(String? payload) async {
    if (payload == null || payload.isEmpty) return;
    if (payload.startsWith('user_request:')) {
      final requestId = payload.replaceFirst('user_request:', '').trim();
      if (requestId.isEmpty) return;
      _rootNavigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => MyRequestsScreen(initialRequestId: requestId),
        ),
      );
      return;
    }

    if (payload.startsWith('user_approved:')) {
      final contextArgs = await AvailableAgentsContextStore.load();
      _rootNavigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => AvailableAgentsScreen(
            city: contextArgs?.city.isNotEmpty == true ? contextArgs!.city : 'your area',
            latitude: contextArgs?.latitude,
            longitude: contextArgs?.longitude,
            radiusKm: contextArgs?.radiusKm ?? 10.0,
            transactionType: contextArgs?.transactionType ?? 'UPI → Cash',
            amount: contextArgs?.amount ?? '1000',
          ),
        ),
      );
      return;
    }

    if (payload == 'open_live_requests') {
      _rootNavigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => const AgentHomeScreen(openLiveRequestsOnLoad: true),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _rootNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Cash Platform',
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final clampedTextScale = mediaQuery.textScaleFactor.clamp(0.95, 1.10);
        return MediaQuery(
          data: mediaQuery.copyWith(textScaleFactor: clampedTextScale),
          child: child ?? const SizedBox.shrink(),
        );
      },
      theme: ThemeData(
        primarySwatch: Colors.green,
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const AppStartScreen(),
    );
  }
}

class AppStartScreen extends StatefulWidget {
  const AppStartScreen({super.key});

  @override
  State<AppStartScreen> createState() => _AppStartScreenState();
}

class _AppStartScreenState extends State<AppStartScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F2FF),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset(
                  'Cashio/unnamed.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 80,
                    color: Colors.green,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Cash IO',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

