import 'package:flutter/material.dart';

/// Dev splash screen that matches the branding from your SS.
///
class BrandSplash extends StatelessWidget {
  const BrandSplash({super.key, this.secondsLeft});

  final int? secondsLeft;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF5BAA3C);

    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final effectiveH = constraints.maxHeight > 0
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height;
          final logoTop = effectiveH * 0.20;
          final spinnerTop = effectiveH * 0.67;

          return Stack(
            children: [
              Positioned(
                top: logoTop,
                left: 0,
                right: 0,
                child: Center(
                  child: Image.asset(
                    'assets/convobridge_logo.png',
                    width: 340,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox(width: 340, height: 240);
                    },
                  ),
                ),
              ),
              Positioned(
                top: spinnerTop,
                left: 0,
                right: 0,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 70,
                        height: 70,
                        child: CircularProgressIndicator(
                          strokeWidth: 6,
                          valueColor: const AlwaysStoppedAnimation<Color>(green),
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                      if (secondsLeft != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${secondsLeft!}s',
                          style: TextStyle(
                            color: green,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

