import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_primary_button.dart';

class BirthPlaceStep extends StatefulWidget {
  final String initialPlace;
  final ValueChanged<String?> onSave;
  final VoidCallback onNext;

  const BirthPlaceStep({
    super.key,
    this.initialPlace = '',
    required this.onSave,
    required this.onNext,
  });

  @override
  State<BirthPlaceStep> createState() => _BirthPlaceStepState();
}

class _BirthPlaceStepState extends State<BirthPlaceStep> {
  late final TextEditingController _placeController;

  @override
  void initState() {
    super.initState();
    _placeController = TextEditingController(
      text: widget.initialPlace.isEmpty ? 'Jaipur, RJ, India' : widget.initialPlace,
    );
  }

  @override
  void dispose() {
    _placeController.dispose();
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
            'Where were you born?',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'City, state and country for accurate chart',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _placeController,
            style: const TextStyle(fontSize: 16),
            decoration: const InputDecoration(
              hintText: 'Search or enter place',
              prefixIcon: Icon(
                Icons.location_on_outlined,
                color: AppTheme.secondaryTextColor,
                size: 22,
              ),
              suffixIcon: Icon(
                Icons.search_rounded,
                color: AppTheme.primaryColor,
                size: 22,
              ),
            ),
          ),
          const SizedBox(height: 32),
          AppPrimaryButton(
            width: double.infinity,
            height: 52,
            onPressed: () {
              widget.onSave(_placeController.text.trim().isEmpty
                  ? null
                  : _placeController.text.trim());
              widget.onNext();
            },
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }
}
