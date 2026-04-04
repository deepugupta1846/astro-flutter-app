import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_primary_button.dart';

class LanguageStep extends StatefulWidget {
  final List<String> initialSelected;
  final ValueChanged<List<String>?> onSave;
  final ValueChanged<List<String>?> onNext;
  final bool isLoading;

  const LanguageStep({
    super.key,
    this.initialSelected = const [],
    required this.onSave,
    required this.onNext,
    this.isLoading = false,
  });

  @override
  State<LanguageStep> createState() => _LanguageStepState();
}

class _LanguageStepState extends State<LanguageStep> {
  final _languages = [
    'English', 'Hindi', 'Bengali', 'Gujarati', 'Kannada',
    'Malayalam', 'Marathi', 'Punjabi', 'Tamil', 'Telugu', 'Urdu',
  ];
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initialSelected);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select all your languages',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll match you with astrologers who speak your language.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _languages.map((lang) {
              final isSelected = _selected.contains(lang);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selected.remove(lang);
                    } else {
                      _selected.add(lang);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.inputBorderColor,
                      width: isSelected ? 0 : 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        lang,
                        style: TextStyle(
                          color: isSelected
                              ? AppTheme.primaryTextColor
                              : AppTheme.primaryTextColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isSelected ? Icons.check_circle_rounded : Icons.add_rounded,
                        size: 20,
                        color: isSelected
                            ? AppTheme.successColor
                            : AppTheme.secondaryTextColor,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          AppPrimaryButton(
            width: double.infinity,
            height: 52,
            onPressed: widget.isLoading
                ? null
                : () {
                    final list = _selected.toList();
                    widget.onSave(list);
                    widget.onNext(list);
                  },
            disabledBackgroundColor: AppTheme.buttonInactiveColor,
            disabledForegroundColor: AppTheme.buttonInactiveTextColor,
            child: widget.isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.buttonPrimaryTextColor,
                    ),
                  )
                : const Text('Start chat with Astrologer'),
          ),
        ],
      ),
    );
  }
}
