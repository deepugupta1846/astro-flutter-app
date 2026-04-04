import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_primary_button.dart';

class BirthDateStep extends StatefulWidget {
  final ValueChanged<String?> onSave;
  final VoidCallback onNext;

  const BirthDateStep({super.key, required this.onSave, required this.onNext});

  @override
  State<BirthDateStep> createState() => _BirthDateStepState();
}

class _BirthDateStepState extends State<BirthDateStep> {
  DateTime _selectedDate = DateTime(2000, 7, 15);

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  Widget build(BuildContext context) {
    final days =
        List.generate(31, (i) => (i + 1).toString());
    final years =
        List.generate(50, (i) => (2005 - i).toString());

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
            'Enter your birth date',
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
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildColumn(
                  items: _months,
                  value: _months[_selectedDate.month - 1],
                  onChanged: (v) {
                    final m = _months.indexOf(v) + 1;
                    setState(() {
                      _selectedDate = DateTime(
                        _selectedDate.year,
                        m,
                        _selectedDate.day.clamp(
                            1, DateTime(_selectedDate.year, m + 1, 0).day),
                      );
                    });
                  },
                ),
                _buildColumn(
                  items: days,
                  value: _selectedDate.day.toString(),
                  onChanged: (v) => setState(() => _selectedDate = DateTime(
                        _selectedDate.year,
                        _selectedDate.month,
                        int.parse(v),
                      )),
                ),
                _buildColumn(
                  items: years,
                  value: _selectedDate.year.toString(),
                  onChanged: (v) => setState(() => _selectedDate = DateTime(
                        int.parse(v),
                        _selectedDate.month,
                        _selectedDate.day,
                      )),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          AppPrimaryButton(
            width: double.infinity,
            height: 52,
            onPressed: () {
              final d = _selectedDate;
              widget.onSave(
                  '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
              widget.onNext();
            },
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  Widget _buildColumn({
    required List<String> items,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: 72,
      height: 160,
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
                  fontSize: isSelected ? 17 : 14,
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
