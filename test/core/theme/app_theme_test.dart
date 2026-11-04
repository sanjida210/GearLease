import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/theme/app_colors.dart';
import 'package:gearlease/core/theme/app_theme.dart';

void main() {
  group('AppColors Tests', () {
    test('defines required industrial FinTech color palette', () {
      expect(AppColors.scaffoldBackground, const Color(0xFF090D14));
      expect(AppColors.surfaceCard, const Color(0xFF121927));
      expect(AppColors.surfaceCardElevated, const Color(0xFF1E293B));
      expect(AppColors.precisionCyan, const Color(0xFF0D9488));
      expect(AppColors.cyanAccent, const Color(0xFF14B8A6));
      expect(AppColors.industrialAmber, const Color(0xFFF59E0B));
      expect(AppColors.performanceGreen, const Color(0xFF10B981));
      expect(AppColors.criticalRed, const Color(0xFFEF4444));
      expect(AppColors.neutralBorder, const Color(0xFF334155));
      expect(AppColors.ledgerWhite, const Color(0xFFF8FAFC));
      expect(AppColors.ledgerMuted, const Color(0xFF94A3B8));
    });
  });

  group('AppTheme Tests', () {
    testWidgets('darkTheme configures correct surface colors and brightness', (tester) async {
      final theme = AppTheme.darkTheme;

      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, AppColors.scaffoldBackground);
      expect(theme.colorScheme.surface, AppColors.surfaceCard);
      expect(theme.colorScheme.primary, AppColors.precisionCyan);
      expect(theme.colorScheme.error, AppColors.criticalRed);
    });

    testWidgets('darkTheme configures Space Grotesk and Inter fonts across text categories', (tester) async {
      final theme = AppTheme.darkTheme;
      final textTheme = theme.textTheme;

      // Headlines, displays, titles should use Space Grotesk
      expect(textTheme.displayLarge?.fontFamily, contains('SpaceGrotesk'));
      expect(textTheme.displayMedium?.fontFamily, contains('SpaceGrotesk'));
      expect(textTheme.headlineMedium?.fontFamily, contains('SpaceGrotesk'));
      expect(textTheme.titleLarge?.fontFamily, contains('SpaceGrotesk'));

      // Body, labels, captions should use Inter
      expect(textTheme.bodyLarge?.fontFamily, contains('Inter'));
      expect(textTheme.bodyMedium?.fontFamily, contains('Inter'));
      expect(textTheme.bodySmall?.fontFamily, contains('Inter'));
      expect(textTheme.labelMedium?.fontFamily, contains('Inter'));
    });

    testWidgets('darkTheme configures ElevatedButton and OutlinedButton with 8px radius', (tester) async {
      final theme = AppTheme.darkTheme;

      // Elevated Button
      final elevatedStyle = theme.elevatedButtonTheme.style;
      expect(elevatedStyle, isNotNull);
      final elevatedShape = elevatedStyle!.shape?.resolve({}) as RoundedRectangleBorder?;
      expect(elevatedShape?.borderRadius, BorderRadius.circular(8));

      // Outlined Button
      final outlinedStyle = theme.outlinedButtonTheme.style;
      expect(outlinedStyle, isNotNull);
      final outlinedShape = outlinedStyle!.shape?.resolve({}) as RoundedRectangleBorder?;
      expect(outlinedShape?.borderRadius, BorderRadius.circular(8));
    });

    testWidgets('darkTheme configures SnackBar, Dialog, and BottomNavigation themes for surfaceCard', (tester) async {
      final theme = AppTheme.darkTheme;

      // SnackBar
      expect(theme.snackBarTheme.backgroundColor, AppColors.surfaceCard);
      expect(theme.snackBarTheme.shape, isA<RoundedRectangleBorder>());

      // Dialog
      expect(theme.dialogTheme.backgroundColor, AppColors.surfaceCard);
      expect(theme.dialogTheme.shape, isA<RoundedRectangleBorder>());

      // Bottom Navigation Bar
      expect(theme.bottomNavigationBarTheme.backgroundColor, AppColors.surfaceCard);
      expect(theme.bottomNavigationBarTheme.selectedItemColor, AppColors.cyanAccent);
    });
  });
}
