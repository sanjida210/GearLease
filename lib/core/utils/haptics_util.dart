import 'package:flutter/services.dart';

class HapticsUtil {
  HapticsUtil._();

  /// Triggered on barcode or QR code recognition
  static Future<void> barcodeCaptured() async {
    await HapticFeedback.mediumImpact();
  }

  /// Triggered on lease approval and contract signing
  static Future<void> leaseApproved() async {
    await HapticFeedback.heavyImpact();
  }

  /// Triggered on financial slider increments
  static Future<void> sliderChanged() async {
    await HapticFeedback.selectionClick();
  }

  /// Light haptic for general tactile interactions
  static Future<void> lightTap() async {
    await HapticFeedback.lightImpact();
  }
}
