import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_primary_button.dart';
import '../../core/api/user_api.dart';
import '../../core/session/app_session.dart';

class OtpScreen extends StatefulWidget {
  final String mobileNumber;
  final String countryCode;

  const OtpScreen({
    super.key,
    required this.mobileNumber,
    this.countryCode = '+91',
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const int _otpLength = 6;
  final List<TextEditingController> _controllers = List.generate(
    _otpLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    _otpLength,
    (_) => FocusNode(),
  );
  bool _isSubmitting = false;
  bool _isResending = false;
  bool _isSendingOtp = false;
  int _resendSeconds = 30;
  bool _canResend = false;
  Timer? _resendCountdownTimer;
  /// Shown in dev when API returns `_devOtp` (no real SMS).
  String? _devOtpHint;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    _sendOtp();
  }

  void _startResendTimer() {
    _resendCountdownTimer?.cancel();
    setState(() {
      _resendSeconds = 30;
      _canResend = false;
    });
    _resendCountdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_resendSeconds <= 1) {
          _resendSeconds = 0;
          _canResend = true;
          t.cancel();
        } else {
          _resendSeconds--;
        }
      });
    });
  }

  @override
  void dispose() {
    _resendCountdownTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _enteredOtp => _controllers.map((c) => c.text).join();

  void _onOtpChanged(int index, String value) {
    if (value.length > 1) {
      value = value[value.length - 1];
      _controllers[index].text = value;
    }
    if (value.isNotEmpty) {
      if (index < _otpLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }
  }

  KeyEventResult _onKey(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _handleVerifyResponse(Map<String, dynamic> res) async {
    if (!mounted) return;
    final ok = res['success'] == true || (res['_statusCode'] as int?) == 200;
    if (ok) {
      final data = res['data'];
      if (data is Map && data['user'] is Map) {
        await AppSession.setUser(
          Map<String, dynamic>.from(data['user'] as Map),
        );
      }
      if (!mounted) return;
      final existingUser = data is Map ? data['existingUser'] == true : false;
      if (existingUser) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/dashboard',
          (route) => false,
        );
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/details',
          (route) => false,
          arguments: {
            'phone': widget.mobileNumber,
            'countryCode': widget.countryCode,
          },
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Invalid OTP')),
      );
    }
  }

  Future<void> _submitOtp() async {
    final otp = _enteredOtp;
    if (otp.length != _otpLength) return;

    setState(() => _isSubmitting = true);
    try {
      final res = await UserApi.verifyOtp(
        phone: widget.mobileNumber,
        countryCode: widget.countryCode,
        otp: otp,
      );
      await _handleVerifyResponse(res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend || _isResending) return;
    setState(() => _isResending = true);
    try {
      final res = await UserApi.sendOtp(
        phone: widget.mobileNumber,
        countryCode: widget.countryCode,
      );
      if (!mounted) return;
      final ok = res['success'] == true || (res['_statusCode'] as int?) == 200;
      if (ok) {
        setState(() => _devOtpHint = res['_devOtp']?.toString());
        _startResendTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP sent again')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Resend failed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  String get _maskedNumber {
    final s = widget.mobileNumber.replaceAll(RegExp(r'\s'), '');
    if (s.length <= 4) return s;
    return '${s.substring(0, 2)}****${s.substring(s.length - 2)}';
  }

  Future<void> _sendOtp() async {
    if (_isSendingOtp) return;
    setState(() => _isSendingOtp = true);
    try {
      final res = await UserApi.sendOtp(
        phone: widget.mobileNumber,
        countryCode: widget.countryCode,
      );
      if (!mounted) return;
      final ok = res['success'] == true || (res['_statusCode'] as int?) == 200;
      if (ok) {
        setState(() => _devOtpHint = res['_devOtp']?.toString());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Failed to send OTP')),
        );
        _startResendTimer();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        _startResendTimer();
      }
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.backgroundColorWarm,
              AppTheme.backgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new, size: 18),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Verify OTP',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Enter the 6-digit code for\n${widget.countryCode} $_maskedNumber',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.secondaryTextColor,
                    ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'No SMS? Use the master OTP from server .env (MASTER_OTP).',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.secondaryTextColor,
                      ),
                ),
              ),
              if (_devOtpHint != null && _devOtpHint!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Dev OTP (non-production API): $_devOtpHint',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(_otpLength, (index) {
                          return SizedBox(
                            width: 44,
                            child: Focus(
                              onKeyEvent: (_, event) => _onKey(index, event),
                              child: TextField(
                                controller: _controllers[index],
                                focusNode: _focusNodes[index],
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                maxLength: 1,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onChanged: (value) => _onOtpChanged(index, value),
                                decoration: InputDecoration(
                                  counterText: '',
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusSm,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusSm,
                                    ),
                                    borderSide: const BorderSide(
                                      color: AppTheme.inputBorderColor,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusSm,
                                    ),
                                    borderSide: const BorderSide(
                                      color: AppTheme.primaryColor,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 28),
                      AppPrimaryButton(
                        onPressed: _enteredOtp.length == _otpLength &&
                                !_isSubmitting &&
                                !_isSendingOtp
                            ? _submitOtp
                            : null,
                        disabledBackgroundColor: AppTheme.buttonInactiveColor,
                        disabledForegroundColor:
                            AppTheme.buttonInactiveTextColor,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.buttonPrimaryTextColor,
                                ),
                              )
                            : const Text('SUBMIT'),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: (_canResend && !_isResending) ? _resendOtp : null,
                        child: _isResending
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                _canResend
                                    ? 'Resend OTP'
                                    : 'Resend OTP in $_resendSeconds s',
                                style: TextStyle(
                                  color: _canResend
                                      ? AppTheme.primaryColor
                                      : AppTheme.secondaryTextColor,
                                  fontWeight: FontWeight.w500,
                                ),
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
