import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme.dart';
import '../../../models/maintenance_request.dart';
import '../../../models/contractor.dart';
import 'add_maintenance_screen.dart';
import 'contractor_profile_screen.dart';
import '../../../services/maintenance_service.dart';
import '../../../services/supabase_service.dart';

abstract class MaintenanceDetailDataSource {
  Future<MaintenanceRequest> getMaintenanceRequestById(String requestId);
}

class _DefaultMaintenanceDetailDataSource implements MaintenanceDetailDataSource {
  const _DefaultMaintenanceDetailDataSource();

  @override
  Future<MaintenanceRequest> getMaintenanceRequestById(String requestId) {
    return MaintenanceService.instance.getMaintenanceRequestById(requestId);
  }
}

class MaintenanceDetailScreen extends StatefulWidget {
  const MaintenanceDetailScreen({
    required this.requestId,
    this.dataSource,
    super.key,
  });

  final String requestId;
  final MaintenanceDetailDataSource? dataSource;

  @override
  State<MaintenanceDetailScreen> createState() => _MaintenanceDetailScreenState();
}

class _MaintenanceDetailScreenState extends State<MaintenanceDetailScreen> {
  static const MaintenanceDetailDataSource _defaultDataSource = _DefaultMaintenanceDetailDataSource();
  late Future<MaintenanceRequest> _requestFuture;

  MaintenanceDetailDataSource get _dataSource => widget.dataSource ?? _defaultDataSource;

  @override
  void initState() {
    super.initState();
    _loadRequest();
  }

  void _loadRequest() {
    _requestFuture = _dataSource.getMaintenanceRequestById(widget.requestId);
  }

  Future<void> _callContractor(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      if (!mounted) return;
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.redAccent,
        content: Text(
          'Could not launch dialer for contractor.',
          style: TextStyle(fontFamily: AppTheme.appFontFamily),
        ),
      ),
    );
  }

  String _normalizeWhatsAppPhone(String rawPhone) {
    final digits = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return '';
    }

    // Default to Kenya-style normalization when user saves local numbers.
    if (digits.startsWith('254') && digits.length >= 12) {
      return digits;
    }
    if (digits.startsWith('0') && digits.length == 10) {
      return '254${digits.substring(1)}';
    }
    if (digits.startsWith('7') && digits.length == 9) {
      return '254$digits';
    }

    return digits;
  }

  Future<bool> _tryLaunchExternal(Uri uri) async {
    if (!await canLaunchUrl(uri)) {
      return false;
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _sendJobBrief(MaintenanceRequest request) async {
    final contractor = request.contractor;
    final phone = contractor?.phone.trim() ?? '';
    if (contractor == null || phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            'No contractor is assigned to this ticket.',
            style: TextStyle(fontFamily: AppTheme.appFontFamily),
          ),
        ),
      );
      return;
    }

    final unit = await SupabaseService.instance.fetchUnitById(request.unitId);
    if (!mounted) {
      return;
    }

    final unitNumber = unit?.unitNumber.trim().isNotEmpty == true ? unit!.unitNumber : request.unitId;
    final message =
        'Plot Manager Brief:\n'
        'Unit: $unitNumber\n'
        'Issue: ${request.title}\n'
        'Category: ${request.category}\n'
        'Est. Cost: ${request.estimatedCost == null ? '-' : '\$${request.estimatedCost!.toStringAsFixed(2)}'}\n'
        'Please confirm receipt.';

    final whatsappPhone = _normalizeWhatsAppPhone(phone);
    if (whatsappPhone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            'The contractor phone number is invalid for WhatsApp.',
            style: TextStyle(fontFamily: AppTheme.appFontFamily),
          ),
        ),
      );
      return;
    }

    final encodedMessage = Uri.encodeComponent(message);
    final whatsappUri = Uri.parse(
      'whatsapp://send?phone=$whatsappPhone&text=$encodedMessage',
    );
    final waMeUri = Uri.parse('https://wa.me/$whatsappPhone?text=$encodedMessage');

    if (await _tryLaunchExternal(whatsappUri)) {
      return;
    }

    if (await _tryLaunchExternal(waMeUri)) {
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.redAccent,
        content: Text(
          'This number is not on WhatsApp, or WhatsApp is unavailable on this device.',
          style: TextStyle(fontFamily: AppTheme.appFontFamily),
        ),
      ),
    );
  }

  Future<void> _openContractorProfile(Contractor contractor) async {
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContractorProfileScreen(
          contractorId: contractor.id,
          initialContractor: contractor,
        ),
      ),
    );

    if (!mounted) return;
    setState(_loadRequest);
  }

  Future<void> _openResolveDialog(MaintenanceRequest request) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final resolved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _ResolveMaintenanceScreen(request: request),
      ),
    );

    if (!mounted) return;
    if (resolved == true) {
      setState(() {
        _loadRequest();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF0D9488),
          content: Text(
            'Ticket marked as resolved.',
            style: TextStyle(
              fontFamily: AppTheme.appFontFamily,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _openEditScreen(MaintenanceRequest request) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddMaintenanceScreen(
          unitId: request.unitId,
          initialRequest: request,
        ),
      ),
    );

    if (!mounted) return;
    if (updated == true) {
      setState(_loadRequest);
    }
  }

  Color _priorityColor(MaintenancePriority priority) {
    switch (priority) {
      case MaintenancePriority.high:
        return Colors.red;
      case MaintenancePriority.medium:
        return Colors.orange;
      case MaintenancePriority.low:
        return Colors.teal;
    }
  }

  Color _priorityBackgroundColor(MaintenancePriority priority) {
    switch (priority) {
      case MaintenancePriority.high:
        return Colors.red.withValues(alpha: 0.2);
      case MaintenancePriority.medium:
        return const Color(0xFFCC7A00);
      case MaintenancePriority.low:
        return Colors.teal.withValues(alpha: 0.2);
    }
  }

  Color _priorityTextColor(MaintenancePriority priority) {
    switch (priority) {
      case MaintenancePriority.medium:
        return Colors.white;
      default:
        return _priorityColor(priority);
    }
  }

  Widget _buildContractorSection(MaintenanceRequest request) {
    if (request.contractor != null) {
      return _buildContractorRow(request.contractor!);
    }

    if (request.contractorId == null || request.contractorId!.isEmpty) {
      return const Text(
        'Assigned Contractor: Not Assigned',
        style: TextStyle(fontFamily: AppTheme.appFontFamily),
      );
    }

    // Safety: if contractor_id exists but relation was not expanded, fetch it directly.
    return FutureBuilder<Contractor?>(
      future: MaintenanceService.instance.getContractorById(request.contractorId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: LinearProgressIndicator(),
          );
        }

        final contractor = snapshot.data;
        if (contractor == null) {
          return const Text(
            'Assigned Contractor: Not Assigned',
            style: TextStyle(fontFamily: AppTheme.appFontFamily),
          );
        }

        return _buildContractorRow(contractor);
      },
    );
  }

  Widget _buildContractorRow(Contractor contractor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Assigned Contractor: ${contractor.name} - ${contractor.specialty}',
          style: const TextStyle(fontFamily: AppTheme.appFontFamily),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: () => _callContractor(contractor.phone),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              icon: const Icon(Icons.call, size: 16),
              label: const Text(
                'Call Contractor',
                style: TextStyle(fontFamily: AppTheme.appFontFamily),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                _openContractorProfile(contractor);
              },
              icon: const Icon(Icons.person),
              label: const Text(
                'View Profile',
                style: TextStyle(fontFamily: AppTheme.appFontFamily),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openImagePreview({
    required String title,
    required String? storedPathOrUrl,
    required String emptyMessage,
  }) async {
    final messenger = ScaffoldMessenger.of(context);

    if (storedPathOrUrl == null || storedPathOrUrl.trim().isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            emptyMessage,
            style: const TextStyle(
              fontFamily: AppTheme.appFontFamily,
              color: Colors.white,
            ),
          ),
        ),
      );
      return;
    }

    final resolvedUrl = await MaintenanceService.instance.getAccessibleImageUrl(storedPathOrUrl);
    if (!mounted) return;

    if (resolvedUrl.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            emptyMessage,
            style: const TextStyle(
              fontFamily: AppTheme.appFontFamily,
              color: Colors.white,
            ),
          ),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: AppTheme.surfaceColor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontFamily: AppTheme.appFontFamily,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () {
                        if (Navigator.of(dialogContext).canPop()) {
                          Navigator.of(dialogContext).pop();
                        }
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  child: Image.network(
                    resolvedUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox(
                        height: 220,
                        child: Center(
                          child: Text(
                            'No Image Available',
                            style: TextStyle(
                              fontFamily: AppTheme.appFontFamily,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Maintenance Ticket',
          style: TextStyle(fontFamily: AppTheme.appFontFamily),
        ),
        actions: [
          FutureBuilder<MaintenanceRequest>(
            future: _requestFuture,
            builder: (context, snapshot) {
              final req = snapshot.data;
              if (req == null) {
                return const SizedBox.shrink();
              }

              final actions = <Widget>[
                if (req.contractor != null)
                  IconButton(
                    tooltip: 'Send Job Brief',
                    onPressed: () => _sendJobBrief(req),
                    icon: const Icon(
                      FontAwesomeIcons.whatsapp,
                      color: Color(0xFF25D366),
                    ),
                  ),
                if (req.status == MaintenanceStatus.open)
                  IconButton(
                    tooltip: 'Edit Ticket',
                    onPressed: () => _openEditScreen(req),
                    icon: const Icon(Icons.edit),
                  ),
              ];

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: actions,
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<MaintenanceRequest>(
        future: _requestFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load ticket: ${snapshot.error}',
                style: const TextStyle(fontFamily: AppTheme.appFontFamily),
              ),
            );
          }

          final request = snapshot.data;
          if (request == null) {
            return const Center(
              child: Text(
                'Ticket not found.',
                style: TextStyle(fontFamily: AppTheme.appFontFamily),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                request.title,
                                style: const TextStyle(
                                  fontFamily: AppTheme.appFontFamily,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _priorityBackgroundColor(request.priority),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                request.priority.displayName,
                                style: TextStyle(
                                  fontFamily: AppTheme.appFontFamily,
                                  color: _priorityTextColor(request.priority),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Category: ${request.category}',
                          style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          request.description,
                          style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Estimated Cost: ${request.estimatedCost == null ? '-' : '\$${request.estimatedCost!.toStringAsFixed(2)}'}',
                          style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                        ),
                        Text(
                          'Actual Cost: ${request.actualCost == null ? '-' : '\$${request.actualCost!.toStringAsFixed(2)}'}',
                          style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                        ),
                        Text(
                          'Status: ${request.status.displayName}',
                          style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                        ),
                        const SizedBox(height: 8),
                        _buildContractorSection(request),
                        if (request.resolvedAt != null)
                          Text(
                            'Resolved At: ${request.resolvedAt!.toLocal()}',
                            style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _openImagePreview(
                        title: 'Before Image',
                        storedPathOrUrl: request.imageUrl,
                        emptyMessage: 'No Before Image Available',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text(
                        'View Before Image',
                        style: TextStyle(fontFamily: AppTheme.appFontFamily),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openImagePreview(
                        title: 'After Image',
                        storedPathOrUrl: request.afterImageUrl,
                        emptyMessage: 'No After Image Available',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text(
                        'View After Image',
                        style: TextStyle(fontFamily: AppTheme.appFontFamily),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (request.status != MaintenanceStatus.completed &&
                    request.status != MaintenanceStatus.closed)
                  ElevatedButton.icon(
                    onPressed: () => _openResolveDialog(request),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text(
                      'Mark as Resolved',
                      style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ResolveMaintenanceScreen extends StatefulWidget {
  const _ResolveMaintenanceScreen({required this.request});

  final MaintenanceRequest request;

  @override
  State<_ResolveMaintenanceScreen> createState() => _ResolveMaintenanceScreenState();
}

class _ResolveMaintenanceScreenState extends State<_ResolveMaintenanceScreen> {
  final _actualCostController = TextEditingController();
  File? _afterPhoto;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _actualCostController.dispose();
    super.dispose();
  }

  Future<void> _pickAfterPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (!mounted) return;
      if (picked == null) return;

      setState(() {
        _afterPhoto = File(picked.path);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            'Failed to pick after photo: $error',
            style: const TextStyle(
              fontFamily: AppTheme.appFontFamily,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _confirmResolution() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final actualCost = double.tryParse(_actualCostController.text.trim());
    if (actualCost == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            'Enter a valid actual cost before resolving.',
            style: TextStyle(fontFamily: AppTheme.appFontFamily),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      String? afterImageUrl;
      if (_afterPhoto != null) {
        final path = await MaintenanceService.instance.uploadAfterMaintenanceImage(
          _afterPhoto!,
          widget.request.unitId,
          widget.request.id,
        );
        if (!mounted) return;
        afterImageUrl = MaintenanceService.instance.getImageUrl(path);
      }

      await MaintenanceService.instance.resolveMaintenanceRequest(
        requestId: widget.request.id,
        actualCost: actualCost,
        afterImageUrl: afterImageUrl,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            'Failed to resolve ticket: $error',
            style: const TextStyle(
              fontFamily: AppTheme.appFontFamily,
              color: Colors.white,
            ),
          ),
        ),
      );
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mark as Resolved',
          style: TextStyle(fontFamily: AppTheme.appFontFamily),
        ),
        leading: IconButton(
          onPressed: _isSubmitting
              ? null
              : () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  Navigator.of(context).pop(false);
                },
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _actualCostController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontFamily: AppTheme.appFontFamily),
              decoration: const InputDecoration(
                labelText: 'Actual Cost',
                prefixText: '\$ ',
              ),
            ),
            const SizedBox(height: 12),
            if (_afterPhoto != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  _afterPhoto!,
                  height: 180,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text(
                    'No After Photo Selected',
                    style: TextStyle(fontFamily: AppTheme.appFontFamily),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isSubmitting ? null : _pickAfterPhoto,
              icon: const Icon(Icons.folder_open),
              label: const Text(
                'Choose After Image File',
                style: TextStyle(fontFamily: AppTheme.appFontFamily),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _confirmResolution,
              icon: const Icon(Icons.check_circle_outline),
              label: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Confirm Resolution',
                      style: TextStyle(fontFamily: AppTheme.appFontFamily),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
