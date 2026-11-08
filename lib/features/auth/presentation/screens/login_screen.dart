import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitLogin() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
            AuthLoginRequested(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            ),
          );
    }
  }

  void _triggerBiometrics() {
    context.read<AuthBloc>().add(AuthBiometricLoginRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailureState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.message,
                  style: GoogleFonts.inter(color: Colors.white),
                ),
                backgroundColor: AppColors.criticalRed,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Terminal Branding
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14.0,
                            vertical: 6.0,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.precisionCyan.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.precisionCyan.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            'TLS 1.3 SECURE POS // VERIFIED NODE',
                            style: GoogleFonts.inter(
                              color: AppColors.cyanAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'GEARLEASE',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                          color: AppColors.ledgerWhite,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Commercial Equipment Financing Terminal',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.ledgerMuted,
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Auth Card Form
                      Container(
                        padding: const EdgeInsets.all(28.0),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.neutralBorder),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'OPERATOR IDENTIFICATION',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: AppColors.ledgerMuted,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                key: const Key('login_email_field'),
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                enabled: !isLoading,
                                style: GoogleFonts.inter(color: AppColors.ledgerWhite),
                                decoration: InputDecoration(
                                  labelText: 'Corporate Email',
                                  labelStyle: GoogleFonts.inter(color: AppColors.ledgerMuted),
                                  prefixIcon: const Icon(
                                    Icons.badge_outlined,
                                    color: AppColors.precisionCyan,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.surfaceCardElevated,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: AppColors.neutralBorder),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: AppColors.neutralBorder),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: AppColors.precisionCyan,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter corporate email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                key: const Key('login_password_field'),
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                enabled: !isLoading,
                                style: GoogleFonts.inter(color: AppColors.ledgerWhite),
                                decoration: InputDecoration(
                                  labelText: 'Passcode / Key',
                                  labelStyle: GoogleFonts.inter(color: AppColors.ledgerMuted),
                                  prefixIcon: const Icon(
                                    Icons.lock_outline,
                                    color: AppColors.precisionCyan,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: AppColors.ledgerMuted,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  filled: true,
                                  fillColor: AppColors.surfaceCardElevated,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: AppColors.neutralBorder),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: AppColors.neutralBorder),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: AppColors.precisionCyan,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter security passkey';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 28),

                              // Submit Button
                              SizedBox(
                                height: 50,
                                child: ElevatedButton(
                                  key: const Key('login_submit_button'),
                                  onPressed: isLoading ? null : _submitLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.precisionCyan,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : Text(
                                          'AUTHORIZE TERMINAL',
                                          style: GoogleFonts.spaceGrotesk(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Biometric Button
                              SizedBox(
                                height: 50,
                                child: OutlinedButton.icon(
                                  key: const Key('login_biometric_button'),
                                  onPressed: isLoading ? null : _triggerBiometrics,
                                  icon: const Icon(
                                    Icons.fingerprint,
                                    color: AppColors.cyanAccent,
                                  ),
                                  label: Text(
                                    'BIOMETRIC INSTANT UNLOCK',
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.0,
                                      color: AppColors.ledgerWhite,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppColors.neutralBorder),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    backgroundColor: AppColors.surfaceCardElevated,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'AUTHORIZED PERSONNEL ONLY • REV-INDEXED SECURED',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.8,
                          color: AppColors.ledgerMuted.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
