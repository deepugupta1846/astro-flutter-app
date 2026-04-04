import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_primary_button.dart';

class BirthTimeStep extends StatefulWidget {
  final ValueChanged<String?> onSave;
  final VoidCallback onNext;

  const BirthTimeStep({super.key, required this.onSave, required this.onNext});

  @override
  State<BirthTimeStep> createState() => _BirthTimeStepState();
}

class _BirthTimeStepState extends State<BirthTimeStep> {
  int _hour = 11;
  int _minute = 43;
  bool _isAm = true;
  bool _dontKnow = false;

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
            'Enter your birth time',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildWheel(
                  items: List.generate(12, (i) => (i + 1).toString()),
                  value: _hour.toString(),
                  onChanged: (v) => setState(() => _hour = int.parse(v)),
                ),
                Text(
                  ':',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                _buildWheel(
                  items:
                      List.generate(60, (i) => i.toString().padLeft(2, '0')),
                  value: _minute.toString().padLeft(2, '0'),
                  onChanged: (v) =>
                      setState(() => _minute = int.parse(v)),
                ),
                const SizedBox(width: 12),
                _buildWheel(
                  items: const ['AM', 'PM'],
                  value: _isAm ? 'AM' : 'PM',
                  onChanged: (v) => setState(() => _isAm = v == 'AM'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _dontKnow = !_dontKnow),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      _dontKnow
                          ? Icons.check_box_rounded
                          : Icons.check_box_outlined,
                      color: _dontKnow
                          ? AppTheme.primaryColor
                          : AppTheme.secondaryTextColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Don't know my exact time of birth",
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'We can still give up to 80% accurate predictions without it.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 28),
          AppPrimaryButton(
            width: double.infinity,
            height: 52,
            onPressed: () {
              final timeStr = _dontKnow
                  ? ''
                  : '$_hour:${_minute.toString().padLeft(2, '0')} ${_isAm ? 'AM' : 'PM'}';
              widget.onSave(timeStr.isEmpty ? null : timeStr);
              widget.onNext();
            },
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  Widget _buildWheel({
    required List<String> items,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: 56,
      height: 132,
      child: ListView.builder(
        itemCount: items.length,
        itemExtent: 44,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemBuilder: (context, i) {
          final isSelected = items[i] == value;
          return GestureDetector(
            onTap: () => onChanged(items[i]),
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                style: TextStyle(
                  fontSize: isSelected ? 20 : 16,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected
                      ? AppTheme.primaryTextColor
                      : AppTheme.secondaryTextColor,
                ),
                child: Text(items[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}
