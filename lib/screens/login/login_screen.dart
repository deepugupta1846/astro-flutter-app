import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/login_country_options.dart';
import '../../core/storage/auth_draft_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_country_code_dropdown.dart';
import '../../core/widgets/app_outline_input.dart';
import '../../core/widgets/app_primary_button.dart';
import 'astrologer_auth_wizard.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _mobileController = TextEditingController();
  final _phoneFocus = FocusNode();
  LoginCountryOption _country = kDefaultLoginCountry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _phoneFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  void _onCountrySelected(LoginCountryOption next) {
    setState(() {
      _country = next;
      final t = _mobileController.text;
      if (t.length > next.maxNationalDigits) {
        _mobileController.text = t.substring(0, next.maxNationalDigits);
        _mobileController.selection = TextSelection.collapsed(
          offset: _mobileController.text.length,
        );
      }
    });
  }

  void _onSendOtp() {
    final mobile = _mobileController.text.trim();
    if (!_country.isValidNational(mobile)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_country.validationMessage())),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => OtpScreen(
          mobileNumber: mobile,
          countryCode: _country.dialCode,
        ),
      ),
    );
  }

  Future<void> _onContinueAsAstrologer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kAstroAuthDraftKey);
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => const AstrologerAuthWizard(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0, 0.42, 1],
            colors: [
              AppTheme.backgroundColorWarm,
              Color.lerp(
                    AppTheme.backgroundColor,
                    AppTheme.primaryContainer,
                    0.35,
                  ) ??
                  AppTheme.backgroundColor,
              AppTheme.backgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                width: 140,
                height: 140,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.18),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Image.asset(
                  AppAssets.logo,
                  width: 140,
                  height: 140,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'AstroLoger',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Login or Sign Up',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.secondaryTextColor,
                    ),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.06),
                          blurRadius: 32,
                          offset: const Offset(0, 12),
                          spreadRadius: -8,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 24,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppCountryCodeDropdown(
                              value: _country,
                              onChanged: _onCountrySelected,
                              width: 88,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AppOutlineTextField(
                                key: ValueKey<String>(
                                  '${_country.dialCode}_${_country.name}',
                                ),
                                controller: _mobileController,
                                focusNode: _phoneFocus,
                                labelText: 'Mobile number',
                                hintText: _country.resolvedHint,
                                counterText: '',
                                keyboardType: TextInputType.phone,
                                maxLength: _country.maxNationalDigits,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        AppPrimaryButton(
                          onPressed: _onSendOtp,
                          child: const Text('SEND OTP'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 4),
                child: TextButton(
                  onPressed: _onContinueAsAstrologer,
                  child: Text(
                    'Continue as Astrologer',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      decoration: TextDecoration.underline,
                      decorationColor: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      color: AppTheme.secondaryTextColor,
                      fontSize: 12,
                      height: 1.4,
                    ),
                    children: [
                      const TextSpan(text: 'By signing up, you agree to our '),
                      TextSpan(
                        text: 'Terms of Use',
                        style: TextStyle(
                          color: AppTheme.primaryTextColor,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: TextStyle(
                          color: AppTheme.primaryTextColor,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
