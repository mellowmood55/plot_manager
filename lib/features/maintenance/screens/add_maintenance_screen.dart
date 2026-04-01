import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_contacts/contact.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme.dart';
import '../../../models/contractor.dart';
import '../../../models/maintenance_request.dart';
import '../../../services/maintenance_service.dart';
import '../../../services/supabase_service.dart';
import 'contractor_registry_screen.dart';

class AddMaintenanceScreen extends StatefulWidget {
  final String? unitId;
  final MaintenanceRequest? initialRequest;

  const AddMaintenanceScreen({
    super.key,
    this.unitId,
    this.initialRequest,
  });

  @override
  State<AddMaintenanceScreen> createState() => _AddMaintenanceScreenState();
}

class _AddMaintenanceScreenState extends State<AddMaintenanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _estimatedCostController = TextEditingController();
  final _categoryController = TextEditingController(text: 'General');
  final _contractorNameController = TextEditingController();
  final _contractorPhoneController = TextEditingController();
  final _contractorSpecialtyController = TextEditingController(text: 'General Handyman');

  MaintenancePriority _selectedPriority = MaintenancePriority.medium;
  File? _selectedImage;
  bool _isUploading = false;
  String? _selectedUnitId;
  String? _selectedContractorId;
  bool _isContractorsLoading = true;
  List<Contractor> _contractors = [];
  Map<String, int> _activeTicketCounts = {};
  String? _selectedTemplateLabel;
  Set<String> _selectedContractorRoles = {};

  static const List<String> _roleOptions = [
    'Plumbing',
    'Electrical',
    'Painting',
    'Carpentry',
    'Masonry',
    'General Handyman',
  ];

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
    _applyInitialRequestIfAny();
    _loadContractors();
    _recoverLostImageData();
  }

  Future<void> _recoverLostImageData() async {
    try {
      final picker = ImagePicker();
      final lostData = await picker.retrieveLostData();
      if (!mounted) return;

      if (!lostData.isEmpty && lostData.file != null) {
        setState(() {
          _selectedImage = File(lostData.file!.path);
        });
      }
    } catch (_) {
      // Ignore lost data recovery failures; normal picker flow still works.
    }
  }

  void _applyInitialRequestIfAny() {
    final existing = widget.initialRequest;
    if (existing == null) {
      return;
    }

    _selectedUnitId = existing.unitId;
    _titleController.text = existing.title;
    _descriptionController.text = existing.description;
    _categoryController.text = existing.category;
    _selectedPriority = existing.priority;
    _estimatedCostController.text = existing.estimatedCost?.toStringAsFixed(2) ?? '';
    _selectedContractorId = existing.contractorId;
    _contractorNameController.text = existing.contractor?.name ?? '';
    _contractorPhoneController.text = existing.contractor?.phone ?? '';
    _contractorSpecialtyController.text = existing.contractor?.specialty ?? _categoryController.text;
    _selectedContractorRoles = _parseRoles(_contractorSpecialtyController.text);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _estimatedCostController.dispose();
    _categoryController.dispose();
    _contractorNameController.dispose();
    _contractorPhoneController.dispose();
    _contractorSpecialtyController.dispose();
    super.dispose();
  }

  Future<void> _loadContractors() async {
    await _loadContractorsForCategory(_categoryController.text.trim());
  }

  bool get _hasSelectedCategory => _categoryController.text.trim().isNotEmpty;

  List<Contractor> get _sortedMatchingContractors {
    final category = _categoryController.text.trim();
    final matches = _contractors.where((contractor) {
      if (category.isEmpty) {
        return true;
      }

      return contractor.matchesCategory(category);
    }).toList();

    matches.sort((left, right) {
      final leftActive = _activeTicketCounts[left.id] ?? 0;
      final rightActive = _activeTicketCounts[right.id] ?? 0;

      final leftRecommended = leftActive == 0;
      final rightRecommended = rightActive == 0;
      if (leftRecommended != rightRecommended) {
        return leftRecommended ? -1 : 1;
      }

      final scoreCompare = right.reliabilityScore.compareTo(left.reliabilityScore);
      if (scoreCompare != 0) {
        return scoreCompare;
      }

      final activeCompare = leftActive.compareTo(rightActive);
      if (activeCompare != 0) {
        return activeCompare;
      }

      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });

    return matches;
  }

  Contractor? get _recommendedContractor {
    final matches = _sortedMatchingContractors.where((contractor) {
      return (_activeTicketCounts[contractor.id] ?? 0) == 0;
    }).toList();

    return matches.isEmpty ? null : matches.first;
  }

  Future<void> _openContractorRegistry({String? specialty}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContractorRegistryScreen(
          initialSpecialty: specialty,
        ),
      ),
    );

    if (!mounted) return;
    await _loadContractorsForCategory(_categoryController.text.trim());
  }

  Future<void> _loadContractorsForCategory(String category) async {
    setState(() {
      _isContractorsLoading = true;
    });

    try {
      final resolvedOrganizationId = await SupabaseService.instance.getCurrentOrganizationId();
      final contractors = await MaintenanceService.instance.getContractors(
        organizationId: resolvedOrganizationId,
        specialty: category,
      );
      final activeTicketCounts = await MaintenanceService.instance.getActiveTicketCountsByContractor(
        organizationId: resolvedOrganizationId,
      );

      if (!mounted) return;
      setState(() {
        _contractors = contractors;
        _activeTicketCounts = activeTicketCounts;
        if (_selectedContractorId != null) {
          final selected = _sortedMatchingContractors.where((c) => c.id == _selectedContractorId).toList();
          if (selected.isNotEmpty) {
            _contractorNameController.text = selected.first.name;
            _contractorPhoneController.text = selected.first.phone;
            _contractorSpecialtyController.text = selected.first.specialty;
            _selectedContractorRoles = _parseRoles(selected.first.specialty);
          } else {
            _selectedContractorId = null;
          }
        }
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
      _selectedContractorId = null;
      if (_contractorSpecialtyController.text.trim().isEmpty ||
          _contractorSpecialtyController.text == 'General Handyman') {
        _contractorSpecialtyController.text = template.category;
        _selectedContractorRoles = _parseRoles(template.category);
      }
    });

    _loadContractorsForCategory(template.category);
  }

  Set<String> _parseRoles(String raw) {
    return raw
        .split(RegExp(r'[,/;|]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  void _syncSpecialtyFromRoles() {
    if (_selectedContractorRoles.isEmpty) {
      _contractorSpecialtyController.text = 'General Handyman';
      return;
    }
    _contractorSpecialtyController.text = _selectedContractorRoles.join(', ');
  }

  Future<void> _pickContractorFromContacts() async {
    try {
      final permission = await Permission.contacts.request();
      if (!permission.isGranted) {
        if (permission.isPermanentlyDenied) {
          await openAppSettings();
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              'Contacts permission is required to pick a contractor.',
              style: TextStyle(fontFamily: AppTheme.appFontFamily),
            ),
          ),
        );
        return;
      }

      final Contact? contact = await FlutterContacts.openExternalPick();
      if (contact == null) {
        return;
      }

      final phone = contact.phones.isNotEmpty
          ? contact.phones.first.number.trim()
          : '';

      if (!mounted) return;
      setState(() {
        _contractorNameController.text = contact.displayName;
        _contractorPhoneController.text = phone;
        if (_contractorSpecialtyController.text.trim().isEmpty) {
          _contractorSpecialtyController.text = _categoryController.text.trim().isEmpty
              ? 'General Handyman'
              : _categoryController.text.trim();
          _selectedContractorRoles = _parseRoles(_contractorSpecialtyController.text);
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            'Failed to load contacts: $error',
            style: const TextStyle(
              fontFamily: AppTheme.appFontFamily,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

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

      String? contractorId = _selectedContractorId;
      if ((_contractorNameController.text.trim().isNotEmpty ||
              _contractorPhoneController.text.trim().isNotEmpty) &&
          contractorId == null) {
        final organizationId = await SupabaseService.instance.getCurrentOrganizationId();
        contractorId = await MaintenanceService.instance.findOrCreateContractor(
          name: _contractorNameController.text,
          phone: _contractorPhoneController.text,
          specialty: _contractorSpecialtyController.text,
          organizationId: organizationId,
        );

        if (!mounted) return;
      }

      final existing = widget.initialRequest;
      if (existing == null) {
        await MaintenanceService.instance.createMaintenanceRequest(
          unitId: _selectedUnitId!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _categoryController.text.trim(),
          priority: _selectedPriority,
          estimatedCost: estimatedCost,
          imageUrl: imageUrl,
          contractorId: contractorId,
        );
      } else {
        await MaintenanceService.instance.updateMaintenanceRequest(
          requestId: existing.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _categoryController.text.trim(),
          priority: _selectedPriority,
          estimatedCost: estimatedCost,
          imageUrl: imageUrl ?? existing.imageUrl,
          contractorId: contractorId,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? 'Maintenance request created successfully!'
                : 'Maintenance request updated successfully!',
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
        title: Text(
          widget.initialRequest == null ? 'Report Maintenance Issue' : 'Edit Maintenance Issue',
          style: const TextStyle(fontFamily: AppTheme.appFontFamily),
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
              Builder(
                builder: (context) {
                  final currentCategory = _categoryController.text.trim();
                  final categoryOptions = <String>{
                    'General',
                    'Plumbing',
                    'Electrical',
                    'Painting',
                    'Carpentry',
                    'Masonry',
                    if (currentCategory.isNotEmpty) currentCategory,
                  }.toList();

                  return DropdownButtonFormField<String>(
                    initialValue: currentCategory.isEmpty ? 'General' : currentCategory,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    items: categoryOptions.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(
                          category,
                          style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _categoryController.text = value;
                        _selectedContractorId = null;
                      });
                      _loadContractorsForCategory(value);
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Category is required';
                      }
                      return null;
                    },
                  );
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
                initialValue: _selectedContractorId != null &&
                        _sortedMatchingContractors.any((c) => c.id == _selectedContractorId)
                    ? _selectedContractorId
                    : null,
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
                  ..._sortedMatchingContractors.map((contractor) {
                    final isRecommended = _recommendedContractor?.id == contractor.id;
                    final activeTickets = _activeTicketCounts[contractor.id] ?? 0;
                    return DropdownMenuItem<String?>(
                      value: contractor.id,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              contractor.displayLabel,
                              style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isRecommended)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.16),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: AppTheme.primaryColor),
                              ),
                              child: const Text(
                                'Recommended',
                                style: TextStyle(
                                  fontFamily: AppTheme.appFontFamily,
                                  fontSize: 11,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                'Score ${contractor.reliabilityLabel} • $activeTickets active',
                                style: const TextStyle(
                                  fontFamily: AppTheme.appFontFamily,
                                  fontSize: 11,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: _isContractorsLoading
                    ? null
                    : (value) {
                        setState(() {
                          _selectedContractorId = value;
                          final selected = _contractors.where((c) => c.id == value).toList();
                          if (selected.isNotEmpty) {
                            _contractorNameController.text = selected.first.name;
                            _contractorPhoneController.text = selected.first.phone;
                            _contractorSpecialtyController.text = selected.first.specialty;
                            _selectedContractorRoles = _parseRoles(selected.first.specialty);
                          }
                        });
                      },
              ),
              if (_isContractorsLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(),
                ),
              if (!_isContractorsLoading)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _sortedMatchingContractors.isEmpty
                        ? 'No contractors match ${_categoryController.text.trim()} yet.'
                        : 'Recommended contractor is highlighted by score and open tickets.',
                    style: const TextStyle(
                      fontFamily: AppTheme.appFontFamily,
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (!_isContractorsLoading && _sortedMatchingContractors.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _openContractorRegistry(
                          specialty: _categoryController.text.trim(),
                        ),
                        icon: const Icon(LucideIcons.userPlus),
                        label: Text(
                          'Add ${_categoryController.text.trim()} Contractor',
                          style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _contractorNameController,
                      decoration: InputDecoration(
                        labelText: 'Contractor Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isUploading ? null : _pickContractorFromContacts,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                    child: const Text(
                      'Pick from Device Contacts',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTheme.appFontFamily,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contractorPhoneController,
                decoration: InputDecoration(
                  labelText: 'Contractor Phone',
                  hintText: '+2547...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontFamily: AppTheme.appFontFamily),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contractorSpecialtyController,
                decoration: InputDecoration(
                  labelText: 'Contractor Specialty',
                  hintText: 'Plumber, Electrician, Painter',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                onChanged: (value) {
                  setState(() {
                    _selectedContractorRoles = _parseRoles(value);
                  });
                },
              ),
              const SizedBox(height: 10),
              Text(
                'Contractor Roles (supports multiple)',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: AppTheme.appFontFamily,
                      color: Colors.white70,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _roleOptions.map((role) {
                  final selected = _selectedContractorRoles.contains(role);
                  return FilterChip(
                    selected: selected,
                    label: Text(
                      role,
                      style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                    ),
                    onSelected: (isSelected) {
                      setState(() {
                        if (isSelected) {
                          _selectedContractorRoles.add(role);
                        } else {
                          _selectedContractorRoles.remove(role);
                        }
                        _syncSpecialtyFromRoles();
                      });
                    },
                  );
                }).toList(),
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
                icon: const Icon(Icons.folder_open),
                label: Text(
                  _selectedImage == null ? 'Choose Image File' : 'Change Image File',
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
                        'Save Request',
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
