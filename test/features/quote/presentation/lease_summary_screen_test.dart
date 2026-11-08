import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/theme/app_theme.dart';
import 'package:gearlease/core/utils/result.dart';
import 'package:gearlease/features/quote/domain/entities/hardware_asset.dart';
import 'package:gearlease/features/quote/domain/entities/lease_agreement_result.dart';
import 'package:gearlease/features/quote/domain/entities/quote_calculation.dart';
import 'package:gearlease/features/quote/domain/usecases/submit_lease_agreement_usecase.dart';
import 'package:gearlease/features/quote/presentation/screens/lease_summary_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockSubmitLeaseAgreementUseCase extends Mock implements SubmitLeaseAgreementUseCase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSubmitLeaseAgreementUseCase mockSubmitLease;

  const testAsset = HardwareAsset(
    id: 'ast-001',
    vendorId: 'vnd-101',
    serialNumber: 'LM-2026-9811',
    barcodePayload: 'GL-ROAST-2026-9811',
    barcodeSymbology: 'CODE_128',
    make: 'La Marzocco',
    model: 'Linea PB 3-Group',
    category: 'Commercial Espresso',
    initialValueCents: 2450000,
    iotDeviceIdentifier: 'IOT-LM-9811',
  );

  const testQuote = QuoteCalculation(
    quoteId: 'qte-998822',
    qualificationStatus: QualificationStatus.INSTANT_QUALIFIED,
    repaymentType: RepaymentStructureType.REVENUE_INDEXED,
    termMonths: 36,
    requestedAmountCents: 2450000,
    monthlyBaseCents: 75500,
    revenueSharePercent: 3.5,
    estimatedMonthlyCents: 72000,
  );

  final testSignatureBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x01, 0x02]);

  setUpAll(() {
    registerFallbackValue(SubmitLeaseAgreementParams(
      quoteId: 'qte-998822',
      lesseeBusinessName: 'Apex Roasting Works LLC',
      equipmentSerial: 'LM-2026-9811',
      termMonths: 36,
      monthlyBaseCents: 75500,
      pricingType: 'REVENUE_INDEXED',
      auditHash: 'mock-sha256-hash',
      signatureBytes: testSignatureBytes,
    ));
  });

  setUp(() {
    mockSubmitLease = MockSubmitLeaseAgreementUseCase();
  });

  Widget createWidgetUnderTest({
    void Function(String)? onDownloadPdf,
    VoidCallback? onCompleted,
  }) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: LeaseSummaryScreen(
        lesseeBusinessName: 'Apex Roasting Works LLC',
        asset: testAsset,
        calculation: testQuote,
        signatureBytes: testSignatureBytes,
        signatureSvg: '<svg></svg>',
        auditHash: 'mock-sha256-hash-fingerprint',
        submitLeaseAgreement: mockSubmitLease,
        onDownloadPdf: onDownloadPdf,
        onCompleted: onCompleted,
      ),
    );
  }

  group('Phase 17 — LeaseSummaryScreen Widget Tests', () {
    testWidgets('renders full summary: business name, serial, pricing terms, signature preview, audit hash', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      // Lessee business name
      expect(find.byKey(const Key('summary_lessee_name')), findsOneWidget);
      expect(find.text('Apex Roasting Works LLC'), findsOneWidget);

      // Equipment serial & details
      expect(find.byKey(const Key('summary_equipment_serial')), findsOneWidget);
      expect(find.textContaining('LM-2026-9811'), findsWidgets);
      expect(find.textContaining('La Marzocco Linea PB 3-Group'), findsWidgets);

      // Agreed pricing terms
      expect(find.byKey(const Key('summary_term')), findsOneWidget);
      expect(find.textContaining('36 Months'), findsWidgets);
      expect(find.byKey(const Key('summary_pricing_model')), findsOneWidget);
      expect(find.textContaining('Revenue-Indexed'), findsWidgets);
      expect(find.byKey(const Key('summary_monthly_base')), findsOneWidget);

      // Rendered signature preview
      expect(find.byKey(const Key('summary_signature_preview')), findsOneWidget);

      // Cryptographic audit hash fingerprint
      expect(find.byKey(const Key('summary_audit_hash')), findsOneWidget);
      expect(find.textContaining('mock-sha256-hash-fingerprint'), findsWidgets);

      // Submit CTA
      expect(find.byKey(const Key('submit_lease_button')), findsOneWidget);
    });

    testWidgets('submits lease agreement and displays animated success modal with instant Lease ID and PDF download option', (tester) async {
      when(() => mockSubmitLease.call(any())).thenAnswer((_) async => Result.success(
            LeaseAgreementResult(
              leaseId: 'LSE-2026-98110',
              status: 'EXECUTED',
              pdfUrl: 'https://api.gearlease.io/leases/LSE-2026-98110/doc.pdf',
              idempotencyKey: 'idemp-1234',
              isOfflineQueued: false,
              submittedAt: DateTime.now(),
            ),
          ));

      bool downloadTriggered = false;

      await tester.pumpWidget(createWidgetUnderTest(
        onDownloadPdf: (url) {
          downloadTriggered = true;
        },
      ));
      await tester.pump();

      final submitBtn = find.byKey(const Key('submit_lease_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pump(); // Start submission
      await tester.pump(const Duration(milliseconds: 300)); // Animate modal

      // Success modal displayed
      expect(find.byKey(const Key('lease_success_modal')), findsOneWidget);
      expect(find.byKey(const Key('lease_id_text')), findsOneWidget);
      expect(find.textContaining('LSE-2026-98110'), findsWidgets);

      // PDF download button in modal
      final downloadBtn = find.byKey(const Key('download_lease_pdf_button'));
      expect(downloadBtn, findsOneWidget);

      await tester.tap(downloadBtn);
      await tester.pump();

      expect(downloadTriggered, isTrue);
    });
  });
}
