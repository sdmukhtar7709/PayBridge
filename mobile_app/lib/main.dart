import 'package:flutter/material.dart';
import 'screens/agent/agent_home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/user/available_agents_screen.dart';
import 'screens/user/my_requests_screen.dart';
import 'services/available_agents_context_store.dart';
import 'services/local_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalNotificationService.instance.init();
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
            radiusKm: contextArgs?.radiusKm ?? 5.0,
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
      theme: ThemeData(primarySwatch: Colors.green),
      home: const LoginScreen(),
    );
  }
}

