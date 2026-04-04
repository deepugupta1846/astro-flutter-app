import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_primary_button.dart';

class NameStep extends StatefulWidget {
  final String initialName;
  final ValueChanged<String?> onSave;
  final VoidCallback onNext;

  const NameStep({
    super.key,
    this.initialName = '',
    required this.onSave,
    required this.onNext,
  });

  @override
  State<NameStep> createState() => _NameStepState();
}

class _NameStepState extends State<NameStep> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
            'Hey there!',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.secondaryTextColor,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'What is your name?',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _nameController,
            style: const TextStyle(fontSize: 16),
            decoration: const InputDecoration(
              hintText: 'Enter your name',
              prefixIcon: Icon(Icons.person_outline_rounded, color: AppTheme.secondaryTextColor, size: 22),
            ),
          ),
          const SizedBox(height: 32),
          AppPrimaryButton(
            width: double.infinity,
            height: 52,
            onPressed: () {
              widget.onSave(_nameController.text.trim().isEmpty
                  ? null
                  : _nameController.text.trim());
              widget.onNext();
            },
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }
}
