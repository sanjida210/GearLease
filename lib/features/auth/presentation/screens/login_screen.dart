import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../shell/presentation/screens/main_shell_screen.dart';
import '../../domain/entities/user_session.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const LoginScreen({
    super.key,
    this.onLoginSuccess,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  String _selectedOrganization = 'org-craft-coffee';
  UserRole _selectedRole = UserRole.VENDOR_AGENT;

  final Map<String, String> _organizations = const {
    'org-craft-coffee': 'Craft Coffee Roasters LLC',
    'org-showroom-vendor': 'Showroom Equipment Vendor Inc.',
    'org-bay-fleet': 'Bay Fleet Logistics LLC',
  };

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitLogin() {
    HapticFeedback.lightImpact();
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
            LoginRequested(
              _emailController.text.trim(),
              _passwordController.text,
            ),
          );
    }
  }

  void _triggerBiometrics() {
    HapticFeedback.mediumImpact();
    context.read<AuthBloc>().add(BiometricAuthRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is Authenticated) {
            HapticFeedback.heavyImpact();
            if (widget.onLoginSuccess != null) {
              widget.onLoginSuccess!();
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const MainShellScreen()),
              );
            }
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;
          final errorMessage = state is AuthFailure
              ? state.message
              : (state is AuthFailureState ? state.message : null);

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
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 24),

                      // Role Preview Segmented Selector
                      _buildRolePreviewSelector(),
                      const SizedBox(height: 20),

                      // Inline Error Banner (Phase 10 requirement)
                      if (errorMessage != null) ...[
                        Container(
                          key: const Key('login_error_banner'),
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: AppColors.criticalRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.criticalRed),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.criticalRed,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorMessage,
                                  style: GoogleFonts.inter(
                                    color: AppColors.ledgerWhite,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Auth Card Form
                      Container(
                        padding: const EdgeInsets.all(24.0),
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

                              // Organization Selector (Phase 10 requirement)
                              DropdownButtonFormField<String>(
                                key: const Key('login_org_selector'),
                                initialValue: _selectedOrganization,
                                isExpanded: true,
                                dropdownColor: AppColors.surfaceCardElevated,
                                style: GoogleFonts.inter(color: AppColors.ledgerWhite),
                                decoration: InputDecoration(
                                  labelText: 'Select Organization',
                                  labelStyle: GoogleFonts.inter(color: AppColors.ledgerMuted),
                                  prefixIcon: const Icon(
                                    Icons.business_outlined,
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
                                items: _organizations.entries.map((entry) {
                                  return DropdownMenuItem<String>(
                                    value: entry.key,
                                    child: Text(
                                      entry.value,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: AppColors.ledgerWhite,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: isLoading
                                    ? null
                                    : (val) {
                                        if (val != null) {
                                          setState(() => _selectedOrganization = val);
                                        }
                                      },
                              ),
                              const SizedBox(height: 16),

                              // Email Field
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
                              const SizedBox(height: 16),

                              // Password Field
                              TextFormField(
                                key: const Key('login_password_field'),
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                enabled: !isLoading,
                                style: GoogleFonts.inter(color: AppColors.ledgerWhite),
                                decoration: InputDecoration(
                                  labelText: 'Passcode / Security Key',
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
                              const SizedBox(height: 24),

                              // Submit Credentials Button
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
                              const SizedBox(height: 14),

                              // Instant Biometric Login Button (Phase 10 requirement)
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
                                    'Instant Biometric Login',
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

  Widget _buildRolePreviewSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neutralBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: const Key('role_preview_vendor'),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedRole = UserRole.VENDOR_AGENT);
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedRole == UserRole.VENDOR_AGENT
                      ? AppColors.surfaceCardElevated
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _selectedRole == UserRole.VENDOR_AGENT
                        ? AppColors.precisionCyan
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      size: 16,
                      color: _selectedRole == UserRole.VENDOR_AGENT
                          ? AppColors.cyanAccent
                          : AppColors.ledgerMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Vendor POS',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _selectedRole == UserRole.VENDOR_AGENT
                            ? AppColors.ledgerWhite
                            : AppColors.ledgerMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              key: const Key('role_preview_lessee'),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedRole = UserRole.LESSEE_OWNER);
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedRole == UserRole.LESSEE_OWNER
                      ? AppColors.surfaceCardElevated
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _selectedRole == UserRole.LESSEE_OWNER
                        ? AppColors.precisionCyan
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.precision_manufacturing_outlined,
                      size: 16,
                      color: _selectedRole == UserRole.LESSEE_OWNER
                          ? AppColors.cyanAccent
                          : AppColors.ledgerMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Fleet Owner',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _selectedRole == UserRole.LESSEE_OWNER
                            ? AppColors.ledgerWhite
                            : AppColors.ledgerMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
