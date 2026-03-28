import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme.dart';
import '../../../models/contractor.dart';
import '../../../models/maintenance_request.dart';
import '../../../services/maintenance_service.dart';

class AddMaintenanceScreen extends StatefulWidget {
  final String? unitId;

  const AddMaintenanceScreen({super.key, this.unitId});

  @override
  State<AddMaintenanceScreen> createState() => _AddMaintenanceScreenState();
}

class _AddMaintenanceScreenState extends State<AddMaintenanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _estimatedCostController = TextEditingController();
  final _categoryController = TextEditingController(text: 'General');

  MaintenancePriority _selectedPriority = MaintenancePriority.medium;
  File? _selectedImage;
  bool _isUploading = false;
  String? _selectedUnitId;
  String? _selectedContractorId;
  bool _isContractorsLoading = true;
  List<Contractor> _contractors = [];
  String? _selectedTemplateLabel;

  static const List<_MaintenanceTemplate> _templates = [
    _MaintenanceTemplate(
      label: 'Leaking Tap',
      title: 'Leaking Tap in Unit',
      category: 'Plumbing',
      estimatedCost: 2500,
    ),
    _MaintenanceTemplate(
      label: 'Socket Repair',
      title: 'Electrical Socket Not Working',
      category: 'Electrical',
      estimatedCost: 1800,
    ),
    _MaintenanceTemplate(
      label: 'Painting',
      title: 'Wall Repainting Required',
      category: 'Painting',
      estimatedCost: 12000,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedUnitId = widget.unitId;
    _loadContractors();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _estimatedCostController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _loadContractors() async {
    setState(() {
      _isContractorsLoading = true;
    });

    try {
      final contractors = await MaintenanceService.instance.getContractors();
      if (!mounted) return;
      setState(() {
        _contractors = contractors;
        _isContractorsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isContractorsLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            'Failed to load contractors: $error',
            style: const TextStyle(
              fontFamily: AppTheme.appFontFamily,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
  }

  void _applyTemplate(_MaintenanceTemplate template) {
    setState(() {
      _selectedTemplateLabel = template.label;
      _titleController.text = template.title;
      _categoryController.text = template.category;
      _estimatedCostController.text = template.estimatedCost.toStringAsFixed(2);
    });
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.camera);

      if (pickedFile != null && mounted) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            'Failed to pick image: $e',
            style: const TextStyle(
              fontFamily: AppTheme.appFontFamily,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedUnitId == null || _selectedUnitId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            'Please open this form from a unit and try again.',
            style: TextStyle(fontFamily: AppTheme.appFontFamily),
          ),
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      String? imageUrl;

      if (_selectedImage != null) {
        try {
          final fileName = await MaintenanceService.instance.uploadMaintenanceImage(
            _selectedImage!,
            _selectedUnitId!,
            'temp_${DateTime.now().millisecondsSinceEpoch}',
          );
          imageUrl = MaintenanceService.instance.getImageUrl(fileName);
        } catch (uploadError) {
          if (!mounted) return;
          setState(() => _isUploading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade700,
              content: Text(
                'Photo upload failed. Please try again. Details: $uploadError',
                style: const TextStyle(
                  fontFamily: AppTheme.appFontFamily,
                  color: Colors.white,
                ),
              ),
            ),
          );
          return;
        }
      }

      final estimatedCost = _estimatedCostController.text.isEmpty
          ? null
          : double.tryParse(_estimatedCostController.text);

      await MaintenanceService.instance.createMaintenanceRequest(
        unitId: _selectedUnitId!,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _categoryController.text.trim(),
        priority: _selectedPriority,
        estimatedCost: estimatedCost,
        imageUrl: imageUrl,
        contractorId: _selectedContractorId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Maintenance request created successfully!',
            style: TextStyle(
              fontFamily: AppTheme.appFontFamily,
              color: Colors.white,
            ),
          ),
          backgroundColor: Color(0xFF0D9488),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            'Error creating request: $e',
            style: const TextStyle(
              fontFamily: AppTheme.appFontFamily,
              color: Colors.white,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Report Maintenance Issue',
          style: TextStyle(fontFamily: AppTheme.appFontFamily),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Quick Select (Kenyan Common Repairs)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontFamily: AppTheme.appFontFamily,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _templates.map((template) {
                  final isSelected = _selectedTemplateLabel == template.label;
                  return ChoiceChip(
                    selected: isSelected,
                    label: Text(
                      template.label,
                      style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                    ),
                    onSelected: (_) => _applyTemplate(template),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Issue Title',
                  hintText: 'e.g., Leaky Faucet, Broken Window',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _categoryController,
                decoration: InputDecoration(
                  labelText: 'Category',
                  hintText: 'Plumbing, Electrical, Painting',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Category is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Provide details about the issue',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<MaintenancePriority>(
                initialValue: _selectedPriority,
                decoration: InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                items: MaintenancePriority.values.map((priority) {
                  return DropdownMenuItem(
                    value: priority,
                    child: Text(
                      priority.displayName,
                      style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedPriority = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: _selectedContractorId,
                decoration: InputDecoration(
                  labelText: 'Assign Contractor',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      'Not Assigned',
                      style: TextStyle(fontFamily: AppTheme.appFontFamily),
                    ),
                  ),
                  ..._contractors.map((contractor) {
                    return DropdownMenuItem<String?>(
                      value: contractor.id,
                      child: Text(
                        contractor.displayLabel,
                        style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ],
                onChanged: _isContractorsLoading
                    ? null
                    : (value) {
                        setState(() => _selectedContractorId = value);
                      },
              ),
              if (_isContractorsLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _estimatedCostController,
                decoration: InputDecoration(
                  labelText: 'Estimated Cost (Optional)',
                  hintText: '0.00',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                    return 'Enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Attach Photo (Optional)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontFamily: AppTheme.appFontFamily,
                    ),
              ),
              const SizedBox(height: 12),
              if (_selectedImage != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _selectedImage!,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade900,
                  ),
                  child: const Center(
                    child: Text(
                      'No image selected',
                      style: TextStyle(
                        color: Colors.grey,
                        fontFamily: AppTheme.appFontFamily,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _pickImage,
                icon: const Icon(Icons.photo_camera),
                label: Text(
                  _selectedImage == null ? 'Take Photo' : 'Change Photo',
                  style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isUploading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.primaryColor,
                ),
                child: _isUploading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Submit Request',
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: AppTheme.appFontFamily,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaintenanceTemplate {
  const _MaintenanceTemplate({
    required this.label,
    required this.title,
    required this.category,
    required this.estimatedCost,
  });

  final String label;
  final String title;
  final String category;
  final double estimatedCost;
}
