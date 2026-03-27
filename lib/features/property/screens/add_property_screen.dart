import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../services/supabase_service.dart';
import '../providers/properties_provider.dart';

class AddPropertyScreen extends ConsumerStatefulWidget {
  const AddPropertyScreen({
    required this.organizationId,
    super.key,
  });

  final String organizationId;

  @override
  ConsumerState<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends ConsumerState<AddPropertyScreen> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final List<String> _propertyTypes = const [
    'Residential',
    'Commercial',
    'Industrial',
    'Mixed Use',
  ];
  String _selectedPropertyType = 'Residential';
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _saveProperty() async {
    final name = _nameController.text.trim();
    final location = _locationController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Plot name is required.',
            style: TextStyle(fontFamily: AppTheme.appFontFamily),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await SupabaseService.instance.createProperty(
        organizationId: widget.organizationId,
        name: name,
        location: location,
        propertyType: _selectedPropertyType,
      );

      if (!mounted) return;

      ref.invalidate(propertiesProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Plot saved successfully!',
            style: TextStyle(fontFamily: AppTheme.appFontFamily),
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to save plot: $error',
            style: const TextStyle(fontFamily: AppTheme.appFontFamily),
          ),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add New Plot',
          style: TextStyle(fontFamily: AppTheme.appFontFamily),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'Plot Name',
                labelText: 'Plot Name',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                hintText: 'Location',
                labelText: 'Location',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedPropertyType,
              dropdownColor: AppTheme.surfaceColor,
              decoration: const InputDecoration(
                hintText: 'Property Type',
                labelText: 'Property Type',
              ),
              style: const TextStyle(
                fontFamily: AppTheme.appFontFamily,
                color: Colors.white,
              ),
              items: _propertyTypes
                  .map(
                    (type) => DropdownMenuItem<String>(
                      value: type,
                      child: Text(
                        type,
                        style: const TextStyle(
                          fontFamily: AppTheme.appFontFamily,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _isSaving
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedPropertyType = value;
                      });
                    },
            ),
            if (_selectedPropertyType == 'Residential') ...[
              const SizedBox(height: 10),
              const Text(
                'Residential plots support bedroom-based unit type occupancy policies.',
                style: TextStyle(
                  fontFamily: AppTheme.appFontFamily,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveProperty,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Save Plot',
                      style: TextStyle(fontFamily: AppTheme.appFontFamily),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
