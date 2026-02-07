import 'package:Picon/api_service.dart';
import 'package:Picon/home_screen.dart';
import 'package:Picon/login_screen.dart';
import 'package:Picon/signup_screen.dart';
import 'package:Picon/splash_screen.dart';
import 'package:Picon/utils/colors.dart';
import 'package:Picon/utils/police.dart';
import 'package:flutter/material.dart';


import 'package:app_links/app_links.dart';
import 'package:Picon/receipt_screen.dart'; // Import ReceiptScreen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();
  runApp(const MyApp());
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
    // _appLinks.getInitialLink().then((uri) { // getInitialLink returns Future<Uri?>
    //   if (uri != null) _handleDeepLink(uri);
    // });

    // Listen to link stream
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme == 'picon' && uri.host == 'payment-callback') {
      final status = uri.queryParameters['status'];
      if (status == 'success') {
         // Navigate to ReceiptScreen
         // Note: In a real app we would fetch order details from backend using an orderID passed in params
         // Here we show a generic success for demonstration
         _navigatorKey.currentState?.push(
           MaterialPageRoute(
             builder: (context) => ReceiptScreen(
               orderDetails: {}, // Empty for demo check 
               paymentMethod: "PayDunya",
               orderId: "CMD-${DateTime.now().millisecondsSinceEpoch}", 
               prices: {},
               userName: ApiService.userName ?? "Client",
               userPhone: ApiService.userEmail ?? "",
             )
           )
         );
      } else if (status == 'cancel') {
         // Show error or just stay
         ScaffoldMessenger.of(_navigatorKey.currentContext!).showSnackBar(
           const SnackBar(content: Text("Paiement annulé."), backgroundColor: Colors.red),
         );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      initialRoute: '/splash',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/splash':
            return MaterialPageRoute(builder: (context) => const SplashScreen());
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
}
