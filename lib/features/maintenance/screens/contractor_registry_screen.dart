import 'package:flutter/material.dart';
import 'package:flutter_contacts/contact.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme.dart';
import '../../../models/contractor.dart';
import '../../../services/maintenance_service.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/specialty_dropdown_field.dart';

class ContractorRegistryScreen extends StatefulWidget {
  const ContractorRegistryScreen({
    super.key,
    this.initialSpecialty,
  });

  final String? initialSpecialty;

  @override
  State<ContractorRegistryScreen> createState() => _ContractorRegistryScreenState();
}

class _ContractorRegistryScreenState extends State<ContractorRegistryScreen> {
  static const List<String> _specialtyFilters = [
    'All',
    'Plumbing',
    'Electrical',
    'Painting',
    'Carpentry',
    'Masonry',
    'General Handyman',
  ];

  bool _isLoading = true;
  String? _error;
  String? _organizationId;
  String _searchQuery = '';
  String _selectedSpecialty = 'All';
  List<Contractor> _contractors = [];
  Map<String, int> _activeTicketCounts = {};

  @override
  void initState() {
    super.initState();
    final initialSpecialty = widget.initialSpecialty?.trim();
    if (initialSpecialty != null && initialSpecialty.isNotEmpty) {
      _selectedSpecialty = initialSpecialty;
    }
    _loadRegistry();
  }

  Future<void> _loadRegistry() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final organizationId = await SupabaseService.instance.getCurrentOrganizationId();
      if (organizationId == null || organizationId.isEmpty) {
        if (!mounted) {
          return;
        }
        setState(() {
          _organizationId = null;
          _contractors = [];
          _activeTicketCounts = {};
          _isLoading = false;
        });
        return;
      }

      final contractors = await MaintenanceService.instance.getContractorsByOrganization(
        organizationId: organizationId,
      );
      final activeTicketCounts = await MaintenanceService.instance.getActiveTicketCountsByContractor(
        organizationId: organizationId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _organizationId = organizationId;
        _contractors = contractors;
        _activeTicketCounts = activeTicketCounts;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Failed to load contractor registry: $error';
        _isLoading = false;
      });
    }
  }

  List<Contractor> get _filteredContractors {
    final query = _searchQuery.trim().toLowerCase();
    final specialty = _selectedSpecialty.trim();

    final results = _contractors.where((contractor) {
      final matchesSpecialty = specialty == 'All' ? true : contractor.matchesCategory(specialty);
      final matchesSearch = query.isEmpty
          ? true
          : contractor.name.toLowerCase().contains(query) ||
              contractor.phone.toLowerCase().contains(query) ||
              contractor.specialty.toLowerCase().contains(query);

      return matchesSpecialty && matchesSearch;
    }).toList();

    results.sort((left, right) {
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

    return results;
  }

  Contractor? get _recommendedContractor {
    final candidates = _filteredContractors.where((contractor) {
      return (_activeTicketCounts[contractor.id] ?? 0) == 0;
    }).toList();

    if (candidates.isEmpty) {
      return null;
    }

    return candidates.first;
  }

  IconData _specialtyIcon(String specialty) {
    final normalized = specialty.trim().toLowerCase();

    if (normalized.contains('electrical')) {
      return Icons.bolt;
    }
    if (normalized.contains('plumb')) {
      return Icons.handyman;
    }
    if (normalized.contains('paint')) {
      return Icons.format_paint;
    }
    if (normalized.contains('carp')) {
      return Icons.construction;
    }
    if (normalized.contains('mason')) {
      return Icons.account_balance;
    }

    return Icons.person;
  }

  Future<void> _pickFromContacts(
    TextEditingController nameController,
    TextEditingController phoneController,
  ) async {
    try {
      final permission = await Permission.contacts.request();
      if (!permission.isGranted) {
        if (permission.isPermanentlyDenied) {
          await openAppSettings();
        }
        if (!mounted) {
          return;
        }
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

      if (!mounted) {
        return;
      }

      final phone = contact.phones.isNotEmpty ? contact.phones.first.number.trim() : '';
      nameController.text = contact.displayName;
      phoneController.text = phone;
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            'Failed to pick a contact: $error',
            style: const TextStyle(fontFamily: AppTheme.appFontFamily),
          ),
        ),
      );
    }
  }

  Future<void> _openAddContractorSheet({String? specialty}) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final specialtyController = TextEditingController(
      text: (specialty == null || specialty.trim().isEmpty) ? 'General Handyman' : specialty.trim(),
    );
    final reliabilityController = TextEditingController(text: '0.0');
    final formKey = GlobalKey<FormState>();

    var isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppTheme.lightTextColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Add Contractor',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontFamily: AppTheme.appFontFamily,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Keep the contractor pool organized and score-aware.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontFamily: AppTheme.appFontFamily,
                              color: AppTheme.lightTextColor,
                            ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: nameController,
                        style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                        decoration: const InputDecoration(
                          labelText: 'Contractor Name',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                              decoration: const InputDecoration(
                                labelText: 'Phone Number',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Phone is required';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    await _pickFromContacts(nameController, phoneController);
                                    if (sheetContext.mounted) {
                                      setModalState(() {});
                                    }
                                  },
                            icon: const Icon(Icons.contacts),
                            label: const Text(
                              'Contacts',
                              style: TextStyle(fontFamily: AppTheme.appFontFamily),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SpecialtyDropdownField(
                        controller: specialtyController,
                        onChanged: (value) {
                          setModalState(() {});
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: reliabilityController,
                        style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Reliability Score (0 - 5)',
                        ),
                        validator: (value) {
                          final parsed = double.tryParse((value ?? '').trim());
                          if (parsed == null) {
                            return 'Enter a valid score';
                          }
                          if (parsed < 0 || parsed > 5) {
                            return 'Score must be between 0 and 5';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) {
                                  return;
                                }

                                final parsedScore =
                                    double.tryParse(reliabilityController.text.trim()) ?? 0;
                                final organizationId =
                                    _organizationId ?? await SupabaseService.instance.getCurrentOrganizationId();

                                if (organizationId == null || organizationId.isEmpty) {
                                  if (!sheetContext.mounted) {
                                    return;
                                  }
                                  setModalState(() {
                                    isSaving = false;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      backgroundColor: Colors.redAccent,
                                      content: Text(
                                        'Could not resolve the current organization.',
                                        style: TextStyle(fontFamily: AppTheme.appFontFamily),
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() {
                                  isSaving = true;
                                });

                                try {
                                  final saved = await MaintenanceService.instance.saveContractor(
                                    name: nameController.text,
                                    phone: phoneController.text,
                                    specialty: specialtyController.text,
                                    organizationId: organizationId,
                                    reliabilityScore: parsedScore,
                                  );

                                  if (!mounted) {
                                    return;
                                  }

                                  Navigator.of(sheetContext).pop();
                                  if (saved != null) {
                                    await _loadRegistry();
                                  }
                                } catch (error) {
                                  if (!sheetContext.mounted) {
                                    return;
                                  }
                                  setModalState(() {
                                    isSaving = false;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: Colors.red.shade700,
                                      content: Text(
                                        'Failed to save contractor: $error',
                                        style: const TextStyle(
                                          fontFamily: AppTheme.appFontFamily,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              },
                        child: isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                'Save Contractor',
                                style: TextStyle(fontFamily: AppTheme.appFontFamily),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _specialtyFilters.map((specialty) {
        final selected = _selectedSpecialty == specialty;
        return ChoiceChip(
          selected: selected,
          label: Text(
            specialty,
            style: const TextStyle(fontFamily: AppTheme.appFontFamily),
          ),
          onSelected: (_) {
            setState(() {
              _selectedSpecialty = specialty;
            });
          },
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredContractors = _filteredContractors;
    final recommendedContractor = _recommendedContractor;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Contractor Registry',
          style: TextStyle(fontFamily: AppTheme.appFontFamily),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadRegistry,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryColor,
        onPressed: () => _openAddContractorSheet(
          specialty: _selectedSpecialty == 'All' ? null : _selectedSpecialty,
        ),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text(
          'Add Contractor',
          style: TextStyle(fontFamily: AppTheme.appFontFamily),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                    ),
                  ),
                )
              : SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Organized contractor pool',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontFamily: AppTheme.appFontFamily,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                onChanged: (value) {
                                  setState(() {
                                    _searchQuery = value;
                                  });
                                },
                                style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                                decoration: const InputDecoration(
                                  labelText: 'Search by name, phone, or specialty',
                                  prefixIcon: Icon(Icons.search),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildFilterChips(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (recommendedContractor != null)
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.9), width: 1.2),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primaryColor.withOpacity(0.16),
                              child: Icon(
                                _specialtyIcon(recommendedContractor.specialty),
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            title: Text(
                              'Recommended',
                              style: const TextStyle(
                                fontFamily: AppTheme.appFontFamily,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            subtitle: Text(
                              '${recommendedContractor.name} • ${recommendedContractor.specialty} • Score ${recommendedContractor.reliabilityLabel}',
                              style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                            ),
                            trailing: Text(
                              '${_activeTicketCounts[recommendedContractor.id] ?? 0} active',
                              style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                            ),
                          ),
                        ),
                      if (recommendedContractor != null) const SizedBox(height: 12),
                      if (filteredContractors.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                const Text(
                                  'No contractors match the current filter.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontFamily: AppTheme.appFontFamily),
                                ),
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: () => _openAddContractorSheet(
                                    specialty: _selectedSpecialty == 'All' ? null : _selectedSpecialty,
                                  ),
                                  icon: const Icon(Icons.add),
                                  label: Text(
                                    _selectedSpecialty == 'All'
                                        ? 'Add Contractor'
                                        : 'Add $_selectedSpecialty Contractor',
                                    style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...filteredContractors.map((contractor) {
                          final isRecommended = recommendedContractor?.id == contractor.id;
                          final activeTickets = _activeTicketCounts[contractor.id] ?? 0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isRecommended ? AppTheme.primaryColor : Colors.transparent,
                                  width: isRecommended ? 1.2 : 0,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.primaryColor.withOpacity(0.16),
                                  child: Icon(
                                    _specialtyIcon(contractor.specialty),
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        contractor.name,
                                        style: const TextStyle(
                                          fontFamily: AppTheme.appFontFamily,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (isRecommended)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor.withOpacity(0.16),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: const Text(
                                          'Recommended',
                                          style: TextStyle(
                                            fontFamily: AppTheme.appFontFamily,
                                            fontSize: 11,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    '${contractor.specialty} • ${contractor.phone}\n${activeTickets} active tickets',
                                    style: const TextStyle(
                                      fontFamily: AppTheme.appFontFamily,
                                      color: AppTheme.lightTextColor,
                                    ),
                                  ),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 18),
                                    const SizedBox(height: 4),
                                    Text(
                                      contractor.reliabilityLabel,
                                      style: const TextStyle(
                                        fontFamily: AppTheme.appFontFamily,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.lightTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 84),
                    ],
                  ),
                ),
    );
  }
}
