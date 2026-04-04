import 'dart:convert';

import 'package:flutter/material.dart';
import '../../core/api/user_api.dart';
import '../../core/constants/profile_languages.dart';
import '../../core/session/app_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_outline_input.dart';
import '../../core/widgets/app_primary_button.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _birthTimeCtrl;
  late final TextEditingController _birthPlaceCtrl;
  String? _gender;
  bool? _knowBirthTime;
  DateTime? _birthDate;
  late Set<String> _languages;
  bool _saving = false;

  static List<String> _parseLanguages(dynamic v) {
    if (v is List) {
      return v.map((e) => e.toString()).toList();
    }
    if (v is String && v.isNotEmpty) {
      try {
        final d = jsonDecode(v);
        if (d is List) return d.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return [];
  }

  static DateTime? _parseBirthDate(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    if (s.length >= 10) {
      try {
        return DateTime.parse(s.substring(0, 10));
      } catch (_) {}
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nameCtrl = TextEditingController(text: u['name']?.toString() ?? '');
    _emailCtrl = TextEditingController(text: u['email']?.toString() ?? '');
    _birthTimeCtrl = TextEditingController(text: u['birthTime']?.toString() ?? '');
    _birthPlaceCtrl = TextEditingController(text: u['birthPlace']?.toString() ?? '');
    final g = u['gender']?.toString();
    _gender = (g != null && g.isNotEmpty) ? g : null;
    final kbt = u['knowBirthTime'];
    if (kbt is bool) {
      _knowBirthTime = kbt;
    } else {
      _knowBirthTime = null;
    }
    _birthDate = _parseBirthDate(u['birthDate']);
    _languages = Set<String>.from(_parseLanguages(u['languages']));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _birthTimeCtrl.dispose();
    _birthPlaceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: AppTheme.onPrimaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  int? _resolveUserId() {
    final a = AppSession.userId;
    if (a != null) return a;
    final i = widget.user['id'];
    if (i is int) return i;
    if (i is num) return i.toInt();
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final id = _resolveUserId();
    if (id == null) return;

    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'name': _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'gender': _gender,
        'knowBirthTime': _knowBirthTime,
        'birthTime': _birthTimeCtrl.text.trim().isEmpty ? null : _birthTimeCtrl.text.trim(),
        'birthPlace': _birthPlaceCtrl.text.trim().isEmpty ? null : _birthPlaceCtrl.text.trim(),
        'birthDate': _birthDate == null
            ? null
            : '${_birthDate!.year.toString().padLeft(4, '0')}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}',
        'languages': _languages.toList(),
      };

      final res = await UserApi.updateUser(id, body);
      if (!mounted) return;
      final ok = res['success'] == true || (res['_statusCode'] as int?) == 200;
      if (ok && res['data'] is Map) {
        await AppSession.setUser(Map<String, dynamic>.from(res['data'] as Map));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated')),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Update failed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppTheme.surfaceColor,
            foregroundColor: AppTheme.primaryTextColor,
            title: const Text('Edit profile'),
            actions: [
              TextButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            sliver: SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _card(
                      context,
                      'Basic',
                      Icons.person_outline_rounded,
                      [
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: AppOutlineInputDecoration.outline(
                            labelText: 'Full name',
                          ),
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailCtrl,
                          decoration: AppOutlineInputDecoration.outline(
                            labelText: 'Email',
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            if (!v.contains('@')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _card(
                      context,
                      'Birth details',
                      Icons.cake_outlined,
                      [
                        DropdownButtonFormField<String?>(
                          value: _gender,
                          decoration: AppOutlineInputDecoration.outline(
                            labelText: 'Gender',
                          ),
                          items: const [
                            DropdownMenuItem(value: null, child: Text('Prefer not to say')),
                            DropdownMenuItem(value: 'male', child: Text('Male')),
                            DropdownMenuItem(value: 'female', child: Text('Female')),
                            DropdownMenuItem(value: 'other', child: Text('Other')),
                          ],
                          onChanged: (v) => setState(() => _gender = v),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _knowTriStateKey(),
                          decoration: AppOutlineInputDecoration.outline(
                            labelText: 'Know exact birth time?',
                          ),
                          items: const [
                            DropdownMenuItem(value: 'unset', child: Text('Not specified')),
                            DropdownMenuItem(value: 'yes', child: Text('Yes')),
                            DropdownMenuItem(value: 'no', child: Text('No')),
                          ],
                          onChanged: (v) {
                            setState(() {
                              if (v == 'unset') {
                                _knowBirthTime = null;
                              } else if (v == 'yes') {
                                _knowBirthTime = true;
                              } else {
                                _knowBirthTime = false;
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _birthTimeCtrl,
                          decoration: AppOutlineInputDecoration.outline(
                            labelText: 'Birth time (e.g. 11:43 AM)',
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Birth date'),
                          subtitle: Text(
                            _birthDate == null
                                ? 'Tap to choose'
                                : '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}',
                            style: TextStyle(
                              color: _birthDate == null
                                  ? AppTheme.hintTextColor
                                  : AppTheme.primaryTextColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: const Icon(Icons.calendar_today_rounded),
                          onTap: _pickDate,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            side: const BorderSide(color: AppTheme.inputBorderColor),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _birthPlaceCtrl,
                          decoration: AppOutlineInputDecoration.outline(
                            labelText: 'Birth place',
                          ),
                          textCapitalization: TextCapitalization.words,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _card(
                      context,
                      'Languages',
                      Icons.language_rounded,
                      [
                        Text(
                          'Select languages you speak',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.secondaryTextColor,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: kProfileLanguageOptions.map((lang) {
                            final sel = _languages.contains(lang);
                            return FilterChip(
                              label: Text(lang),
                              selected: sel,
                              onSelected: (v) {
                                setState(() {
                                  if (v) {
                                    _languages.add(lang);
                                  } else {
                                    _languages.remove(lang);
                                  }
                                });
                              },
                              selectedColor: AppTheme.primaryColor.withValues(alpha: 0.35),
                              checkmarkColor: AppTheme.primaryTextColor,
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(color: AppTheme.inputBorderColor),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.phone_android_rounded, color: AppTheme.secondaryTextColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mobile number',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppTheme.secondaryTextColor,
                                      ),
                                ),
                                Text(
                                  AppSession.phoneLine.isEmpty
                                      ? '${widget.user['countryCode'] ?? '+91'} ${widget.user['phone'] ?? ''}'
                                      : AppSession.phoneLine,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'Read-only',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.secondaryTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    AppPrimaryButton(
                      onPressed: _saving ? null : _save,
                      disabledBackgroundColor: AppTheme.buttonInactiveColor,
                      disabledForegroundColor: AppTheme.buttonInactiveTextColor,
                      child: _saving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.buttonPrimaryTextColor,
                              ),
                            )
                          : const Text('Save changes'),
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

  String _knowTriStateKey() {
    if (_knowBirthTime == null) return 'unset';
    return _knowBirthTime! ? 'yes' : 'no';
  }

  Widget _card(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.primaryDark, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}
