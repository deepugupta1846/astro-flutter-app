import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/api/user_api.dart';
import '../../core/session/app_session.dart';
import 'steps/name_step.dart';
import 'steps/gender_step.dart';
import 'steps/know_birth_time_step.dart';
import 'steps/birth_time_step.dart';
import 'steps/birth_date_step.dart';
import 'steps/birth_place_step.dart';
import 'steps/language_step.dart';

class DetailsFlowScreen extends StatefulWidget {
  final String phone;
  final String countryCode;

  const DetailsFlowScreen({
    super.key,
    required this.phone,
    this.countryCode = '+91',
  });

  @override
  State<DetailsFlowScreen> createState() => _DetailsFlowScreenState();
}

class _DetailsFlowScreenState extends State<DetailsFlowScreen> {
  int _currentStep = 0;
  bool? _knowTimeOfBirth;
  final int _totalSteps = 7;

  // Signup data collected from steps
  String _name = '';
  String? _gender;
  String _birthTime = '';
  String _birthDate = '';
  String _birthPlace = '';
  List<String> _languages = [];
  bool _isSubmitting = false;

  void _nextStep() {
    if (_currentStep >= _totalSteps - 1) {
      _submitSignup();
      return;
    }
    setState(() {
      if (_currentStep == 2 && _knowTimeOfBirth == false) {
        _currentStep = 4;
      } else {
        _currentStep++;
      }
    });
  }

  Future<void> _submitSignup({List<String>? languagesOverride}) async {
    if (_isSubmitting) return;
    if (widget.phone.isEmpty) {
      // Skipped login: go to dashboard without API
      Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
      return;
    }
    final languages = languagesOverride ?? _languages;
    setState(() => _isSubmitting = true);
    try {
      final res = await UserApi.signup(
        phone: widget.phone,
        countryCode: widget.countryCode,
        name: _name.isEmpty ? null : _name,
        gender: _gender,
        knowBirthTime: _knowTimeOfBirth,
        birthTime: _birthTime.isEmpty ? null : _birthTime,
        birthDate: _birthDate.isEmpty ? null : _birthDate,
        birthPlace: _birthPlace.isEmpty ? null : _birthPlace,
        languages: languages.isEmpty ? null : languages,
      );
      if (!mounted) return;
      final ok = res['success'] == true || (res['_statusCode'] as int?) == 201;
      if (ok) {
        final d = res['data'];
        if (d is Map && d['user'] is Map) {
          await AppSession.setUser(
            Map<String, dynamic>.from(d['user'] as Map),
          );
        }
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Signup failed')),
        );
      }
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

  void _onKnowTimeOfBirth(bool? value) {
    setState(() => _knowTimeOfBirth = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Container(
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
              AppBar(
                backgroundColor: Colors.transparent,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new, size: 18),
                  ),
                  onPressed: () {
                    if (_currentStep > 0) {
                      setState(() {
                        if (_currentStep == 4 && _knowTimeOfBirth == false) {
                          _currentStep = 2;
                        } else {
                          _currentStep--;
                        }
                      });
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                title: Text(
                  'Enter Your Details',
                  style: Theme.of(context).appBarTheme.titleTextStyle,
                ),
                centerTitle: true,
              ),
              _buildProgressIndicator(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  child: _buildStepContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final icons = [
      Icons.person_outline_rounded,
      Icons.female_rounded,
      Icons.schedule_rounded,
      Icons.access_time_rounded,
      Icons.calendar_today_rounded,
      Icons.location_on_outlined,
      Icons.translate_rounded,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: List.generate(_totalSteps * 2 - 1, (index) {
          if (index.isOdd) {
            final stepIndex = index ~/ 2;
            final isFilled = stepIndex < _currentStep;
            return Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isFilled
                      ? AppTheme.progressActiveColor
                      : AppTheme.progressInactiveColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            );
          }
          final stepIndex = index ~/ 2;
          final isActive = stepIndex == _currentStep;
          final isCompleted = stepIndex < _currentStep;
          return Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive || isCompleted
                  ? AppTheme.progressActiveColor
                  : AppTheme.progressInactiveColor,
              shape: BoxShape.circle,
              border: isActive
                  ? Border.all(color: AppTheme.primaryTextColor, width: 2)
                  : null,
            ),
            child: Icon(
              icons[stepIndex],
              size: 20,
              color: isActive || isCompleted
                  ? AppTheme.primaryTextColor
                  : AppTheme.secondaryTextColor,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return NameStep(
          initialName: _name,
          onSave: (v) => setState(() => _name = v ?? ''),
          onNext: _nextStep,
        );
      case 1:
        return GenderStep(
          onSave: (v) => setState(() => _gender = v),
          onNext: _nextStep,
        );
      case 2:
        return KnowBirthTimeStep(
          onNext: _nextStep,
          onKnowTimeOfBirth: _onKnowTimeOfBirth,
        );
      case 3:
        return BirthTimeStep(
          onSave: (v) => setState(() => _birthTime = v ?? ''),
          onNext: _nextStep,
        );
      case 4:
        return BirthDateStep(
          onSave: (v) => setState(() => _birthDate = v ?? ''),
          onNext: _nextStep,
        );
      case 5:
        return BirthPlaceStep(
          initialPlace: _birthPlace,
          onSave: (v) => setState(() => _birthPlace = v ?? ''),
          onNext: _nextStep,
        );
      case 6:
        return LanguageStep(
          initialSelected: _languages,
          onSave: (v) => setState(() => _languages = v ?? []),
          onNext: (list) {
            if (list != null && list.isNotEmpty) setState(() => _languages = list);
            _submitSignup(languagesOverride: list);
          },
          isLoading: _isSubmitting,
        );
      default:
        return const SizedBox();
    }
  }
}
