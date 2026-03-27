import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme.dart';
import '../../../models/tenant.dart';
import '../../../models/unit.dart';
import '../../../services/supabase_service.dart';

class UnitDetailScreen extends StatefulWidget {
  const UnitDetailScreen({
    required this.unit,
    required this.tenant,
    super.key,
  });

  final Unit unit;
  final Tenant? tenant;

  @override
  State<UnitDetailScreen> createState() => _UnitDetailScreenState();
}

class _UnitDetailScreenState extends State<UnitDetailScreen> {
  late Unit _unit;
  Tenant? _tenant;

  static const Map<String, (int min, int max)> _fallbackOccupancyRules = {
    'bedsitter': (1, 1),
    'bed-sitter': (1, 1),
    'studio': (1, 2),
    'one bedroom': (1, 3),
    '1 bedroom': (1, 3),
    'two bedroom': (1, 5),
    '2 bedroom': (1, 5),
  };

  @override
  void initState() {
    super.initState();
    _unit = widget.unit;
    _tenant = widget.tenant;
  }

  Future<void> _launchDialer(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not launch dialer',
            style: TextStyle(fontFamily: AppTheme.appFontFamily),
          ),
        ),
      );
    }
  }

  Future<void> _showAddTenantDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final nationalIdController = TextEditingController();
    final occupantsController = TextEditingController(text: '1');

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: const Text(
            'Add Tenant',
            style: TextStyle(fontFamily: AppTheme.appFontFamily),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(hintText: 'Tenant Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(hintText: 'Phone Number'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nationalIdController,
                  decoration: const InputDecoration(hintText: 'National ID'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: occupantsController,
                  decoration: const InputDecoration(hintText: 'Number of Occupants'),
                  keyboardType: TextInputType.number,
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
                final name = nameController.text.trim();
                final phone = phoneController.text.trim();
                final nationalId = nationalIdController.text.trim();
                final occupantsText = occupantsController.text.trim();
                final occupants = int.tryParse(occupantsText) ?? 1;

                if (name.isEmpty || phone.isEmpty || nationalId.isEmpty) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.red.shade700,
                        content: const Text(
                          'All fields are required.',
                          style: TextStyle(fontFamily: AppTheme.appFontFamily),
                        ),
                      ),
                    );
                  }
                  return;
                }

                final occupancyValidationError = await _validateOccupantsForUnitType(occupants);
                if (occupancyValidationError != null) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.red.shade700,
                      content: Text(
                        occupancyValidationError,
                        style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                      ),
                    ),
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
                      return const Center(child: CircularProgressIndicator());
                    },
                  );

                  final tenant = await SupabaseService.instance.addTenantAndMarkUnitOccupied(
                    unitId: _unit.id,
                    fullName: name,
                    phoneNumber: phone,
                    nationalId: nationalId,
                    occupantsCount: occupants,
                  );

                  // Always dismiss the loading dialog first.
                  if (loadingDialogContext != null &&
                      Navigator.of(loadingDialogContext!).canPop()) {
                    Navigator.of(loadingDialogContext!).pop();
                    loadingDialogContext = null;
                  }

                  if (!mounted) return;

                  setState(() {
                    _tenant = tenant;
                    _unit = Unit(
                      id: _unit.id,
                      propertyId: _unit.propertyId,
                      unitNumber: _unit.unitNumber,
                      status: 'occupied',
                      tenantId: tenant.id,
                      unitType: _unit.unitType,
                    );
                  });
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Color(0xFF0D9488),
                      content: Text(
                        'Tenant added successfully.',
                        style: TextStyle(fontFamily: AppTheme.appFontFamily),
                      ),
                    ),
                  );
                } catch (error) {
                  // Ensure loading dialog does not outlive this operation.
                  if (loadingDialogContext != null &&
                      Navigator.of(loadingDialogContext!).canPop()) {
                    Navigator.of(loadingDialogContext!).pop();
                    loadingDialogContext = null;
                  }

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.red.shade700,
                        content: Text(
                          'Failed to add tenant: $error',
                          style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                        ),
                      ),
                    );
                  }
                }
              },
              child: const Text('Save Tenant'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
    nationalIdController.dispose();
    occupantsController.dispose();
  }

  Future<String?> _validateOccupantsForUnitType(int occupantsCount) async {
    if (occupantsCount < 1) {
      return 'Number of occupants must be at least 1.';
    }

    final normalizedUnitType = _unit.unitType?.trim().toLowerCase();
    if (normalizedUnitType == null || normalizedUnitType.isEmpty) {
      return null;
    }

    final organizationId = await SupabaseService.instance.getCurrentOrganizationId();

    if (organizationId != null) {
      final configuration = await SupabaseService.instance.getUnitConfigurationByType(
        organizationId: organizationId,
        unitTypeName: normalizedUnitType,
      );

      if (configuration != null) {
        if (occupantsCount < configuration.minOccupants ||
            occupantsCount > configuration.maxOccupants) {
          return '${configuration.unitTypeName} supports ${configuration.minOccupants}-${configuration.maxOccupants} occupants only.';
        }
        return null;
      }
    }

    final fallbackRule = _fallbackOccupancyRules[normalizedUnitType];
    if (fallbackRule == null) {
      return null;
    }

    if (occupantsCount < fallbackRule.$1 || occupantsCount > fallbackRule.$2) {
      return '${_unit.unitType} supports ${fallbackRule.$1}-${fallbackRule.$2} occupants only.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final occupied = _unit.isOccupied;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _unit.name,
          style: const TextStyle(fontFamily: AppTheme.appFontFamily),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: occupied && _tenant != null
            ? Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Tenant Profile',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontFamily: AppTheme.appFontFamily,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      _InfoRow(label: 'Name', value: _tenant!.name),
                      _PhoneRow(
                        label: 'Phone',
                        value: _tenant!.phoneNumber,
                        onTap: () => _launchDialer(_tenant!.phoneNumber),
                      ),
                      _InfoRow(label: 'National ID', value: _tenant!.nationalId),
                      _InfoRow(
                        label: 'Occupants',
                        value: _tenant!.occupants.toString(),
                      ),
                    ],
                  ),
                ),
              )
            : Center(
                child: ElevatedButton.icon(
                  onPressed: _showAddTenantDialog,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('+ Add Tenant'),
                ),
              ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontFamily: AppTheme.appFontFamily,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: AppTheme.appFontFamily),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneRow extends StatelessWidget {
  const _PhoneRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontFamily: AppTheme.appFontFamily,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Text(
                value,
                style: const TextStyle(
                  fontFamily: AppTheme.appFontFamily,
                  color: AppTheme.primaryColor,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
