import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/astrologer_api.dart';
import '../../core/api/upload_api.dart';
import '../../core/api/user_api.dart';
import '../../core/session/app_session.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/astrologer_profile_options.dart';
import '../../core/constants/login_country_options.dart';
import '../../core/storage/auth_draft_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_country_code_dropdown.dart';
import '../../core/widgets/app_mat_select_dropdown.dart';
import '../../core/widgets/app_outline_input.dart';
import '../../core/widgets/app_primary_button.dart';

const _idProofOptions = <String, String>{
  'aadhaar': 'Aadhaar',
  'pan': 'PAN',
  'passport': 'Passport',
  'driving_license': 'Driving license',
  'voter_id': 'Voter ID',
  'other': 'Other',
};

/// Full astrologer signup: phone → OTP → profile → professional → KYC.
class AstrologerAuthWizard extends StatefulWidget {
  const AstrologerAuthWizard({super.key});

  @override
  State<AstrologerAuthWizard> createState() => _AstrologerAuthWizardState();
}

class _AstrologerAuthWizardState extends State<AstrologerAuthWizard> {
  static const int _otpLen = 6;

  int _step = 0;

  final _phone = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _bio = TextEditingController();
  final _experience = TextEditingController();
  final _fee = TextEditingController();
  final _idNumber = TextEditingController();

  final _otpCtrls =
      List.generate(_otpLen, (_) => TextEditingController());
  final _otpNodes = List.generate(_otpLen, (_) => FocusNode());
  final _phoneFocus = FocusNode();
  final _nameFocus = FocusNode();

  LoginCountryOption _country = kDefaultLoginCountry;

  String? _gender;
  String? _education;
  String? _idProofType;

  final List<String> _specialties = [];
  final List<String> _languages = [];
  final List<String> _skills = [];

  String? _profileImageUrl;
  String? _profileLocalPath;
  String? _idFrontUrl;
  String? _idFrontLocalPath;
  String? _idBackUrl;
  String? _idBackLocalPath;

  bool _sendOtpLoading = false;
  bool _verifyLoading = false;
  bool _resendLoading = false;
  bool _submitLoading = false;
  int _resendSeconds = 30;
  bool _canResend = false;
  Timer? _resendTimer;
  String? _devOtpHint;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadDraft().then((_) {
      if (!mounted) return;
      if (_step == 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _phoneFocus.requestFocus();
        });
      }
    });
  }

  Future<void> _loadDraft() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(kAstroAuthDraftKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _step = (m['step'] as num?)?.toInt() ?? 0;
        _phone.text = m['phone']?.toString() ?? '';
        final cname = m['countryName']?.toString();
        if (cname != null && cname.isNotEmpty) {
          _country = kLoginCountryOptions.firstWhere(
            (o) => o.name == cname,
            orElse: () => kDefaultLoginCountry,
          );
        }
        _name.text = m['name']?.toString() ?? '';
        _email.text = m['email']?.toString() ?? '';
        _bio.text = m['bio']?.toString() ?? '';
        final ed = m['education']?.toString();
        _education = (ed != null &&
                ed.isNotEmpty &&
                kAstrologerEducationOptions.contains(ed))
            ? ed
            : null;
        _experience.text = m['experience']?.toString() ?? '';
        _fee.text = m['fee']?.toString() ?? '';
        _idNumber.text = m['idNumber']?.toString() ?? '';
        _gender = m['gender']?.toString();
        _idProofType = m['idProofType']?.toString();
        _profileImageUrl = m['profileImageUrl']?.toString();
        _profileLocalPath = m['profileLocalPath']?.toString();
        _idFrontUrl = m['idFrontUrl']?.toString();
        _idFrontLocalPath = m['idFrontLocalPath']?.toString();
        _idBackUrl = m['idBackUrl']?.toString();
        _idBackLocalPath = m['idBackLocalPath']?.toString();
        _specialties
          ..clear()
          ..addAll(
            _stringList(m['specialties']).where(
              kAstrologerSpecialtyOptions.contains,
            ),
          );
        _languages
          ..clear()
          ..addAll(
            _stringList(m['languages']).where(
              kAstrologerLanguageOptions.contains,
            ),
          );
        _skills
          ..clear()
          ..addAll(
            _stringList(m['skills']).where(
              kAstrologerSkillOptions.contains,
            ),
          );
        if (_step > 4) _step = 4;
      });
    } catch (_) {}
  }

  List<String> _stringList(dynamic v) {
    if (v is List) {
      return v.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  Future<void> _saveDraft() async {
    final p = await SharedPreferences.getInstance();
    final m = <String, dynamic>{
      'step': _step,
      'phone': _phone.text,
      'countryName': _country.name,
      'name': _name.text,
      'email': _email.text,
      'bio': _bio.text,
      'education': _education ?? '',
      'experience': _experience.text,
      'fee': _fee.text,
      'idNumber': _idNumber.text,
      'gender': _gender,
      'idProofType': _idProofType,
      'profileImageUrl': _profileImageUrl,
      'profileLocalPath': _profileLocalPath,
      'idFrontUrl': _idFrontUrl,
      'idFrontLocalPath': _idFrontLocalPath,
      'idBackUrl': _idBackUrl,
      'idBackLocalPath': _idBackLocalPath,
      'specialties': List<String>.from(_specialties),
      'languages': List<String>.from(_languages),
      'skills': List<String>.from(_skills),
    };
    await p.setString(kAstroAuthDraftKey, jsonEncode(m));
  }

  Future<void> _clearDraft() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(kAstroAuthDraftKey);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phone.dispose();
    _name.dispose();
    _email.dispose();
    _bio.dispose();
    _experience.dispose();
    _fee.dispose();
    _idNumber.dispose();
    for (final c in _otpCtrls) {
      c.dispose();
    }
    for (final n in _otpNodes) {
      n.dispose();
    }
    _phoneFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  String get _enteredOtp => _otpCtrls.map((c) => c.text).join();

  bool _phoneValid() => _country.isValidNational(_phone.text.trim());

  void _onCountrySelected(LoginCountryOption next) {
    setState(() {
      _country = next;
      final t = _phone.text;
      if (t.length > next.maxNationalDigits) {
        _phone.text = t.substring(0, next.maxNationalDigits);
        _phone.selection = TextSelection.collapsed(offset: _phone.text.length);
      }
    });
    _saveDraft();
  }

  bool _emailOk() {
    final e = _email.text.trim();
    if (e.isEmpty) return true;
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(e);
  }

  bool _step0Valid() => _phoneValid();

  bool _step1Valid() => _enteredOtp.length == _otpLen;

  bool _step2Valid() {
    if (_name.text.trim().isEmpty) return false;
    if (_gender == null) return false;
    return _emailOk();
  }

  bool _step3Valid() => true;

  bool _step4Valid() {
    if (_idProofType == null || _idProofType!.isEmpty) return false;
    if (_idNumber.text.trim().isEmpty) return false;
    final hasFront =
        (_idFrontUrl != null && _idFrontUrl!.isNotEmpty) ||
            (_idFrontLocalPath != null && _idFrontLocalPath!.isNotEmpty);
    return hasFront;
  }

  bool _canProceedCurrentStep() {
    switch (_step) {
      case 0:
        return _step0Valid();
      case 1:
        return _step1Valid();
      case 2:
        return _step2Valid();
      case 3:
        return _step3Valid();
      case 4:
        return _step4Valid();
      default:
        return false;
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendSeconds = 30;
      _canResend = false;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
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

  Future<void> _sendOtp() async {
    if (!_step0Valid() || _sendOtpLoading) return;
    setState(() => _sendOtpLoading = true);
    try {
      final res = await UserApi.sendOtp(
        phone: _phone.text.trim(),
        countryCode: _country.dialCode,
      );
      if (!mounted) return;
      final ok = res['success'] == true || (res['_statusCode'] as int?) == 200;
      if (ok) {
        setState(() {
          _devOtpHint = res['_devOtp']?.toString();
          _step = 1;
          for (final c in _otpCtrls) {
            c.clear();
          }
        });
        _startResendTimer();
        _saveDraft();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _otpNodes.first.requestFocus();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP sent')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Failed to send OTP'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendOtpLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend || _resendLoading) return;
    setState(() => _resendLoading = true);
    try {
      final res = await UserApi.sendOtp(
        phone: _phone.text.trim(),
        countryCode: _country.dialCode,
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
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Resend failed'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _resendLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (!_step1Valid() || _verifyLoading) return;
    setState(() => _verifyLoading = true);
    try {
      final res = await UserApi.verifyOtp(
        phone: _phone.text.trim(),
        countryCode: _country.dialCode,
        otp: _enteredOtp,
        signupIntent: 'astrologer',
      );
      if (!mounted) return;
      final ok = res['success'] == true || (res['_statusCode'] as int?) == 200;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Invalid OTP'),
          ),
        );
        return;
      }

      final data = res['data'];
      if (data is Map && data['user'] is Map) {
        await AppSession.setUser(
          Map<String, dynamic>.from(data['user'] as Map),
        );
      }

      final existingUser = data is Map && data['existingUser'] == true;

      if (existingUser) {
        await _clearDraft();
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/dashboard',
          (route) => false,
        );
        return;
      }

      setState(() => _step = 2);
      await _saveDraft();
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _nameFocus.requestFocus();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _verifyLoading = false);
    }
  }

  Future<void> _pickImage(String which) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    final src =
        choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
    try {
      final x = await _picker.pickImage(source: src, imageQuality: 85);
      if (x == null || !mounted) return;
      setState(() {
        switch (which) {
          case 'profile':
            _profileLocalPath = x.path;
            _profileImageUrl = null;
            break;
          case 'idFront':
            _idFrontLocalPath = x.path;
            _idFrontUrl = null;
            break;
          case 'idBack':
            _idBackLocalPath = x.path;
            _idBackUrl = null;
            break;
        }
      });
      await _saveDraft();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick image: $e')),
        );
      }
    }
  }

  Future<ImageUploadResult> _ensureUploaded(String? local, String? url) async {
    if (url != null && url.isNotEmpty) {
      return ImageUploadResult.ok(url);
    }
    if (local == null || local.isEmpty) {
      return ImageUploadResult.ok(null);
    }
    return UploadApi.uploadImage(local);
  }

  Future<void> _submitRegister() async {
    if (!_step4Valid() || _submitLoading) return;
    setState(() => _submitLoading = true);
    try {
      final profileRes = await _ensureUploaded(
        _profileLocalPath,
        _profileImageUrl,
      );
      final frontRes = await _ensureUploaded(
        _idFrontLocalPath,
        _idFrontUrl,
      );
      final backRes = await _ensureUploaded(
        _idBackLocalPath,
        _idBackUrl,
      );

      final frontUrl = frontRes.url;
      if (!frontRes.isOk ||
          frontUrl == null ||
          frontUrl.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              frontRes.errorMessage ??
                  'Could not upload ID front image. Try a JPG/PNG or check your network.',
            ),
            duration: const Duration(seconds: 6),
          ),
        );
        return;
      }

      if (!profileRes.isOk && _profileLocalPath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profile photo: ${profileRes.errorMessage ?? "upload failed"}',
            ),
          ),
        );
      }

      final profileUrl = profileRes.url;
      final String? backUrl = backRes.isOk ? backRes.url : null;
      if (!backRes.isOk &&
          (_idBackLocalPath != null || _idBackUrl != null) &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ID back: ${backRes.errorMessage ?? "upload failed"} — continuing without it',
            ),
          ),
        );
      }

      final body = <String, dynamic>{
        'phone': _phone.text.trim(),
        'countryCode': _country.dialCode,
        'name': _name.text.trim(),
        'gender': _gender,
        'idProofType': _idProofType,
        'idProofNumber': _idNumber.text.trim(),
        'idProofImageUrl': frontUrl,
        if (backUrl != null && backUrl.isNotEmpty)
          'idProofBackImageUrl': backUrl,
        if (profileUrl != null && profileUrl.isNotEmpty)
          'profileImageUrl': profileUrl,
        if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
        if (_bio.text.trim().isNotEmpty) 'bio': _bio.text.trim(),
        if (_education != null && _education!.trim().isNotEmpty)
          'education': _education!.trim(),
        if (_experience.text.trim().isNotEmpty)
          'experienceYears': num.tryParse(_experience.text.trim()),
        if (_specialties.isNotEmpty) 'specialties': _specialties,
        if (_languages.isNotEmpty) 'languages': _languages,
        if (_skills.isNotEmpty) 'skills': _skills,
        if (_fee.text.trim().isNotEmpty)
          'consultationFeePerMin': num.tryParse(_fee.text.trim()),
      };

      final res = await AstrologerApi.register(body);
      if (!mounted) return;
      final code = res['_statusCode'] as int?;
      final ok = res['success'] == true && (code == 201 || code == 200);
      if (ok) {
        final d = res['data'];
        if (d is Map && d['user'] is Map) {
          await AppSession.setUser(
            Map<String, dynamic>.from(d['user'] as Map),
          );
        }
        await _clearDraft();
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/dashboard',
          (route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Welcome! Registration complete.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Registration failed'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitLoading = false);
    }
  }

  void _goBack() {
    if (_step <= 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _step -= 1;
      if (_step == 1) _startResendTimer();
    });
    _saveDraft();
  }

  void _onOtpChanged(int index, String value) {
    if (value.length > 1) {
      value = value[value.length - 1];
      _otpCtrls[index].text = value;
    }
    if (value.isNotEmpty) {
      if (index < _otpLen - 1) {
        _otpNodes[index + 1].requestFocus();
      } else {
        _otpNodes[index].unfocus();
      }
    }
    setState(() {});
    _saveDraft();
  }

  KeyEventResult _otpKey(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _otpCtrls[index].text.isEmpty &&
        index > 0) {
      _otpNodes[index - 1].requestFocus();
      _otpCtrls[index - 1].clear();
      setState(() {});
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _removeTag(List<String> list, String t) {
    setState(() => list.remove(t));
    _saveDraft();
  }

  String _stepPhaseLabel() {
    switch (_step) {
      case 0:
        return 'Phone number';
      case 1:
        return 'Verify OTP';
      case 2:
        return 'Basic profile';
      case 3:
        return 'Professional details';
      case 4:
        return 'ID verification';
      default:
        return '';
    }
  }

  Widget _imageTile({
    required String label,
    required String which,
    String? url,
    String? local,
  }) {
    Widget preview;
    final hasLocal = !kIsWeb &&
        local != null &&
        local.isNotEmpty &&
        File(local).existsSync();
    if (hasLocal) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Image.file(
          File(local),
          height: 120,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    } else if (url != null && url.isNotEmpty) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Image.network(
          url,
          height: 120,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, err, st) => const SizedBox(
            height: 120,
            child: Center(child: Icon(Icons.broken_image_outlined)),
          ),
        ),
      );
    } else {
      preview = Container(
        height: 100,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.inputBackgroundColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.inputBorderColor),
        ),
        child: Icon(Icons.add_photo_alternate_outlined,
            color: AppTheme.secondaryTextColor, size: 40),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        preview,
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _pickImage(which),
          icon: const Icon(Icons.upload_outlined, size: 20),
          label: const Text('Upload'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primaryColor,
            side: const BorderSide(color: AppTheme.primaryColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusPrimaryButton),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _presetTagSection({
    required String title,
    required String addLabel,
    required List<String> selected,
    required List<String> options,
  }) {
    final available =
        options.where((o) => !selected.contains(o)).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: selected
              .map(
                (t) => Chip(
                  label: Text(t),
                  onDeleted: () => _removeTag(selected, t),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        if (available.isEmpty)
          InputDecorator(
            decoration: AppOutlineInputDecoration.outline(
              labelText: addLabel,
              contentPadding: kAppMatSelectContentPadding,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'All options added',
                style: TextStyle(
                  color: AppTheme.secondaryTextColor,
                  fontSize: 15,
                ),
              ),
            ),
          )
        else
          AppMatSelectDropdown(
            key: ValueKey<String>('${title}_${selected.join('|')}'),
            labelText: addLabel,
            value: null,
            items: [
              for (final o in available)
                DropdownMenuItem<String>(value: o, child: Text(o)),
            ],
            hint: const Text('Select to add'),
            onChanged: (v) {
              if (v == null || selected.contains(v)) return;
              setState(() => selected.add(v));
              _saveDraft();
            },
          ),
      ],
    );
  }

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCountryCodeDropdown(
                  value: _country,
                  onChanged: _onCountrySelected,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppOutlineTextField(
                    key: ValueKey<String>(
                      '${_country.dialCode}_${_country.name}',
                    ),
                    controller: _phone,
                    focusNode: _phoneFocus,
                    labelText: 'Mobile number',
                    hintText: _country.resolvedHint,
                    counterText: '',
                    keyboardType: TextInputType.phone,
                    maxLength: _country.maxNationalDigits,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) {
                      setState(() {});
                      _saveDraft();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!_phoneValid() && _phone.text.isNotEmpty)
              Text(
                _country.validationMessage(),
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 12,
                ),
              ),
            const SizedBox(height: 20),
            AppPrimaryButton(
              onPressed:
                  _step0Valid() && !_sendOtpLoading ? _sendOtp : null,
              child: _sendOtpLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('SEND OTP'),
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter 6-digit code',
              style: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_otpLen, (index) {
                return SizedBox(
                  width: 44,
                  child: Focus(
                    onKeyEvent: (_, e) => _otpKey(index, e),
                    child: TextField(
                      controller: _otpCtrls[index],
                      focusNode: _otpNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (v) => _onOtpChanged(index, v),
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusPrimaryButton,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusPrimaryButton,
                          ),
                          borderSide: const BorderSide(
                            color: AppTheme.inputBorderColor,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusPrimaryButton,
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
            if (_devOtpHint != null && _devOtpHint!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Text(
                  'Dev OTP: $_devOtpHint',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const SizedBox(height: 24),
            AppPrimaryButton(
              onPressed: _step1Valid() && !_verifyLoading && !_sendOtpLoading
                  ? _verifyOtp
                  : null,
              disabledBackgroundColor: AppTheme.buttonInactiveColor,
              disabledForegroundColor: AppTheme.buttonInactiveTextColor,
              child: _verifyLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('VERIFY OTP'),
            ),
            const SizedBox(height: 12),
            AppPrimaryButton(
              onPressed: (_canResend && !_resendLoading) ? _resendOtp : null,
              disabledBackgroundColor: AppTheme.buttonInactiveColor,
              disabledForegroundColor: AppTheme.buttonInactiveTextColor,
              child: _resendLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _canResend
                          ? 'Resend OTP'
                          : 'Resend in $_resendSeconds s',
                    ),
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppOutlineTextField(
              controller: _name,
              focusNode: _nameFocus,
              labelText: 'Full name *',
              textCapitalization: TextCapitalization.words,
              onChanged: (_) {
                setState(() {});
                _saveDraft();
              },
            ),
            const SizedBox(height: 12),
            AppOutlineTextField(
              controller: _email,
              labelText: 'Email',
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) {
                setState(() {});
                _saveDraft();
              },
            ),
            if (!_emailOk() && _email.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Invalid email',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),
            AppMatSelectDropdown(
              labelText: 'Gender *',
              value: _gender,
              hint: const Text('Select'),
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) {
                setState(() => _gender = v);
                _saveDraft();
              },
            ),
            const SizedBox(height: 20),
            _imageTile(
              label: 'Profile photo',
              which: 'profile',
              url: _profileImageUrl,
              local: _profileLocalPath,
            ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppOutlineTextField(
              controller: _bio,
              labelText: 'Bio',
              maxLines: 4,
              decoration: AppOutlineInputDecoration.outline(
                labelText: 'Bio',
              ).copyWith(alignLabelWithHint: true),
              onChanged: (_) => _saveDraft(),
            ),
            const SizedBox(height: 12),
            AppOutlineTextField(
              controller: _experience,
              labelText: 'Experience (years)',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _saveDraft(),
            ),
            const SizedBox(height: 12),
            AppMatSelectDropdown.strings(
              labelText: 'Higher education',
              value: _education,
              options: kAstrologerEducationOptions,
              hint: const Text('Select'),
              onChanged: (v) {
                setState(() => _education = v);
                _saveDraft();
              },
            ),
            const SizedBox(height: 16),
            _presetTagSection(
              title: 'Specialties',
              addLabel: 'Add specialty',
              selected: _specialties,
              options: kAstrologerSpecialtyOptions,
            ),
            const SizedBox(height: 16),
            _presetTagSection(
              title: 'Languages',
              addLabel: 'Add language',
              selected: _languages,
              options: kAstrologerLanguageOptions,
            ),
            const SizedBox(height: 16),
            _presetTagSection(
              title: 'Skills',
              addLabel: 'Add skill',
              selected: _skills,
              options: kAstrologerSkillOptions,
            ),
            const SizedBox(height: 12),
            AppOutlineTextField(
              controller: _fee,
              labelText: 'Fee per minute (₹)',
              prefix: const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Text(
                  '₹',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _saveDraft(),
            ),
          ],
        );
      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppMatSelectDropdown(
              labelText: 'ID proof type *',
              value: _idProofType,
              hint: const Text('Select document'),
              items: [
                for (final e in _idProofOptions.entries)
                  DropdownMenuItem<String>(
                    value: e.key,
                    child: Text(e.value),
                  ),
              ],
              onChanged: (v) {
                setState(() => _idProofType = v);
                _saveDraft();
              },
            ),
            const SizedBox(height: 12),
            AppOutlineTextField(
              controller: _idNumber,
              labelText: 'ID number *',
              onChanged: (_) {
                setState(() {});
                _saveDraft();
              },
            ),
            const SizedBox(height: 16),
            _imageTile(
              label: 'ID front *',
              which: 'idFront',
              url: _idFrontUrl,
              local: _idFrontLocalPath,
            ),
            const SizedBox(height: 16),
            _imageTile(
              label: 'ID back (optional)',
              which: 'idBack',
              url: _idBackUrl,
              local: _idBackLocalPath,
            ),
            const SizedBox(height: 24),
            AppPrimaryButton(
              onPressed:
                  _step4Valid() && !_submitLoading ? _submitRegister : null,
              child: _submitLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('COMPLETE REGISTRATION'),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
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
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _goBack,
                      style: IconButton.styleFrom(
                        backgroundColor:
                            AppTheme.surfaceColor.withValues(alpha: 0.9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusPrimaryButton,
                          ),
                        ),
                        padding: const EdgeInsets.all(8),
                      ),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _stepPhaseLabel(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.secondaryTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
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
                        if (_step >= 2) ...[
                          Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryColor
                                          .withValues(alpha: 0.16),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                      spreadRadius: -4,
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  AppAssets.logo,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'AstroLoger',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    Text(
                                      'Step ${_step + 1} of 5',
                                      style: TextStyle(
                                        color: AppTheme.secondaryTextColor,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                        _stepBody(),
                        if (_step >= 2 && _step < 4) ...[
                          const SizedBox(height: 24),
                          AppPrimaryButton(
                            onPressed: _canProceedCurrentStep()
                                ? () {
                                    setState(() => _step += 1);
                                    _saveDraft();
                                    if (_step == 3) {
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                        if (mounted) {
                                          _bio.selection = TextSelection
                                              .fromPosition(
                                            TextPosition(
                                                offset: _bio.text.length),
                                          );
                                        }
                                      });
                                    }
                                  }
                                : null,
                            disabledBackgroundColor: AppTheme.buttonInactiveColor,
                            disabledForegroundColor:
                                AppTheme.buttonInactiveTextColor,
                            child: const Text('NEXT'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
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
