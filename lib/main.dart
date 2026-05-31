import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'api/seedr_api.dart';
import 'utils/storage.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized(); 
  final api = await SeedrApi.create();
  final (email, password) = await Storage.getCreds();

  bool loggedIn = false;
  if (email != null && password != null) {
    try {
      await api.login(email, password);
      loggedIn = true;
    } catch (_) {}
  }

  runApp(SeedrApp(api: api, startLoggedIn: loggedIn));
}

class SeedrApp extends StatelessWidget {
  final SeedrApi api;
  final bool startLoggedIn;

  const SeedrApp({super.key, required this.api, required this.startLoggedIn});

  @override
  Widget build(BuildContext context) {
    return NeumorphicApp(
      debugShowCheckedModeBanner: false,
      title: 'Magnetro',
      navigatorKey: Get.key,                   // ← GetX navigator key
      themeMode: ThemeMode.dark,
      darkTheme: NeumorphicThemeData(
        baseColor: const Color(0xFF1E1E2C),
        accentColor: const Color(0xFF7B61FF),
        variantColor: const Color(0xFF3D3B8E),
        lightSource: LightSource.topLeft,
        depth: 6,
        intensity: 0.5,
        shadowDarkColor: const Color(0xFF12121C),
        shadowLightColor: const Color(0xFF2A2A3C),
      ),
      home: startLoggedIn
          ? HomeScreen(api: api)
          : LoginScreen(api: api),
    );
  }
}