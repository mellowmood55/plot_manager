import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme.dart';
import '../../../models/property.dart';
import '../../../models/tenant.dart';
import '../../../models/unit.dart';
import '../../../models/unit_configuration.dart';
import '../../../services/supabase_service.dart';
import '../../unit/screens/unit_detail_screen.dart';

class PropertyDetailScreen extends StatefulWidget {
  const PropertyDetailScreen({
    required this.property,
    super.key,
  });

  final Property property;

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  bool _isLoading = true;
  String? _error;
  List<_UnitTenantView> _units = [];

  void _showUnitSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? Colors.red.shade700 : AppTheme.primaryColor,
        content: Text(
          message,
          style: const TextStyle(fontFamily: AppTheme.appFontFamily),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final units = await SupabaseService.instance.fetchUnitsByProperty(widget.property.id);

      final List<_UnitTenantView> data = [];

      for (final unit in units) {
        final tenant = await SupabaseService.instance.fetchTenantByUnitId(unit.id);

        data.add(_UnitTenantView(unit: unit, tenant: tenant));
      }

      setState(() {
        _units = data;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load units: $error';
      });
    }
  }

  Future<void> _showAddUnitDialog() async {
    final unitNumberController = TextEditingController();
    final rentAmountController = TextEditingController();
    String? selectedUnitType;
    double selectedRent = 0;

    final propertyType = widget.property.propertyType?.trim().toLowerCase();
    if (propertyType != null && propertyType != 'residential') {
      _showUnitSnackBar(
        'Unit type and bedroom occupancy rules are enabled for residential plots only.',
        isError: true,
      );
      return;
    }

    final orgId = await SupabaseService.instance.getCurrentOrganizationId();
    if (orgId == null) {
      _showUnitSnackBar('Organization not found.', isError: true);
      return;
    }

    final configurations =
        await SupabaseService.instance.fetchUnitConfigurationsByOrganization(orgId);

    if (configurations.isEmpty) {
      _showUnitSnackBar(
        'No unit types configured. Open Settings > General Settings > Edit Unit Types first.',
        isError: true,
      );
      return;
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceColor,
              title: const Text(
                'Add Unit',
                style: TextStyle(fontFamily: AppTheme.appFontFamily),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: unitNumberController,
                      decoration: const InputDecoration(
                        hintText: 'Unit Number (e.g. A1)',
                        labelText: 'Unit Number',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedUnitType,
                      decoration: const InputDecoration(
                        labelText: 'Unit Type',
                        hintText: 'Select or create a unit type',
                      ),
                      items: configurations
                          .map(
                            (config) => DropdownMenuItem(
                              value: config.unitTypeName,
                              child: Text(
                                config.unitTypeName,
                                style: const TextStyle(
                                  fontFamily: AppTheme.appFontFamily,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedUnitType = value;
                          if (value != null) {
                            final config = _configurationForType(configurations, value);
                            selectedRent = config.defaultRent;
                            rentAmountController.text = config.defaultRent.toStringAsFixed(2);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: rentAmountController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Default Rent',
                        prefixText: '\$ ',
                        hintText: selectedRent > 0 ? null : 'Select a unit type',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (!mounted) return;
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final candidateUnitNumber = unitNumberController.text.trim().toUpperCase();

                    if (candidateUnitNumber.isEmpty) {
                      _showUnitSnackBar('Unit number is required.', isError: true);
                      return;
                    }

                    final unitPattern = RegExp(r'^A\d{1,3}$');
                    if (!unitPattern.hasMatch(candidateUnitNumber)) {
                      _showUnitSnackBar(
                        'Unit must be in format A + 1 to 3 digits (for example A1, A01, A123).',
                        isError: true,
                      );
                      return;
                    }

                    final unitNumber =
                        SupabaseService.instance.normalizeUnitNumber(candidateUnitNumber);

                    if (unitNumber != candidateUnitNumber) {
                      unitNumberController.text = unitNumber;
                    }

                    if (selectedUnitType == null) {
                      _showUnitSnackBar('Please select a unit type.', isError: true);
                      return;
                    }

                    if (await SupabaseService.instance.unitNumberExists(
                      propertyId: widget.property.id,
                      unitNumber: unitNumber,
                    )) {
                      _showUnitSnackBar(
                        'Unit "$unitNumber" already exists. Each unit identifier must be unique.',
                        isError: true,
                      );
                      return;
                    }

                    BuildContext? loadingDialogContext;

                    try {
                      showDialog<void>(
                        context: context,
                        barrierDismissible: false,
                        builder: (dialogContext) {
                          loadingDialogContext = dialogContext;
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        },
                      );

                      await SupabaseService.instance.createUnitWithType(
                        propertyId: widget.property.id,
                        unitNumber: unitNumber,
                        unitType: selectedUnitType!,
                        rentAmount: selectedRent,
                      );

                      // Always dismiss the loading dialog first.
                      if (loadingDialogContext != null &&
                          Navigator.of(loadingDialogContext!).canPop()) {
                        Navigator.of(loadingDialogContext!).pop();
                        loadingDialogContext = null;
                      }

                      if (!mounted) return;

                      Navigator.of(context).pop();
                      await _loadUnits();
                      _showUnitSnackBar('Unit saved successfully.');
                    } catch (error) {
                      // Ensure loading dialog does not outlive this operation.
                      if (loadingDialogContext != null &&
                          Navigator.of(loadingDialogContext!).canPop()) {
                        Navigator.of(loadingDialogContext!).pop();
                        loadingDialogContext = null;
                      }

                      _showUnitSnackBar('Failed to add unit: $error',
                          isError: true);
                    }
                  },
                  child: const Text('Save Unit'),
                ),
              ],
            );
          },
        );
      },
    );

    unitNumberController.dispose();
    rentAmountController.dispose();
  }

  UnitConfiguration _configurationForType(
    List<UnitConfiguration> configurations,
    String unitType,
  ) {
    final normalizedType = unitType.trim().toLowerCase();

    for (final configuration in configurations) {
      if (configuration.unitTypeName.trim().toLowerCase() == normalizedType) {
        return configuration;
      }
    }

    return configurations.first;
  }

  Future<void> _confirmDeleteUnit(Unit unit) async {
    final verificationController = TextEditingController();
    BuildContext? loadingDialogContext;
    final provider = SupabaseService.instance.getCurrentAuthProvider();
    final requiresPassword = provider == 'email';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: const Text(
            'Delete Unit',
            style: TextStyle(fontFamily: AppTheme.appFontFamily),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                requiresPassword
                    ? 'Enter your account password to delete ${unit.unitNumber}.'
                    : 'Type CONFIRM to delete ${unit.unitNumber}.',
                style: const TextStyle(fontFamily: AppTheme.appFontFamily),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: verificationController,
                obscureText: requiresPassword,
                style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                decoration: InputDecoration(
                  labelText: requiresPassword ? 'Password' : 'Type CONFIRM',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (!mounted) return;
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final verificationInput = verificationController.text;

                if (verificationInput.isEmpty) {
                  _showUnitSnackBar(
                    requiresPassword
                        ? 'Password is required to delete a unit.'
                        : 'Type CONFIRM to delete this unit.',
                    isError: true,
                  );
                  return;
                }

                try {
                  showDialog<void>(
                    context: dialogContext,
                    barrierDismissible: false,
                    builder: (loadingContext) {
                      loadingDialogContext = loadingContext;
                      return const Center(child: CircularProgressIndicator());
                    },
                  );

                  await SupabaseService.instance.deleteUnitWithVerification(
                    unitId: unit.id,
                    verificationInput: verificationInput,
                  );

                  if (loadingDialogContext != null &&
                      Navigator.of(loadingDialogContext!).canPop()) {
                    Navigator.of(loadingDialogContext!).pop();
                    loadingDialogContext = null;
                  }

                  if (!mounted) return;

                  Navigator.of(dialogContext).pop();
                  await _loadUnits();
                  _showUnitSnackBar('Unit deleted successfully.');
                } catch (error) {
                  if (loadingDialogContext != null &&
                      Navigator.of(loadingDialogContext!).canPop()) {
                    Navigator.of(loadingDialogContext!).pop();
                    loadingDialogContext = null;
                  }

                  _showUnitSnackBar('Failed to delete unit: $error', isError: true);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    verificationController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.property.name,
          style: const TextStyle(fontFamily: AppTheme.appFontFamily),
        ),
      ),
      floatingActionButton: (!_isLoading && _error == null)
          ? FloatingActionButton.extended(
              onPressed: _showAddUnitDialog,
              backgroundColor: AppTheme.primaryColor,
              icon: const Icon(LucideIcons.home),
              label: const Text(
                'Add Unit',
                style: TextStyle(fontFamily: AppTheme.appFontFamily),
              ),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      _error!,
                      style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _units.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'No units added yet',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontFamily: AppTheme.appFontFamily),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _showAddUnitDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text(
                              '+ Add Unit',
                              style: TextStyle(fontFamily: AppTheme.appFontFamily),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: GridView.builder(
                        itemCount: _units.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.1,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemBuilder: (context, index) {
                          final item = _units[index];
                          final isOccupied = item.unit.isOccupied;
                          final canDelete = !isOccupied;

                          return InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => UnitDetailScreen(
                                    unit: item.unit,
                                    tenant: item.tenant,
                                  ),
                                ),
                              );
                              await _loadUnits();
                            },
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isOccupied
                                      ? const Color(0xFF64748B)
                                      : AppTheme.primaryColor,
                                  width: 2,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.unit.unitNumber,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontFamily: AppTheme.appFontFamily,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(LucideIcons.trash2),
                                        color: canDelete
                                            ? Colors.red.shade400
                                            : const Color(0xFF64748B),
                                        tooltip: canDelete
                                            ? 'Delete Unit'
                                            : 'Please move out the tenant before deleting this unit.',
                                        onPressed: () {
                                          if (!canDelete) {
                                            _showUnitSnackBar(
                                              'Please move out the tenant before deleting this unit.',
                                              isError: true,
                                            );
                                            return;
                                          }
                                          _confirmDeleteUnit(item.unit);
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      isOccupied ? 'Occupied' : 'Vacant',
                                      style: const TextStyle(
                                        fontFamily: AppTheme.appFontFamily,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (isOccupied && item.tenant != null)
                                      Text(
                                        item.tenant!.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: AppTheme.appFontFamily,
                                          color: Color(0xFFCBD5E1),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _UnitTenantView {
  const _UnitTenantView({
    required this.unit,
    this.tenant,
  });

  final Unit unit;
  final Tenant? tenant;
}
