import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/main_navigation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _logoFade;
  late Animation<Offset> _logoSlide;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _taglineFade;
  late Animation<Offset> _taglineSlide;
  bool _didPrecacheImages = false;

  late AnimationController _shaderAnimController;
  ui.FragmentShader? _fragmentShader;
  double _shaderTime = 0.0;
  DateTime? _startTime;
  DateTime? _lastTick;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();

    // 1. Staggered Entrance Animations (replicating Stitch CSS fade-in-up choreography)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Logo Card: Starts at 0ms, duration 800ms
    final logoCurve = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.67, curve: Curves.easeOutCubic),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(logoCurve);
    _logoSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.25),
      end: Offset.zero,
    ).animate(logoCurve);

    // Title ("KASH"): Starts at 100ms, duration 800ms
    final titleCurve = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.08, 0.75, curve: Curves.easeOutCubic),
    );
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(titleCurve);
    _titleSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.25),
      end: Offset.zero,
    ).animate(titleCurve);

    // Tagline: Starts at 300ms, duration 800ms
    final taglineCurve = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.25, 0.92, curve: Curves.easeOutCubic),
    );
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(taglineCurve);
    _taglineSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.25),
      end: Offset.zero,
    ).animate(taglineCurve);

    _entranceController.forward();

    // 2. Load GLSL Fragment Shader asynchronously
    _loadShader();

    // 3. Pre-warm and cache Lottie animations in background
    _precacheLottieAnimations();

    // 4. 60fps continuous shader ticker with Stitch initial speed burst
    _startTime = DateTime.now();
    _lastTick = _startTime;
    _shaderAnimController =
        AnimationController(
          vsync: this,
          duration: const Duration(seconds: 1),
        )..addListener(() {
          final now = DateTime.now();
          final elapsedMs = now.difference(_startTime!).inMilliseconds;
          final delta = _lastTick != null
              ? (now.difference(_lastTick!).inMicroseconds / 1000000.0)
              : 0.016;
          _lastTick = now;

          // 6.0x initial speed burst during the first 1000ms, settling into 1.0x ambient flow
          const fastBurstDurationMs = 1000;
          final speed = elapsedMs < fastBurstDurationMs ? 6.0 : 1.0;
          _shaderTime += delta * speed;
        });
    _shaderAnimController.repeat();

    // 5. Smooth Transition to MainNavigation
    _navTimer = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const MainNavigation(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didPrecacheImages) {
      _didPrecacheImages = true;
      _precacheImages();
    }
  }

  void _precacheImages() {
    precacheImage(
      const AssetImage('assets/images/kash_spark_logo_corrected.png'),
      context,
    );
    precacheImage(const AssetImage('assets/images/kash_logo.png'), context);
    precacheImage(const AssetImage('assets/images/d_prof.jpg'), context);
  }

  void _precacheLottieAnimations() {
    const animations = [
      'assets/animations/laughing_cat.json',
      'assets/animations/sad_no_result.json',
      'assets/animations/not_found.json',
      'assets/animations/no_results.json',
    ];
    for (final anim in animations) {
      AssetLottie(anim).load().then<void>((_) {}, onError: (error) {
        debugPrint('Precache animation $anim note: $error');
      });
    }
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/splash.frag');
      if (mounted) {
        setState(() {
          _fragmentShader = program.fragmentShader();
        });
      }
    } catch (e) {
      debugPrint(
        'Fragment shader runtime notice: $e (using high-fidelity procedural fallback)',
      );
    }
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _shaderAnimController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      body: Stack(
        children: [
          // Animated Stitch Shader Flowing Background (repainted on every frame)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _shaderAnimController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _ShaderBackgroundPainter(
                    shader: _fragmentShader,
                    time: _shaderTime,
                    isDark: isDark,
                  ),
                );
              },
            ),
          ),

          // Main Splash Content with Stitch Layout & Staggered Animations
          SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),

                  // 1. Elevated Spark Logo Card
                  SlideTransition(
                    position: _logoSlide,
                    child: FadeTransition(
                      opacity: _logoFade,
                      child: Container(
                        width: 184,
                        height: 184,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF4F46E5,
                              ).withValues(alpha: 0.18),
                              blurRadius: 44,
                              spreadRadius: 8,
                              offset: const Offset(0, 14),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 16,
                              spreadRadius: 0,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Image.asset(
                          'assets/images/kash_spark_logo_corrected.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. Wordmark ("KASH")
                  SlideTransition(
                    position: _titleSlide,
                    child: FadeTransition(
                      opacity: _titleFade,
                      child: Text(
                        'KASH',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 46,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: isDark
                              ? const Color(0xFFC3C0FF)
                              : const Color(0xFF3525CD),
                        ),
                      ),
                    ),
                  ),

                  const Spacer(flex: 3),

                  // 3. Tagline ("PERSONAL FINANCE SIMPLIFIED")
                  SlideTransition(
                    position: _taglineSlide,
                    child: FadeTransition(
                      opacity: _taglineFade,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: 32.0,
                          left: 16.0,
                          right: 16.0,
                        ),
                        child: Text(
                          'PERSONAL FINANCE SIMPLIFIED',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.5,
                            color: isDark
                                ? Colors.white60
                                : const Color(
                                    0xFF464555,
                                  ).withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter that renders the GLSL FragmentShader when loaded,
/// or falls back to an exact procedural sine/noise mathematical simulation
/// matching the Stitch shader equation.
class _ShaderBackgroundPainter extends CustomPainter {
  final ui.FragmentShader? shader;
  final double time;
  final bool isDark;

  _ShaderBackgroundPainter({
    required this.shader,
    required this.time,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    if (shader != null) {
      // Uniform 0: u_resolution.x
      // Uniform 1: u_resolution.y
      // Uniform 2: u_time
      // Uniform 3: u_is_dark
      shader!.setFloat(0, size.width);
      shader!.setFloat(1, size.height);
      shader!.setFloat(2, time);
      shader!.setFloat(3, isDark ? 1.0 : 0.0);

      final paint = Paint()..shader = shader;
      canvas.drawRect(rect, paint);
      return;
    }

    // High-fidelity procedural fallback implementing the exact Stitch GLSL equation
    // with vibrant, clearly visible flowing wave motion:
    final wave1X = math.sin(time * 0.8) * 0.40;
    final wave1Y = math.cos(time * 0.6) * 0.35;
    final wave2X = math.cos(time * 1.0) * 0.30;
    final wave2Y = math.sin(time * 0.9) * 0.30;

    // 1. Base ambient fill
    final baseColor = isDark
        ? const Color(0xFF0F0D26)
        : const Color(0xFFF5F6FC);
    canvas.drawRect(rect, Paint()..color = baseColor);

    // 2. Primary pastel lavender/periwinkle flowing wave (from splash_bg)
    final waveColor1 = isDark
        ? const Color(0xFF241E61).withValues(alpha: 0.80)
        : const Color(0xFFC3CAF9).withValues(alpha: 0.90);

    final p1 = Paint()
      ..shader = RadialGradient(
        center: Alignment(-0.4 + wave1X, -0.45 + wave1Y),
        radius: 1.35,
        colors: [
          waveColor1,
          waveColor1.withValues(alpha: 0.45),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, p1);

    // 3. Secondary flowing indigo brand crest wave
    final waveColor2 = isDark
        ? const Color(0xFF665CF5).withValues(alpha: 0.50)
        : const Color(0xFF4F46E5).withValues(alpha: 0.38);

    final p2 = Paint()
      ..shader = RadialGradient(
        center: Alignment(0.45 + wave2X, 0.45 + wave2Y),
        radius: 1.20,
        colors: [
          waveColor2,
          waveColor2.withValues(alpha: 0.20),
          Colors.transparent,
        ],
        stops: const [0.0, 0.58, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, p2);

    // 4. Center radiant aura behind the logo card
    final centerGlow = isDark
        ? const Color(0xFF665CF5).withValues(alpha: 0.30)
        : const Color(0xFF818CF8).withValues(alpha: 0.25);

    final pCenter = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.15),
        radius: 0.85,
        colors: [centerGlow, Colors.transparent],
        stops: const [0.0, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, pCenter);
  }

  @override
  bool shouldRepaint(covariant _ShaderBackgroundPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.shader != shader ||
        oldDelegate.isDark != isDark;
  }
}
