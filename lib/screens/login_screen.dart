import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../api/seedr_api.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  final SeedrApi api;
  const LoginScreen({super.key, required this.api});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  // ─── Palette (mirrors HomeScreen) ─────────────────────────────────────────
  static const _bgTop = Color.fromARGB(255, 38, 38, 38);
  static const _bgMid = Color.fromARGB(255, 32, 32, 32);
  static const _bgBottom = Color.fromARGB(255, 18, 18, 18);
  static const _accent = Color.fromARGB(255, 169, 23, 67);
  static const _textColor = Color(0xFFE0E0E0);

  static const _btnStyle = NeumorphicStyle(
    depth: 4,
    shape: NeumorphicShape.convex,
    intensity: 0.9,
    surfaceIntensity: 0.2,
    color: Color(0xFF121212),
    lightSource: LightSource.topLeft,
    shadowLightColor: Colors.white10,
    shadowDarkColor: Colors.black87,
  );

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.api.login(_emailCtrl.text.trim(), _passCtrl.text.trim());
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(api: widget.api)),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Background gradient ──────────────────────────────────────────
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_bgTop, _bgMid, _bgBottom],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Logo ───────────────────────────────────────────────
                    Center(
                      child: SizedBox(
                        width: 82,
                        height: 82,
                        child: Center(
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Title ──────────────────────────────────────────────
                    const Center(
                      child: Text(
                        'MAGNETRO',
                        style: TextStyle(
                          color: _textColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                          fontFamily: 'UberMove',
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Center(
                      child: Text(
                        'Sign in with your Seedr.cc account',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontFamily: 'UberMove',
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),

                    // ── Email label ────────────────────────────────────────
                    const Text(
                      'EMAIL',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        fontFamily: 'UberMove',
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── Email field ────────────────────────────────────────
                    Neumorphic(
                      style: NeumorphicStyle(
                        depth: 6,
                        intensity: 0.9,
                        color: const Color(0xFF0E0E0E),
                        lightSource: LightSource.topLeft,
                        shadowLightColor: Colors.white12,
                        shadowDarkColor: Colors.black87,
                        boxShape: NeumorphicBoxShape.roundRect(
                          BorderRadius.circular(12),
                        ),
                      ),
                      child: TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(
                          color: _textColor,
                          fontSize: 15,
                          fontFamily: 'UberMove',
                          fontWeight: FontWeight(500),
                        ),
                        decoration: const InputDecoration(
                          hintText: 'you@example.com',
                          hintStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 15,
                            fontFamily: 'UberMove',
                            fontWeight: FontWeight(500),
                          ),
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: Colors.grey,
                            size: 18,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Password label ─────────────────────────────────────
                    const Text(
                      'PASSWORD',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        fontFamily: 'UberMove',
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── Password field ─────────────────────────────────────
                    Neumorphic(
                      style: NeumorphicStyle(
                        depth: 6,
                        intensity: 0.9,
                        color: const Color(0xFF0E0E0E),
                        lightSource: LightSource.topLeft,
                        shadowLightColor: Colors.white12,
                        shadowDarkColor: Colors.black87,
                        boxShape: NeumorphicBoxShape.roundRect(
                          BorderRadius.circular(12),
                        ),
                      ),
                      child: TextField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        style: const TextStyle(
                          color: _textColor,
                          fontSize: 15,
                          fontFamily: 'UberMove',
                          fontWeight: FontWeight(500),
                        ),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          hintStyle: const TextStyle(
                            color: Colors.grey,
                            fontSize: 15,
                            fontFamily: 'UberMove',
                            fontWeight: FontWeight(500),
                          ),
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: Colors.grey,
                            size: 18,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey,
                              size: 18,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),

                    // ── Error ──────────────────────────────────────────────
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Neumorphic(
                        style: NeumorphicStyle(
                          depth: 6,
                          intensity: 0.8,
                          color: const Color(0xFF1A0A0A),
                          lightSource: LightSource.topLeft,
                          shadowLightColor: Colors.white10,
                          shadowDarkColor: Colors.black87,
                          boxShape: NeumorphicBoxShape.roundRect(
                            BorderRadius.circular(10),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: Color(0xFFEF5350),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Color(0xFFEF5350),
                                    fontSize: 12,
                                    fontFamily: 'UberMove',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // ── Sign In button ─────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: NeumorphicButton(
                        onPressed: _loading ? null : _login,
                        minDistance: 3,
                        style: _btnStyle.copyWith(
                          color: _accent,
                          boxShape: NeumorphicBoxShape.roundRect(
                            BorderRadius.circular(12),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Center(
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Sign In',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    fontFamily: 'UberMove',
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
