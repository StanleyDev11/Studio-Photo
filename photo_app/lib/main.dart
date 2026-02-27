import 'package:Picon/api_service.dart';
import 'package:Picon/home_screen.dart';
import 'package:Picon/login_screen.dart';
import 'package:Picon/signup_screen.dart';
import 'package:Picon/utils/colors.dart';
import 'package:Picon/utils/police.dart';
import 'package:flutter/material.dart';


import 'package:app_links/app_links.dart';
import 'package:Picon/receipt_screen.dart'; // Import ReceiptScreen
import 'package:Picon/payment_pending_screen.dart';
import 'package:Picon/payment_success_screen.dart';
import 'package:device_preview/device_preview.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();
  runApp(
    DevicePreview(
      enabled: true,
      builder: (context) => const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();

    // Check initial link if app was closed
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });

    // Listen to link stream
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  Future<void> _handleDeepLink(Uri uri) async {
    if (uri.scheme == 'picon' && uri.host == 'payment-callback') {
      final status = uri.queryParameters['status'];
      final transactionId =
          uri.queryParameters['id'] ?? uri.queryParameters['transaction_id'];
      final orderIdParam = uri.queryParameters['orderId'];

      if (status == 'cancel') {
        ApiService.clearPendingPayment();
        if (_navigatorKey.currentContext != null) {
          ScaffoldMessenger.of(_navigatorKey.currentContext!).showSnackBar(
            const SnackBar(
                content: Text("Paiement annulé."),
                backgroundColor: Colors.red),
          );
        }
        return;
      }

      if (transactionId == null || transactionId.isEmpty) {
        if (orderIdParam != null && orderIdParam.isNotEmpty) {
          final order = await ApiService.fetchOrderById(orderIdParam);
          if (order != null && order.status == 'PROCESSING') {
            if (ApiService.pendingOrderDetails != null &&
                ApiService.pendingPrices != null &&
                ApiService.pendingPaymentMethod != null) {
              _navigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (context) =>
                      PaymentSuccessScreen(orderId: orderIdParam),
                ),
              );
            }
            ApiService.clearPendingPayment();
            return;
          }
        }
        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => PaymentPendingScreen(
              transactionId: null,
              orderId: orderIdParam,
            ),
          ),
        );
        return;
      }

      try {
        final verify = await ApiService.verifyFedapayTransaction(transactionId);
        final verifiedStatus = (verify['status'] ?? '').toString();
        final orderId = (verify['orderId'] ??
                orderIdParam ??
                ApiService.pendingOrderId ??
                '')
            .toString();

        if (verifiedStatus == 'approved') {
          if (ApiService.pendingOrderDetails != null &&
              ApiService.pendingPrices != null &&
              ApiService.pendingPaymentMethod != null) {
            _navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (context) => PaymentSuccessScreen(orderId: orderId),
              ),
            );
          } else {
            if (_navigatorKey.currentContext != null) {
              ScaffoldMessenger.of(_navigatorKey.currentContext!).showSnackBar(
                const SnackBar(
                    content: Text(
                        "Paiement confirmé. Consultez Mes commandes.")),
              );
            }
          }
          ApiService.clearPendingPayment();
        } else if (verifiedStatus == 'pending') {
          _navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => PaymentPendingScreen(
                transactionId: transactionId,
                orderId: orderId,
              ),
            ),
          );
        } else {
          ApiService.clearPendingPayment();
          if (_navigatorKey.currentContext != null) {
            ScaffoldMessenger.of(_navigatorKey.currentContext!).showSnackBar(
              const SnackBar(
                  content: Text("Paiement échoué ou annulé."),
                  backgroundColor: Colors.red),
            );
          }
        }
      } catch (e) {
        if (_navigatorKey.currentContext != null) {
          ScaffoldMessenger.of(_navigatorKey.currentContext!).showSnackBar(
            SnackBar(
                content: Text("Erreur de vérification: $e"),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      navigatorKey: _navigatorKey, // Add navigator key
      title: 'Photo App',
      theme: ThemeData(
        primarySwatch: MaterialColor(AppColors.primary.value, const <int, Color>{
          50: Color(0xFFE8EAF6),
          100: Color(0xFFC5CAE9),
          200: Color(0xFF9FA8DA),
          300: Color(0xFF7986CB),
          400: Color(0xFF5C6BC0),
          500: AppColors.primary,
          600: Color(0xFF3F51B5),
          700: Color(0xFF303F9F),
          800: Color(0xFF283593),
          900: Color(0xFF1A237E),
        }),
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        scaffoldBackgroundColor: AppColors.background,
        textTheme: buildPoppinsTextTheme(ThemeData.light().textTheme),
        fontFamily: primaryFont.fontFamily,
      ),
      debugShowCheckedModeBanner: false,
      home: _getInitialScreen(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (context) => const LoginScreen());
          case '/signup':
             return MaterialPageRoute(builder: (context) => const SignupScreen());
          case '/home':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => HomeScreen(
                userName: args?['userName'] as String? ?? 'Utilisateur',
                userLastName: args?['userLastName'] as String? ?? '',
                userEmail: args?['userEmail'] as String? ?? '',
                userId: args?['userId'] as int? ?? 0,
              ),
            );
          default:
            return MaterialPageRoute(builder: (context) => const LoginScreen());
        }
      },
    );
  }

  Widget _getInitialScreen() {
    if (ApiService.authToken != null && ApiService.userId != null) {
      return HomeScreen(
        userName: ApiService.userName ?? 'Utilisateur',
        userLastName: ApiService.userLastName ?? '',
        userEmail: ApiService.userEmail ?? '',
        userId: ApiService.userId!,
      );
    }
    return const LoginScreen();
  }
}
