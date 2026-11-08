import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:signature/signature.dart' hide SignatureState;
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/mobile_sign_event.dart';
import '../bloc/signature_bloc.dart';
import '../bloc/signature_event.dart';
import '../bloc/signature_state.dart';

class SignaturePadModal extends StatefulWidget {
  final String contractId;
  final void Function(MobileSignEvent signEvent)? onSigned;
  final bool requiresBiometricAudit;

  const SignaturePadModal({
    super.key,
    required this.contractId,
    this.onSigned,
    this.requiresBiometricAudit = false,
  });

  @override
  State<SignaturePadModal> createState() => _SignaturePadModalState();
}

class _SignaturePadModalState extends State<SignaturePadModal> {
  late SignatureController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 3,
      penColor: AppColors.cyanAccent,
      exportBackgroundColor: Colors.transparent,
    );

    _controller.addListener(_onCanvasChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<SignatureBloc>().state;
      if (state is SignatureSuccess) {
        widget.onSigned?.call(state.signEvent);
      }
    });
  }

  void _onCanvasChanged() {
    if (_controller.isNotEmpty) {
      context.read<SignatureBloc>().add(
            SignatureStrokeAdded(_controller.points.length),
          );
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onCanvasChanged);
    _controller.dispose();
    super.dispose();
  }

  void _clearSignature() {
    _controller.clear();
    context.read<SignatureBloc>().add(SignatureCleared());
  }

  void _submitSignature() {
    final svgString = _controller.toRawSVG() ?? '<svg></svg>';
    context.read<SignatureBloc>().add(
          SignatureSubmitted(
            contractId: widget.contractId,
            signatureSvg: svgString,
            requiresBiometricAudit: widget.requiresBiometricAudit,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SignatureBloc, SignatureState>(
      listener: (context, state) {
        if (state is SignatureSuccess) {
          widget.onSigned?.call(state.signEvent);
        } else if (state is SignatureFailureState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.criticalRed,
            ),
          );
        }
      },
      builder: (context, state) {
        final isSubmitting = state is SignatureSubmitting;

        return Container(
          padding: const EdgeInsets.all(24.0),
          decoration: const BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EXECUTE LEASE AGREEMENT',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: AppColors.ledgerWhite,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Contract ID: ${widget.contractId}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.ledgerMuted,
                            ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.ledgerMuted),
                    onPressed: isSubmitting ? null : () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: AppColors.scaffoldBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.neutralBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Signature(
                      controller: _controller,
                      backgroundColor: Colors.transparent,
                      height: 200,
                    ),
                    if (state is SignatureInitial || _controller.isEmpty)
                      Center(
                        child: Text(
                          'Sign within the frame using your finger or stylus',
                          style: TextStyle(
                            color: AppColors.ledgerMuted.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 8,
                      left: 12,
                      child: Text(
                        'Vector stroke audit active (X, Y, P, timestamp)',
                        style: TextStyle(
                          color: AppColors.ledgerMuted.withValues(alpha: 0.4),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('signature_clear_button'),
                      onPressed: isSubmitting ? null : _clearSignature,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.ledgerMuted,
                        side: const BorderSide(color: AppColors.neutralBorder),
                      ),
                      child: const Text('CLEAR'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      key: const Key('signature_submit_button'),
                      onPressed: isSubmitting ? null : _submitSignature,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.precisionCyan,
                        foregroundColor: AppColors.scaffoldBackground,
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.scaffoldBackground,
                              ),
                            )
                          : const Text(
                              'AUTHORIZE & EXECUTE',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
