import 'package:flutter/material.dart';

/// Cash-control session sign-in (opened from Profile & Settings).
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _isSignedIn = false;
  bool _isLoading = false;

  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _signInGreen = Color(0xFF22C55E);
  static const Color _printBg = Color(0xFFE8E8ED);
  static const Color _printText = Color(0xFF8E8E93);

  Future<void> _performSignIn() async {
    if (_isSignedIn || _isLoading) return;
    setState(() => _isLoading = true);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _isSignedIn = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session signed in successfully'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _printSignIn() {
    if (!_isSignedIn) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Print sign in — coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: _textDark,
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          'Sign in',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: _textDark,
            letterSpacing: -0.2,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE5E5EA)),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              GestureDetector(
                onTap: _isLoading ? null : _performSignIn,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  children: [
                    const _BadgeIllustration(),
                    const SizedBox(height: 28),
                    const Text(
                      'Tap to sign in to your session',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: _textDark,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isSignedIn || _isLoading) ? null : _performSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _signInGreen,
                    disabledBackgroundColor: _signInGreen.withValues(alpha: 0.5),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isSignedIn ? 'Signed in' : 'Sign in',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSignedIn ? _printSignIn : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _printBg,
                    disabledBackgroundColor: _printBg,
                    foregroundColor: _printText,
                    disabledForegroundColor: _printText,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Print sign in',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// ID badge outline illustration matching the design mockup.
class _BadgeIllustration extends StatelessWidget {
  const _BadgeIllustration();

  static const Color _outline = Color(0xFF7EB8DA);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(120, 88),
      painter: _BadgePainter(),
    );
  }
}

class _BadgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const color = _BadgeIllustration._outline;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 8, size.width - 8, size.height - 16),
      const Radius.circular(10),
    );
    canvas.drawRRect(r, fill);
    canvas.drawRRect(r, stroke);

    // Clip hole (top-left of badge)
    final clipCenter = Offset(36, 22);
    canvas.drawCircle(clipCenter, 7, stroke);

    // Avatar circle
    canvas.drawCircle(const Offset(36, 48), 16, stroke);
    canvas.drawCircle(const Offset(36, 44), 7, stroke);

    // Text lines on the right
    final linePaint = stroke..strokeWidth = 2;
    const startX = 62.0;
    for (var i = 0; i < 3; i++) {
      final y = 36.0 + i * 14.0;
      final w = i == 0 ? 42.0 : (i == 1 ? 36.0 : 28.0);
      canvas.drawLine(Offset(startX, y), Offset(startX + w, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
