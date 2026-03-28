import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme.dart';
import '../../../models/maintenance_request.dart';
import '../../../services/maintenance_service.dart';

class AddMaintenanceScreen extends StatefulWidget {
  final String? unitId;

  const AddMaintenanceScreen({Key? key, this.unitId}) : super(key: key);

  @override
  State<AddMaintenanceScreen> createState() => _AddMaintenanceScreenState();
}

class _AddMaintenanceScreenState extends State<AddMaintenanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _estimatedCostController = TextEditingController();

  MaintenancePriority _selectedPriority = MaintenancePriority.medium;
  File? _selectedImage;
  bool _isUploading = false;
  String? _selectedUnitId;

  @override
  void initState() {
    super.initState();
    _selectedUnitId = widget.unitId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _estimatedCostController.dispose();
    super.dispose();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to pick image: $e',
              style: const TextStyle(fontFamily: 'Comic Sans MS'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedUnitId == null || _selectedUnitId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a unit',
            style: TextStyle(fontFamily: 'Comic Sans MS'),
          ),
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      String? imageUrl;

      // Upload image if selected
      if (_selectedImage != null) {
        final fileName = await MaintenanceService.instance.uploadMaintenanceImage(
          _selectedImage!,
          _selectedUnitId!,
          'temp_${DateTime.now().millisecondsSinceEpoch}',
        );
        imageUrl = MaintenanceService.instance.getImageUrl(fileName);
      }

      // Create maintenance request
      final estimatedCost = _estimatedCostController.text.isEmpty
        ? null
        : double.tryParse(_estimatedCostController.text);

      await MaintenanceService.instance.createMaintenanceRequest(
        unitId: _selectedUnitId!,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        priority: _selectedPriority,
        estimatedCost: estimatedCost,
        imageUrl: imageUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Maintenance request created successfully!',
              style: TextStyle(
                fontFamily: 'Comic Sans MS',
                color: Colors.white,
              ),
            ),
            backgroundColor: Colors.teal,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error creating request: $e',
              style: const TextStyle(fontFamily: 'Comic Sans MS'),
            ),
          ),
        );
      }
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
        title: const Text('Report Maintenance Issue'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title field
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
                style: const TextStyle(fontFamily: 'Comic Sans MS'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description field
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
                style: const TextStyle(fontFamily: 'Comic Sans MS'),
                maxLines: 4,
              ),
              const SizedBox(height: 16),

              // Priority dropdown
              DropdownButtonFormField<MaintenancePriority>(
                value: _selectedPriority,
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
                      style: const TextStyle(fontFamily: 'Comic Sans MS'),
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

              // Estimated cost field
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
                style: const TextStyle(fontFamily: 'Comic Sans MS'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (double.tryParse(value) == null) {
                      return 'Enter a valid number';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Photo section
              Text(
                'Attach Photo (Optional)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontFamily: 'Comic Sans MS',
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
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[900],
                  ),
                  child: const Center(
                    child: Text(
                      'No image selected',
                      style: TextStyle(
                        color: Colors.grey,
                        fontFamily: 'Comic Sans MS',
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
                  style: const TextStyle(fontFamily: 'Comic Sans MS'),
                ),
              ),
              const SizedBox(height: 24),

              // Submit button
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
                        fontFamily: 'Comic Sans MS',
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
