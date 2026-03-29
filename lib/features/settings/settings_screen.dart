import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme.dart';
import '../../models/unit_configuration.dart';
import '../../services/supabase_service.dart';
import '../../services/utility_rate_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static final NumberFormat _currencyFormat =
      NumberFormat.currency(symbol: r'$ ', decimalDigits: 2);

  double _utilityRate = 0;

  @override
  void initState() {
    super.initState();
    _loadUtilityRate();
  }

  Future<void> _loadUtilityRate() async {
    final rate = await UtilityRateService.instance.getDefaultRate();
    if (!mounted) return;

    setState(() {
      _utilityRate = rate;
    });
  }

  Future<void> _showUtilityRateDialog() async {
    final controller = TextEditingController(
      text: _utilityRate > 0 ? _utilityRate.toStringAsFixed(2) : '',
    );

    final savedRate = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: const Text(
            'Utility Billing Rate',
            style: TextStyle(fontFamily: AppTheme.appFontFamily),
          ),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Rate per unit',
              prefixText: r'$ ',
              hintText: 'Enter water rate per unit',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final value = double.tryParse(controller.text.trim());
                if (value == null || value < 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.red.shade700,
                      content: const Text(
                        'Please enter a valid utility rate.',
                        style: TextStyle(fontFamily: AppTheme.appFontFamily),
                      ),
                    ),
                  );
                  return;
                }

                Navigator.of(dialogContext).pop(value);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (savedRate == null) {
      return;
    }

    await UtilityRateService.instance.setDefaultRate(savedRate);

    if (!mounted) return;

    setState(() {
      _utilityRate = savedRate;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primaryColor,
          content: Text(
            'Utility rate saved: ${_currencyFormat.format(savedRate)} per unit.',
            style: const TextStyle(fontFamily: AppTheme.appFontFamily),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'General Settings',
          style: TextStyle(fontFamily: AppTheme.appFontFamily),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(LucideIcons.droplets),
              title: const Text(
                'Utility Billing Rate',
                style: TextStyle(fontFamily: AppTheme.appFontFamily),
              ),
              subtitle: Text(
                'Current: ${_currencyFormat.format(_utilityRate)} per unit',
                style: const TextStyle(fontFamily: AppTheme.appFontFamily),
              ),
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: _showUtilityRateDialog,
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(LucideIcons.droplet),
              title: const Text(
                'Utility Rate by Unit Type',
                style: TextStyle(fontFamily: AppTheme.appFontFamily),
              ),
              subtitle: const Text(
                'Set custom rates for Bedsitter, Studio, etc.',
                style: TextStyle(fontFamily: AppTheme.appFontFamily),
              ),
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const UtilityRateByUnitTypeScreen(),
                  ),
                );
                await _loadUtilityRate();
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(LucideIcons.home),
              title: const Text(
                'Edit Unit Types',
                style: TextStyle(fontFamily: AppTheme.appFontFamily),
              ),
              subtitle: const Text(
                'Default rent and occupancy rules',
                style: TextStyle(fontFamily: AppTheme.appFontFamily),
              ),
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const UnitTypeSettingsScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class UtilityRateByUnitTypeScreen extends StatefulWidget {
  const UtilityRateByUnitTypeScreen({super.key});

  @override
  State<UtilityRateByUnitTypeScreen> createState() => _UtilityRateByUnitTypeScreenState();
}

class _UtilityRateByUnitTypeScreenState extends State<UtilityRateByUnitTypeScreen> {
  static final NumberFormat _currencyFormat =
      NumberFormat.currency(symbol: r'$ ', decimalDigits: 2);

  bool _isLoading = true;
  String? _error;
  List<UnitConfiguration> _configurations = [];
  Map<String, double> _rateMap = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final orgId = await SupabaseService.instance.getCurrentOrganizationId();
      if (orgId == null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _error = 'Organization not found.';
        });
        return;
      }

      final data = await SupabaseService.instance.fetchUnitConfigurationsByOrganization(orgId);
      final map = await UtilityRateService.instance.getRateMap();

      if (!mounted) return;
      setState(() {
        _configurations = data;
        _rateMap = map;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Failed to load unit types: $error';
      });
    }
  }

  Future<void> _editRate(UnitConfiguration config) async {
    final key = config.unitTypeName.trim().toLowerCase();
    final existing = _rateMap[key];
    final controller = TextEditingController(
      text: existing != null ? existing.toStringAsFixed(2) : '',
    );

    final saved = await showDialog<double?>(
      context: context,
      builder: (dialogContext) {
        String? validationError;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceColor,
              title: Text(
                'Rate: ${config.unitTypeName}',
                style: const TextStyle(fontFamily: AppTheme.appFontFamily),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Rate per unit',
                      prefixText: r'$ ',
                    ),
                  ),
                  if (validationError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      validationError!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                        fontFamily: AppTheme.appFontFamily,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    controller.clear();
                    setDialogState(() {
                      validationError = null;
                    });
                  },
                  child: const Text('Clear'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(double.nan);
                  },
                  child: const Text('Use Default'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final raw = controller.text.trim();
                    final value = double.tryParse(raw);
                    if (value == null || value < 0) {
                      setDialogState(() {
                        validationError = 'Enter a valid non-negative rate.';
                      });
                      return;
                    }

                    Navigator.of(dialogContext).pop(value);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (saved == null) {
      return;
    }

    if (saved.isNaN) {
      await UtilityRateService.instance.removeRateForUnitType(config.unitTypeName);
    } else {
      await UtilityRateService.instance.setRateForUnitType(config.unitTypeName, saved);
    }

    if (!mounted) return;
    await _load();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primaryColor,
          content: Text(
            saved.isNaN
                ? 'Custom rate removed for ${config.unitTypeName}. Using default rate.'
                : 'Saved ${_currencyFormat.format(saved)} for ${config.unitTypeName}.',
            style: const TextStyle(fontFamily: AppTheme.appFontFamily),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Utility Rates by Unit Type',
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
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _configurations.length,
                  itemBuilder: (context, index) {
                    final item = _configurations[index];
                    final rate = _rateMap[item.unitTypeName.trim().toLowerCase()];

                    return Card(
                      child: ListTile(
                        leading: const Icon(LucideIcons.home),
                        title: Text(
                          item.unitTypeName,
                          style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                        ),
                        subtitle: Text(
                          rate == null
                              ? 'Using default utility rate'
                              : 'Custom rate: ${_currencyFormat.format(rate)} / unit',
                          style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                        ),
                        trailing: const Icon(LucideIcons.pencil),
                        onTap: () {
                          _editRate(item);
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

class UnitTypeSettingsScreen extends StatefulWidget {
  const UnitTypeSettingsScreen({super.key});

  @override
  State<UnitTypeSettingsScreen> createState() => _UnitTypeSettingsScreenState();
}

class _UnitTypeSettingsScreenState extends State<UnitTypeSettingsScreen> {
  Future<List<UnitConfiguration>>? _configurationsFuture;
  String? _organizationId;

  @override
  void initState() {
    super.initState();
    _loadConfigurations();
  }

  Future<void> _loadConfigurations() async {
    final orgId = await SupabaseService.instance.getCurrentOrganizationId();
    if (!mounted) return;

    setState(() {
      _organizationId = orgId;
      if (orgId != null) {
        _configurationsFuture =
            SupabaseService.instance.fetchUnitConfigurationsByOrganization(orgId);
      } else {
        _configurationsFuture = Future.value(<UnitConfiguration>[]);
      }
    });
  }

  Future<void> _showConfigurationDialog({UnitConfiguration? existing}) async {
    final typeController = TextEditingController(text: existing?.unitTypeName ?? '');
    final rentController = TextEditingController(
      text: existing != null ? existing.defaultRent.toStringAsFixed(2) : '',
    );
    final minController = TextEditingController(
      text: existing != null ? existing.minOccupants.toString() : '1',
    );
    final maxController = TextEditingController(
      text: existing != null ? existing.maxOccupants.toString() : '1',
    );

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: Text(
            existing == null ? 'Add Unit Type' : 'Edit Unit Type',
            style: const TextStyle(fontFamily: AppTheme.appFontFamily),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: typeController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Studio, One Bedroom',
                    labelText: 'Unit Type Name',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rentController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: 'Default Rent',
                    labelText: 'Default Rent',
                    prefixText: '\$ ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: minController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Minimum Occupants',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: maxController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Maximum Occupants',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Policy presets: Bedsitter (1), Studio (1-2), One Bedroom (1-3), Two Bedroom (1-5).',
                  style: TextStyle(
                    fontFamily: AppTheme.appFontFamily,
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
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
                final typeName = typeController.text.trim();
                final rent = double.tryParse(rentController.text.trim()) ?? -1;
                final min = int.tryParse(minController.text.trim()) ?? 1;
                final max = int.tryParse(maxController.text.trim()) ?? 1;

                if (typeName.isEmpty || rent < 0) {
                  _showSnackBar('Unit type name and valid rent are required.', isError: true);
                  return;
                }

                final resolvedRule = UnitConfiguration.resolveOccupancyRule(typeName, min, max);

                try {
                  if (_organizationId == null) {
                    _showSnackBar('Organization not found.', isError: true);
                    return;
                  }

                  if (existing == null) {
                    await SupabaseService.instance.createUnitConfiguration(
                      organizationId: _organizationId!,
                      unitTypeName: typeName,
                      defaultRent: rent,
                      minOccupants: resolvedRule.min,
                      maxOccupants: resolvedRule.max,
                    );
                  } else {
                    await SupabaseService.instance.updateUnitConfiguration(
                      configurationId: existing.id,
                      unitTypeName: typeName,
                      defaultRent: rent,
                      minOccupants: resolvedRule.min,
                      maxOccupants: resolvedRule.max,
                    );
                  }

                  if (!mounted) return;
                  Navigator.of(context).pop();
                  await _loadConfigurations();
                  _showSnackBar(
                    existing == null
                        ? 'Unit type added successfully.'
                        : 'Unit type updated successfully.',
                  );
                } catch (error) {
                  _showSnackBar('Failed to save unit type: $error', isError: true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    typeController.dispose();
    rentController.dispose();
    minController.dispose();
    maxController.dispose();
  }

  Future<void> _deleteConfiguration(String configId) async {
    try {
      await SupabaseService.instance.deleteUnitConfiguration(configId);
      if (!mounted) return;
      await _loadConfigurations();
      _showSnackBar('Unit type deleted.');
    } catch (error) {
      _showSnackBar('Failed to delete unit type: $error', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Unit Types',
          style: TextStyle(fontFamily: AppTheme.appFontFamily),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showConfigurationDialog(),
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Unit Type',
          style: TextStyle(fontFamily: AppTheme.appFontFamily),
        ),
      ),
      body: _configurationsFuture == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<UnitConfiguration>>(
              future: _configurationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Error loading unit types: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                      ),
                    ),
                  );
                }

                final configurations = snapshot.data ?? [];
                if (configurations.isEmpty) {
                  return Center(
                    child: Text(
                      'No unit types configured yet.',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontFamily: AppTheme.appFontFamily,
                          ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: configurations.length,
                  itemBuilder: (context, index) {
                    final configuration = configurations[index];
                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFF0D9488), width: 1),
                      ),
                      child: ListTile(
                        leading: const Icon(LucideIcons.home),
                        title: Text(
                          configuration.unitTypeName,
                          style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                        ),
                        subtitle: Text(
                          '\$${configuration.defaultRent.toStringAsFixed(2)} | Occupants ${configuration.minOccupants}-${configuration.maxOccupants}',
                          style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(LucideIcons.pencil),
                              onPressed: () =>
                                  _showConfigurationDialog(existing: configuration),
                            ),
                            IconButton(
                              icon: const Icon(LucideIcons.trash2),
                              color: Colors.red.shade700,
                              onPressed: () => _deleteConfiguration(configuration.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
