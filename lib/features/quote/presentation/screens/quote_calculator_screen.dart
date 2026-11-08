import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/hardware_asset.dart';
import '../../domain/entities/quote_calculation.dart';
import '../bloc/quote_bloc.dart';
import '../bloc/quote_event.dart';
import '../bloc/quote_state.dart';

class QuoteCalculatorScreen extends StatelessWidget {
  final VoidCallback? onProceedToSignature;

  const QuoteCalculatorScreen({
    super.key,
    this.onProceedToSignature,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          'Underwriting Calculator',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.ledgerWhite,
          ),
        ),
        backgroundColor: AppColors.surfaceCard,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.ledgerMuted),
            onPressed: () {
              HapticFeedback.selectionClick();
              context.read<QuoteBloc>().add(ResetQuote());
            },
          ),
        ],
      ),
      body: BlocConsumer<QuoteBloc, QuoteState>(
        listener: (context, state) {
          if (state is QuoteErrorState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage),
                backgroundColor: AppColors.criticalRed,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is QuoteLoading || state is QuoteAssetResolving) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.precisionCyan),
              ),
            );
          }

          if (state is QuoteCalculatedState) {
            final asset = state.asset;
            final calc = state.calculation;
            final pricingType = state.selectedPricingType;

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Requirement 2: Dynamic Underwriting Header
                        _buildUnderwritingHeader(calc),
                        const SizedBox(height: 16),

                        // Requirement 1: Asset Spec Card
                        if (asset != null) ...[
                          _buildAssetSpecCard(asset, currencyFormatter),
                          const SizedBox(height: 20),
                        ],

                        // Requirement 3: Pricing Tier Switcher
                        _buildPricingTierSwitcher(context, pricingType),
                        const SizedBox(height: 24),

                        // Requirement 4: Interactive Term Slider & Snapping Chips
                        _buildTermSliderSection(context, state.selectedTermMonths),
                        const SizedBox(height: 24),

                        // Requirement 5: Payment Summary Ledger
                        _buildPaymentSummaryLedger(asset, calc, pricingType, currencyFormatter),
                        const SizedBox(height: 28),

                        // Requirement 6: Bottom Persistent CTA
                        _buildProceedCta(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.qr_code_scanner_outlined,
                    size: 64,
                    color: AppColors.ledgerMuted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Scan asset barcode or enter VIN to compute terms',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppColors.ledgerMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Requirement 2: Dynamic Underwriting Header with Fast-Track Badge
  Widget _buildUnderwritingHeader(QuoteCalculation calc) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8.0,
      runSpacing: 8.0,
      children: [
        // Qualification Status Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: AppColors.performanceGreen.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AppColors.performanceGreen.withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            calc.qualificationStatus.name.replaceAll('_', ' '),
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.performanceGreen,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),

        // Fast-Track Decision Badge
        Container(
          key: const Key('fast_track_badge'),
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: AppColors.precisionCyan.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AppColors.precisionCyan.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.bolt,
                size: 14,
                color: AppColors.precisionCyan,
              ),
              const SizedBox(width: 4),
              Text(
                '${calc.estimatedUnderwriteSeconds}-Second Fast-Track Decision',
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.precisionCyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Requirement 1: Asset Spec Card
  Widget _buildAssetSpecCard(HardwareAsset asset, NumberFormat currencyFormatter) {
    return Container(
      key: const Key('asset_spec_card'),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutralBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.make,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.precisionCyan,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      asset.model,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ledgerWhite,
                      ),
                    ),
                  ],
                ),
              ),
              // MSRP Badge
              Container(
                key: const Key('asset_msrp_badge'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCardElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.neutralBorder),
                ),
                child: Text(
                  'MSRP: ${currencyFormatter.format(asset.msrpCents / 100)}',
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.cyanAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SN: ${asset.serialNumber}',
                style: GoogleFonts.inter(
                  color: AppColors.ledgerMuted,
                  fontSize: 13,
                ),
              ),
              Text(
                asset.category,
                style: GoogleFonts.inter(
                  color: AppColors.ledgerMuted,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Requirement 3: Pricing Tier Switcher (Fixed Annuity vs Revenue-Indexed vs IoT Pay-Per-Use)
  Widget _buildPricingTierSwitcher(BuildContext context, PricingType selectedType) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'REPAYMENT ARCHITECTURE',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: AppColors.ledgerMuted,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Fixed Annuity Tier
            Expanded(
              child: _buildPricingTierButton(
                context: context,
                key: const Key('pricing_tier_fixed'),
                title: 'Fixed Annuity',
                subtitle: 'Fixed Monthly',
                isSelected: selectedType == PricingType.FIXED_ANNUITY,
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.read<QuoteBloc>().add(
                        const PricingModelSelected(PricingType.FIXED_ANNUITY),
                      );
                },
              ),
            ),
            const SizedBox(width: 8),

            // Revenue-Indexed Tier
            Expanded(
              child: _buildPricingTierButton(
                context: context,
                key: const Key('pricing_tier_rev_indexed'),
                title: 'Revenue-Indexed',
                subtitle: 'Dynamic Share',
                isSelected: selectedType == PricingType.REVENUE_INDEXED,
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.read<QuoteBloc>().add(
                        const PricingModelSelected(PricingType.REVENUE_INDEXED),
                      );
                },
              ),
            ),
            const SizedBox(width: 8),

            // IoT Pay-Per-Use Tier
            Expanded(
              child: _buildPricingTierButton(
                context: context,
                key: const Key('pricing_tier_iot'),
                title: 'IoT Pay-Per-Use',
                subtitle: 'Telemetry Metered',
                isSelected: selectedType == PricingType.PAY_PER_USE,
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.read<QuoteBloc>().add(
                        const PricingModelSelected(PricingType.PAY_PER_USE),
                      );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPricingTierButton({
    required BuildContext context,
    required Key key,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return OutlinedButton(
      key: key,
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected
            ? AppColors.precisionCyan.withValues(alpha: 0.2)
            : AppColors.surfaceCard,
        side: BorderSide(
          color: isSelected ? AppColors.precisionCyan : AppColors.neutralBorder,
          width: isSelected ? 1.5 : 1.0,
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: isSelected ? AppColors.precisionCyan : AppColors.ledgerWhite,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: isSelected ? AppColors.precisionCyan : AppColors.ledgerMuted,
            ),
          ),
        ],
      ),
    );
  }

  /// Requirement 4: Interactive Term Slider with Snapping Intervals
  Widget _buildTermSliderSection(BuildContext context, int currentTermMonths) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutralBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FINANCING TERM HORIZON',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppColors.ledgerMuted,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.precisionCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$currentTermMonths Months',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w700,
                    color: AppColors.precisionCyan,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Slider with min: 36, max: 60, divisions: 2 (36, 48, 60)
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.precisionCyan,
              inactiveTrackColor: AppColors.neutralBorder,
              thumbColor: AppColors.cyanAccent,
              overlayColor: AppColors.precisionCyan.withValues(alpha: 0.2),
              tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 4),
              activeTickMarkColor: AppColors.ledgerWhite,
              inactiveTickMarkColor: AppColors.neutralBorder,
              valueIndicatorColor: AppColors.surfaceCardElevated,
              valueIndicatorTextStyle: GoogleFonts.spaceGrotesk(
                color: AppColors.ledgerWhite,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Slider(
              key: const Key('term_slider'),
              value: currentTermMonths.toDouble().clamp(36.0, 60.0),
              min: 36.0,
              max: 60.0,
              divisions: 2,
              label: '$currentTermMonths Mo',
              onChanged: (double val) {
                final int newTerm = val.round();
                if (newTerm != currentTermMonths) {
                  HapticFeedback.selectionClick();
                  context.read<QuoteBloc>().add(TermChanged(newTerm));
                }
              },
            ),
          ),

          const SizedBox(height: 8),

          // Snapping Term Buttons row for direct selection
          Row(
            children: [36, 48, 60].map((term) {
              final isSelected = currentTermMonths == term;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ElevatedButton(
                    onPressed: () {
                      if (!isSelected) {
                        HapticFeedback.selectionClick();
                        context.read<QuoteBloc>().add(TermChanged(term));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected
                          ? AppColors.precisionCyan
                          : AppColors.surfaceCardElevated,
                      foregroundColor:
                          isSelected ? Colors.white : AppColors.ledgerMuted,
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.precisionCyan
                            : AppColors.neutralBorder,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text(
                      '$term Mo',
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Requirement 5: Payment Summary Ledger with Base, Rev Share %, Caps, and Buyout Options
  Widget _buildPaymentSummaryLedger(
    HardwareAsset? asset,
    QuoteCalculation calc,
    PricingType pricingType,
    NumberFormat currencyFormatter,
  ) {
    final isRevIndexed = pricingType == PricingType.REVENUE_INDEXED;
    final isPayPerUse = pricingType == PricingType.PAY_PER_USE;

    final primaryMonthlyAmount = ((isRevIndexed
                ? calc.estimatedMonthlyCents
                : (isPayPerUse ? (calc.monthlyBaseCents ~/ 2) : calc.fixedMonthlyCents)) ??
            calc.fixedMonthlyCents) /
        100;

    final baseMonthlyAmount = (calc.monthlyBaseCents > 0
            ? calc.monthlyBaseCents
            : calc.fixedMonthlyCents) /
        100;

    final revenueSharePct = calc.revenueSharePercent ?? calc.revenueSharePct ?? 3.5;
    final fmvBuyoutAmount = ((asset?.msrpCents ?? 2450000) * 0.10) / 100;

    return Container(
      key: const Key('payment_summary_ledger'),
      padding: const EdgeInsets.all(22.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.precisionCyan.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Primary Highlight
          Center(
            child: Text(
              isRevIndexed
                  ? 'ESTIMATED MONTHLY BASE'
                  : (isPayPerUse ? 'METERED BASE CHARGE' : 'FIXED MONTHLY PAYMENT'),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.ledgerMuted,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              currencyFormatter.format(primaryMonthlyAmount),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: AppColors.ledgerWhite,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.dividerColor, height: 1),
          const SizedBox(height: 16),

          // Ledger Rows
          _buildLedgerRow(
            label: 'Contract Base Amount',
            value: currencyFormatter.format(baseMonthlyAmount),
            valueColor: AppColors.ledgerWhite,
          ),
          const SizedBox(height: 10),

          // Projected Revenue Share %
          _buildLedgerRow(
            label: 'Projected Revenue Share',
            value: isRevIndexed ? '${revenueSharePct.toStringAsFixed(1)}%' : 'N/A (Fixed Schedule)',
            valueColor: isRevIndexed ? AppColors.precisionCyan : AppColors.ledgerMuted,
          ),
          const SizedBox(height: 10),

          // Payment Caps (Floor & Cap)
          if (calc.floorCents != null || calc.capCents != null) ...[
            _buildLedgerRow(
              label: 'Payment Floor Limit',
              value: currencyFormatter.format((calc.floorCents ?? 0) / 100),
              valueColor: AppColors.industrialAmber,
            ),
            const SizedBox(height: 10),
            _buildLedgerRow(
              label: 'Payment Cap Ceiling',
              value: currencyFormatter.format((calc.capCents ?? 0) / 100),
              valueColor: AppColors.precisionCyan,
            ),
            const SizedBox(height: 10),
          ],

          const Divider(color: AppColors.dividerColor, height: 1),
          const SizedBox(height: 14),

          // Buyout Options
          Text(
            'END-OF-TERM BUYOUT OPTIONS',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: AppColors.ledgerMuted,
            ),
          ),
          const SizedBox(height: 10),
          _buildLedgerRow(
            label: '10% FMV Buyout',
            value: currencyFormatter.format(fmvBuyoutAmount),
            valueColor: AppColors.cyanAccent,
          ),
          const SizedBox(height: 8),
          _buildLedgerRow(
            label: '\$1.00 Purchase Option',
            value: '\$1.00 at Maturity',
            valueColor: AppColors.performanceGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerRow({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.ledgerMuted,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          textAlign: TextAlign.right,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  /// Requirement 6: Bottom Persistent CTA
  Widget _buildProceedCta() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        key: const Key('quote_proceed_signature_button'),
        onPressed: () {
          HapticFeedback.mediumImpact();
          onProceedToSignature?.call();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.precisionCyan,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
        ),
        child: Text(
          'Proceed to Customer Sign-on-Glass',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
