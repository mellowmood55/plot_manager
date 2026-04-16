import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme.dart';
import '../../models/unit_configuration.dart';
import '../../services/supabase_service.dart';
import '../../services/utility_rate_service.dart';
import 'providers/theme_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
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
    final savedRate = await showDialog<double>(
      context: context,
      builder: (_) => _RateInputDialog(
        title: 'Utility Billing Rate',
        labelText: 'Rate per unit',
        hintText: 'Enter water rate per unit',
        initialValue: _utilityRate > 0 ? _utilityRate.toStringAsFixed(2) : '',
      ),
    );

    if (savedRate == null) {
      return;
    }

    await UtilityRateService.instance.setDefaultRate(savedRate);

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _utilityRate = savedRate;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isLightMode = themeMode == ThemeMode.light;

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
            child: SwitchListTile(
              secondary: const Icon(LucideIcons.sunMoon, size: 20),
              value: isLightMode,
              onChanged: (value) async {
                HapticFeedback.lightImpact();
                await ref.read(themeModeProvider.notifier).toggleMode(value);
              },
              title: const Text(
                'Light Mode',
                style: TextStyle(fontFamily: AppTheme.appFontFamily),
              ),
              subtitle: Text(
                isLightMode ? 'Crisp White Theme' : 'Midnight Slate Theme',
                style: const TextStyle(fontFamily: AppTheme.appFontFamily),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(LucideIcons.droplets, size: 20),
              title: const Text(
                'Utility Billing Rate',
                style: TextStyle(fontFamily: AppTheme.appFontFamily),
              ),
              subtitle: Text(
                'Current: ${_currencyFormat.format(_utilityRate)} per unit',
                style: const TextStyle(fontFamily: AppTheme.appFontFamily),
              ),
              trailing: const Icon(LucideIcons.chevronRight, size: 20),
              onTap: () {
                HapticFeedback.lightImpact();
                _showUtilityRateDialog();
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(LucideIcons.droplet, size: 20),
              title: const Text(
                'Utility Rate by Unit Type',
                style: TextStyle(fontFamily: AppTheme.appFontFamily),
              ),
              subtitle: const Text(
                'Set custom rates for Bedsitter, Studio, etc.',
                style: TextStyle(fontFamily: AppTheme.appFontFamily),
              ),
              trailing: const Icon(LucideIcons.chevronRight, size: 20),
              onTap: () async {
                HapticFeedback.lightImpact();
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
              leading: const Icon(LucideIcons.home, size: 20),
              title: const Text(
                'Edit Unit Types',
                style: TextStyle(fontFamily: AppTheme.appFontFamily),
              ),
              subtitle: const Text(
                'Default rent and occupancy rules',
                style: TextStyle(fontFamily: AppTheme.appFontFamily),
              ),
              trailing: const Icon(LucideIcons.chevronRight, size: 20),
              onTap: () {
                HapticFeedback.lightImpact();
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

    final saved = await showDialog<double?>(
      context: context,
      builder: (_) => _RateInputDialog(
        title: 'Rate: ${config.unitTypeName}',
        labelText: 'Rate per unit',
        initialValue: existing != null ? existing.toStringAsFixed(2) : '',
        allowUseDefault: true,
      ),
    );

    if (saved == null) {
      return;
    }

    if (saved.isNaN) {
      await UtilityRateService.instance.removeRateForUnitType(config.unitTypeName);
    } else {
      await UtilityRateService.instance.setRateForUnitType(config.unitTypeName, saved);
    }

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final normalizedKey = config.unitTypeName.trim().toLowerCase();
      setState(() {
        if (saved.isNaN) {
          _rateMap.remove(normalizedKey);
        } else {
          _rateMap[normalizedKey] = saved;
        }
      });
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

class _RateInputDialog extends StatefulWidget {
  const _RateInputDialog({
    required this.title,
    required this.labelText,
    required this.initialValue,
    this.hintText,
    this.allowUseDefault = false,
  });

  final String title;
  final String labelText;
  final String initialValue;
  final String? hintText;
  final bool allowUseDefault;

  @override
  State<_RateInputDialog> createState() => _RateInputDialogState();
}

class _RateInputDialogState extends State<_RateInputDialog> {
  late final TextEditingController _controller;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = double.tryParse(_controller.text.trim());
    if (value == null || value < 0) {
      setState(() {
        _validationError = 'Enter a valid non-negative rate.';
      });
      return;
    }

    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: Text(
        widget.title,
        style: const TextStyle(fontFamily: AppTheme.appFontFamily),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: widget.labelText,
              prefixText: r'$ ',
              hintText: widget.hintText,
            ),
          ),
          if (_validationError != null) ...[
            const SizedBox(height: 8),
            Text(
              _validationError!,
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
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            _controller.clear();
            setState(() {
              _validationError = null;
            });
          },
          child: const Text('Clear'),
        ),
        if (widget.allowUseDefault)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(double.nan);
            },
            child: const Text('Use Default'),
          ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
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
          backgroundColor: Theme.of(context).colorScheme.surface,
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
                Text(
                  'Policy presets: Bedsitter (1), Studio (1-2), One Bedroom (1-3), Two Bedroom (1-5).',
                  style: TextStyle(
                    fontFamily: AppTheme.appFontFamily,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[500]! : Color(0xFF94A3B8),
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

                  final successMessage = existing == null
                      ? 'Unit type added successfully.'
                      : 'Unit type updated successfully.';

                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    try {
                      await _loadConfigurations();
                      if (mounted) {
                        _showSnackBar(successMessage);
                      }
                    } catch (reloadError) {
                      if (mounted) {
                        _showSnackBar('$successMessage (list updated)', isError: false);
                      }
                    }
                  });
                } catch (error) {
                  if (mounted) {
                    _showSnackBar('Failed to save unit type: $error', isError: true);
                  }
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
                        side: const BorderSide(color: Color(0xFFB8956A), width: 1),
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
