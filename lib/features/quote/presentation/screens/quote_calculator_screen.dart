import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
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
            onPressed: () => context.read<QuoteBloc>().add(ResetQuote()),
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
          if (state is QuoteLoading) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.precisionCyan),
              ),
            );
          }

          if (state is QuoteCalculatedState) {
            final asset = state.asset;
            final calc = state.calculation;
            final isRevIndexed = state.selectedStructure == RepaymentStructureType.REVENUE_INDEXED;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 580),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Status Badge
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
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
                      ),
                      const SizedBox(height: 16),

                      // Asset Card
                      if (asset != null)
                        Container(
                          padding: const EdgeInsets.all(20.0),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.neutralBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                asset.displayName,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ledgerWhite,
                                ),
                              ),
                              const SizedBox(height: 6),
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
                                    currencyFormatter.format(asset.initialValueCents / 100),
                                    style: GoogleFonts.spaceGrotesk(
                                      color: AppColors.cyanAccent,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),

                      // Pricing Structure Selector
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
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                context.read<QuoteBloc>().add(
                                      const RepaymentStructureChanged(
                                        RepaymentStructureType.FIXED_MONTHLY,
                                      ),
                                    );
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: !isRevIndexed
                                    ? AppColors.precisionCyan.withValues(alpha: 0.2)
                                    : AppColors.surfaceCard,
                                side: BorderSide(
                                  color: !isRevIndexed
                                      ? AppColors.precisionCyan
                                      : AppColors.neutralBorder,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: Text(
                                'Fixed Monthly',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  color: !isRevIndexed
                                      ? AppColors.precisionCyan
                                      : AppColors.ledgerWhite,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                context.read<QuoteBloc>().add(
                                      const RepaymentStructureChanged(
                                        RepaymentStructureType.REVENUE_INDEXED,
                                      ),
                                    );
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: isRevIndexed
                                    ? AppColors.precisionCyan.withValues(alpha: 0.2)
                                    : AppColors.surfaceCard,
                                side: BorderSide(
                                  color: isRevIndexed
                                      ? AppColors.precisionCyan
                                      : AppColors.neutralBorder,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: Text(
                                'Revenue-Indexed',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  color: isRevIndexed
                                      ? AppColors.precisionCyan
                                      : AppColors.ledgerWhite,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Term Selector Buttons
                      Text(
                        'FINANCING TERM HORIZON',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: AppColors.ledgerMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [36, 48, 60].map((term) {
                          final isSelected = state.selectedTermMonths == term;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: ElevatedButton(
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  context.read<QuoteBloc>().add(TermChanged(term));
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
                                ),
                                child: Text('$term Mo'),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // Calculated Monthly Payment Card
                      Container(
                        padding: const EdgeInsets.all(24.0),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.precisionCyan.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              isRevIndexed ? 'ESTIMATED MONTHLY BASE' : 'FIXED MONTHLY PAYMENT',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: AppColors.ledgerMuted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              currencyFormatter.format(
                                ((isRevIndexed
                                            ? calc.estimatedMonthlyCents
                                            : calc.fixedMonthlyCents) ??
                                        calc.fixedMonthlyCents) /
                                    100,
                              ),
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 38,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ledgerWhite,
                              ),
                            ),
                            if (isRevIndexed && calc.floorCents != null && calc.capCents != null) ...[
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  Column(
                                    children: [
                                      Text(
                                        'FLOOR',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.ledgerMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        currencyFormatter.format(calc.floorCents! / 100),
                                        style: GoogleFonts.spaceGrotesk(
                                          color: AppColors.industrialAmber,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    width: 1,
                                    height: 28,
                                    color: AppColors.neutralBorder,
                                  ),
                                  Column(
                                    children: [
                                      Text(
                                        'CAP',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.ledgerMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        currencyFormatter.format(calc.capCents! / 100),
                                        style: GoogleFonts.spaceGrotesk(
                                          color: AppColors.precisionCyan,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // CTA
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          key: const Key('quote_proceed_signature_button'),
                          onPressed: onProceedToSignature,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.precisionCyan,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'PROCEED TO SIGNATURE ON GLASS',
                            style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Center(
            child: Text(
              'Scan asset barcode or enter VIN to compute terms',
              style: GoogleFonts.inter(color: AppColors.ledgerMuted),
            ),
          );
        },
      ),
    );
  }
}
