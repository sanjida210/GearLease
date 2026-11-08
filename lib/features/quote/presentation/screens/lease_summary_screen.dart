import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/hardware_asset.dart';
import '../../domain/entities/lease_agreement_result.dart';
import '../../domain/entities/quote_calculation.dart';
import '../../domain/usecases/submit_lease_agreement_usecase.dart';

class LeaseSummaryScreen extends StatefulWidget {
  final String lesseeBusinessName;
  final HardwareAsset? asset;
  final QuoteCalculation? calculation;
  final Uint8List signatureBytes;
  final String? signatureSvg;
  final String auditHash;
  final String? businessEin;
  final SubmitLeaseAgreementUseCase? submitLeaseAgreement;
  final void Function(String pdfUrl)? onDownloadPdf;
  final VoidCallback? onCompleted;

  const LeaseSummaryScreen({
    super.key,
    required this.lesseeBusinessName,
    this.asset,
    this.calculation,
    required this.signatureBytes,
    this.signatureSvg,
    required this.auditHash,
    this.businessEin,
    this.submitLeaseAgreement,
    this.onDownloadPdf,
    this.onCompleted,
  });

  @override
  State<LeaseSummaryScreen> createState() => _LeaseSummaryScreenState();
}

class _LeaseSummaryScreenState extends State<LeaseSummaryScreen>
    with SingleTickerProviderStateMixin {
  bool _isSubmitting = false;
  String? _errorMessage;
  late final SubmitLeaseAgreementUseCase _submitUseCase;

  @override
  void initState() {
    super.initState();
    _submitUseCase = widget.submitLeaseAgreement ??
        (sl.isRegistered<SubmitLeaseAgreementUseCase>()
            ? sl<SubmitLeaseAgreementUseCase>()
            : SubmitLeaseAgreementUseCase(
                apiClient: sl(),
                syncRepository: sl(),
                networkInfo: sl(),
              ));
  }

  Future<void> _handleSubmit() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final calc = widget.calculation;
    final asset = widget.asset;

    final params = SubmitLeaseAgreementParams(
      quoteId: calc?.quoteId ?? 'qte-${DateTime.now().millisecondsSinceEpoch}',
      lesseeBusinessName: widget.lesseeBusinessName,
      equipmentSerial: asset?.serialNumber ?? 'SN-UNKNOWN',
      termMonths: calc?.termMonths ?? 36,
      monthlyBaseCents: calc?.monthlyBaseCents ?? 75500,
      pricingType: calc?.pricingType.name ?? 'FIXED_ANNUITY',
      auditHash: widget.auditHash,
      signatureBytes: widget.signatureBytes,
      signatureSvg: widget.signatureSvg,
      businessEin: widget.businessEin,
      metadata: {
        'equipment_make': asset?.make,
        'equipment_model': asset?.model,
        'equipment_msrp_cents': asset?.msrpCents,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      },
    );

    final result = await _submitUseCase(params);

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
    });

    result.when(
      success: (leaseResult) {
        _showSuccessConfirmationModal(leaseResult);
      },
      failure: (failure) {
        setState(() {
          _errorMessage = failure.message;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            backgroundColor: AppColors.criticalRed,
          ),
        );
      },
    );
  }

  void _showSuccessConfirmationModal(LeaseAgreementResult leaseResult) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'LeaseSuccessDialog',
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return _buildAnimatedSuccessDialog(dialogContext, leaseResult, animation);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedValue = Curves.easeOutBack.transform(animation.value);
        return Transform.scale(
          scale: curvedValue,
          child: Opacity(
            opacity: animation.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildAnimatedSuccessDialog(
    BuildContext dialogContext,
    LeaseAgreementResult result,
    Animation<double> animation,
  ) {
    return Dialog(
      key: const Key('lease_success_modal'),
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.performanceGreen, width: 1.5),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Animated Checkmark Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.performanceGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.performanceGreen, width: 2),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                size: 38,
                color: AppColors.performanceGreen,
              ),
            ),
            const SizedBox(height: 18),

            Text(
              result.isOfflineQueued
                  ? 'AGREEMENT QUEUED OFFLINE'
                  : 'LEASE AGREEMENT EXECUTED!',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ledgerWhite,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              result.isOfflineQueued
                  ? 'Agreement recorded locally. Auto-sync will dispatch once connection is restored.'
                  : 'Idempotency validated & funded. Assets provisioned for lessee.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.ledgerMuted,
              ),
            ),
            const SizedBox(height: 20),

            // Lease ID Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceCardElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.neutralBorder),
              ),
              child: Column(
                children: [
                  Text(
                    'OFFICIAL LEASE IDENTIFIER',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppColors.ledgerMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result.leaseId,
                    key: const Key('lease_id_text'),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.cyanAccent,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // PDF Download CTA
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                key: const Key('download_lease_pdf_button'),
                icon: const Icon(Icons.picture_as_pdf, color: AppColors.precisionCyan),
                label: Text(
                  'Download Executed Agreement PDF',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ledgerWhite,
                    fontSize: 13,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.precisionCyan),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  final url = result.pdfUrl ??
                      'https://api.gearlease.io/leases/${result.leaseId}/document.pdf';
                  widget.onDownloadPdf?.call(url);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Downloading Executed Agreement PDF...'),
                      backgroundColor: AppColors.precisionCyan,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Done CTA
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                key: const Key('lease_done_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.precisionCyan,
                  foregroundColor: AppColors.scaffoldBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.of(dialogContext).pop();
                  widget.onCompleted?.call();
                },
                child: Text(
                  'RETURN TO DASHBOARD',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final asset = widget.asset;
    final calc = widget.calculation;

    final monthlyAmount = ((calc?.estimatedMonthlyCents ?? calc?.monthlyBaseCents) ?? 75500) / 100;
    final term = calc?.termMonths ?? 36;
    final pricingModelName = (calc?.repaymentType == RepaymentStructureType.REVENUE_INDEXED ||
            calc?.pricingType == PricingType.REVENUE_INDEXED)
        ? 'Revenue-Indexed'
        : ((calc?.repaymentType == RepaymentStructureType.IOT_PAY_PER_USE ||
                calc?.pricingType == PricingType.PAY_PER_USE)
            ? 'IoT Pay-Per-Use'
            : 'Fixed Annuity');

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          'Lease Execution Summary',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.ledgerWhite,
          ),
        ),
        backgroundColor: AppColors.surfaceCard,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title Banner
                  Text(
                    'REVIEW & DISPATCH LEASE CONTRACT',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppColors.precisionCyan,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Confirm legal party details, asset spec, and cryptographic signature audit.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.ledgerMuted,
                    ),
                  ),
                  const SizedBox(height: 18),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.criticalRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.criticalRed),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.inter(color: AppColors.criticalRed, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 1. Lessee Business Profile Card
                  _buildSummaryCard(
                    title: 'LESSEE BUSINESS ENTITY',
                    icon: Icons.business,
                    children: [
                      _buildSummaryRow(
                        label: 'Legal Entity',
                        value: widget.lesseeBusinessName,
                        key: const Key('summary_lessee_name'),
                      ),
                      if (widget.businessEin != null) ...[
                        const SizedBox(height: 8),
                        _buildSummaryRow(
                          label: 'Business EIN',
                          value: widget.businessEin!,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. Equipment Asset Card
                  _buildSummaryCard(
                    title: 'EQUIPMENT IDENTIFICATION',
                    icon: Icons.precision_manufacturing,
                    children: [
                      _buildSummaryRow(
                        label: 'Equipment Description',
                        value: asset?.displayName ?? 'Industrial Machine',
                      ),
                      const SizedBox(height: 8),
                      _buildSummaryRow(
                        label: 'Serial Number',
                        value: asset?.serialNumber ?? 'LM-2026-9811',
                        key: const Key('summary_equipment_serial'),
                        highlightColor: AppColors.cyanAccent,
                      ),
                      if (asset != null && asset.msrpCents > 0) ...[
                        const SizedBox(height: 8),
                        _buildSummaryRow(
                          label: 'Equipment MSRP',
                          value: currencyFormatter.format(asset.msrpCents / 100),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3. Agreed Pricing Terms Card
                  _buildSummaryCard(
                    title: 'AGREED FINANCING TERMS',
                    icon: Icons.receipt_long,
                    children: [
                      _buildSummaryRow(
                        label: 'Financing Term',
                        value: '$term Months',
                        key: const Key('summary_term'),
                      ),
                      const SizedBox(height: 8),
                      _buildSummaryRow(
                        label: 'Repayment Architecture',
                        value: pricingModelName,
                        key: const Key('summary_pricing_model'),
                        highlightColor: AppColors.precisionCyan,
                      ),
                      const SizedBox(height: 8),
                      _buildSummaryRow(
                        label: 'Monthly Base Payment',
                        value: currencyFormatter.format(monthlyAmount),
                        key: const Key('summary_monthly_base'),
                        highlightColor: AppColors.ledgerWhite,
                        isLarge: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 4. Rendered Signature Preview & Cryptographic Audit Hash
                  _buildSummaryCard(
                    title: 'LEGAL SIGN-ON-GLASS AUDIT TRAIL',
                    icon: Icons.draw,
                    children: [
                      Text(
                        'Captured Vector Signature',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.ledgerMuted,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Rendered Signature Preview Container
                      Container(
                        key: const Key('summary_signature_preview'),
                        height: 110,
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.scaffoldBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.neutralBorder),
                        ),
                        child: widget.signatureBytes.isNotEmpty
                            ? Center(
                                child: Image.memory(
                                  widget.signatureBytes,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => Center(
                                    child: Text(
                                      'Vector Signature Captured',
                                      style: GoogleFonts.inter(
                                        color: AppColors.cyanAccent,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  'Vector Signature Captured',
                                  style: GoogleFonts.inter(
                                    color: AppColors.cyanAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),

                      // Cryptographic Audit Hash Badge
                      Container(
                        key: const Key('summary_audit_hash'),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCardElevated,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.precisionCyan.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.security,
                              size: 14,
                              color: AppColors.precisionCyan,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'SHA-256: ${widget.auditHash}',
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 11,
                                  color: AppColors.cyanAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Submit Button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      key: const Key('submit_lease_button'),
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.precisionCyan,
                        foregroundColor: AppColors.scaffoldBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: AppColors.scaffoldBackground,
                              ),
                            )
                          : Text(
                              'SUBMIT LEASE AGREEMENT',
                              style: GoogleFonts.spaceGrotesk(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutralBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.precisionCyan),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppColors.ledgerMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required String value,
    Key? key,
    Color? highlightColor,
    bool isLarge = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.ledgerMuted,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(
            value,
            key: key,
            textAlign: TextAlign.right,
            style: GoogleFonts.spaceGrotesk(
              fontSize: isLarge ? 16 : 13,
              fontWeight: FontWeight.w700,
              color: highlightColor ?? AppColors.ledgerWhite,
            ),
          ),
        ),
      ],
    );
  }
}
