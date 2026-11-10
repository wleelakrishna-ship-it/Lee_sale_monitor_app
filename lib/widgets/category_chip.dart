import 'package:flutter/material.dart';

import '../models/category_rate.dart';
import '../utils/formatters.dart';

class CategoryChip extends StatelessWidget {
  final CategoryRate rate;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const CategoryChip({
    super.key,
    required this.rate,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text('${rate.category} • ${formatCurrency(rate.ratePerKg)}/kg'),
      selected: selected,
      onSelected: onSelected,
    );
  }
}
