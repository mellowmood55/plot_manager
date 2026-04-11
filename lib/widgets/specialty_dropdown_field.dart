import 'package:flutter/material.dart';

import '../core/theme.dart';

class SpecialtyDropdownField extends StatefulWidget {
  const SpecialtyDropdownField({
    required this.controller,
    this.onChanged,
    this.validator,
    super.key,
  });

  static const List<String> defaultSpecialties = [
    'Plumbing',
    'Electrical',
    'Painting',
    'Carpentry',
    'Masonry',
    'HVAC',
    'Roofing',
    'Landscaping',
    'Flooring',
    'Drywall',
    'Tile Work',
    'Concrete',
    'General Handyman',
  ];

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;

  @override
  State<SpecialtyDropdownField> createState() => _SpecialtyDropdownFieldState();
}

class _SpecialtyDropdownFieldState extends State<SpecialtyDropdownField> {
  late String _selectedSpecialty;

  @override
  void initState() {
    super.initState();
    _selectedSpecialty = _resolveInitialSpecialty();
    widget.controller.text = _selectedSpecialty;
  }

  @override
  void didUpdateWidget(covariant SpecialtyDropdownField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final latest = _resolveInitialSpecialty();
    if (latest != _selectedSpecialty) {
      setState(() {
        _selectedSpecialty = latest;
      });
      widget.controller.text = latest;
    }
  }

  String _resolveInitialSpecialty() {
    final raw = widget.controller.text.trim();
    if (raw.isEmpty) {
      return 'General Handyman';
    }
    return raw;
  }

  List<String> _buildItems() {
    final items = <String>[...SpecialtyDropdownField.defaultSpecialties];
    if (!items.contains(_selectedSpecialty)) {
      items.insert(0, _selectedSpecialty);
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildItems();

    return DropdownButtonFormField<String>(
      initialValue: _selectedSpecialty,
      decoration: const InputDecoration(
        labelText: 'Specialty',
      ),
      dropdownColor: Theme.of(context).colorScheme.surface,
      iconEnabledColor: AppTheme.primaryColor,
      style: const TextStyle(
        fontFamily: AppTheme.appFontFamily,
        color: Colors.white,
      ),
      items: items
          .map(
            (specialty) => DropdownMenuItem<String>(
              value: specialty,
              child: Text(
                specialty,
                style: const TextStyle(fontFamily: AppTheme.appFontFamily),
              ),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) {
          return;
        }
        setState(() {
          _selectedSpecialty = value;
        });
        widget.controller.text = value;
        widget.onChanged?.call(value);
      },
      validator: widget.validator ??
          (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Specialty is required';
            }
            return null;
          },
    );
  }
}
