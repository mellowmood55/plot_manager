import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme.dart';
import '../../../models/maintenance_request.dart';
import '../../../services/maintenance_service.dart';

class MaintenanceDetailScreen extends StatefulWidget {
  const MaintenanceDetailScreen({
    required this.requestId,
    super.key,
  });

  final String requestId;

  @override
  State<MaintenanceDetailScreen> createState() => _MaintenanceDetailScreenState();
}

class _MaintenanceDetailScreenState extends State<MaintenanceDetailScreen> {
  late Future<MaintenanceRequest> _requestFuture;
  bool _isResolving = false;

  @override
  void initState() {
    super.initState();
    _loadRequest();
  }

  void _loadRequest() {
    _requestFuture = MaintenanceService.instance.getMaintenanceRequestById(widget.requestId);
  }

  Future<void> _callContractor(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
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

  Future<void> _openResolveDialog(MaintenanceRequest request) async {
    final actualCostController = TextEditingController();
    File? afterPhoto;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceColor,
              title: const Text(
                'Mark as Resolved',
                style: TextStyle(fontFamily: AppTheme.appFontFamily),
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width > 600 ? 420 : double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: actualCostController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                        decoration: const InputDecoration(
                          labelText: 'Actual Cost',
                          prefixText: '\$ ',
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (afterPhoto != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            afterPhoto!,
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
                        onPressed: _isResolving
                            ? null
                            : () async {
                                try {
                                  final picked = await ImagePicker().pickImage(source: ImageSource.camera);
                                  if (picked == null) return;
                                  setDialogState(() {
                                    afterPhoto = File(picked.path);
                                  });
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: Colors.red.shade700,
                                      content: Text(
                                        'Failed to pick after photo: $e',
                                        style: const TextStyle(
                                          fontFamily: AppTheme.appFontFamily,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text(
                          'Capture After Photo',
                          style: TextStyle(fontFamily: AppTheme.appFontFamily),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isResolving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontFamily: AppTheme.appFontFamily),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isResolving
                      ? null
                      : () async {
                          final actualCost = double.tryParse(actualCostController.text.trim());
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
                            _isResolving = true;
                          });

                          try {
                            String? afterImageUrl;
                            if (afterPhoto != null) {
                              final path = await MaintenanceService.instance.uploadAfterMaintenanceImage(
                                afterPhoto!,
                                request.unitId,
                                request.id,
                              );
                              afterImageUrl = MaintenanceService.instance.getImageUrl(path);
                            }

                            await MaintenanceService.instance.resolveMaintenanceRequest(
                              requestId: request.id,
                              actualCost: actualCost,
                              afterImageUrl: afterImageUrl,
                            );

                            if (!mounted) return;
                            Navigator.of(dialogContext).pop();
                            setState(_loadRequest);
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
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.red.shade700,
                                content: Text(
                                  'Failed to resolve ticket: $e',
                                  style: const TextStyle(
                                    fontFamily: AppTheme.appFontFamily,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            );
                          } finally {
                            if (!mounted) return;
                            setState(() {
                              _isResolving = false;
                            });
                          }
                        },
                  child: _isResolving
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
            );
          },
        );
      },
    );

    actualCostController.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Maintenance Ticket',
          style: TextStyle(fontFamily: AppTheme.appFontFamily),
        ),
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

          final contractor = request.contractor;

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
                                color: _priorityColor(request.priority).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                request.priority.displayName,
                                style: TextStyle(
                                  fontFamily: AppTheme.appFontFamily,
                                  color: _priorityColor(request.priority),
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
                        if (request.resolvedAt != null)
                          Text(
                            'Resolved At: ${request.resolvedAt!.toLocal()}',
                            style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                          ),
                      ],
                    ),
                  ),
                ),
                if (contractor != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Assigned Contractor',
                            style: TextStyle(
                              fontFamily: AppTheme.appFontFamily,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            contractor.displayLabel,
                            style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                          ),
                          Text(
                            contractor.phone,
                            style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => _callContractor(contractor.phone),
                            icon: const Icon(Icons.call),
                            label: const Text(
                              'Call Handyman',
                              style: TextStyle(fontFamily: AppTheme.appFontFamily),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (request.imageUrl != null && request.imageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(request.imageUrl!, fit: BoxFit.cover),
                  ),
                ],
                if (request.afterImageUrl != null && request.afterImageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(request.afterImageUrl!, fit: BoxFit.cover),
                  ),
                ],
                const SizedBox(height: 16),
                if (request.status != MaintenanceStatus.completed &&
                    request.status != MaintenanceStatus.closed)
                  ElevatedButton.icon(
                    onPressed: _isResolving ? null : () => _openResolveDialog(request),
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      _isResolving ? 'Resolving...' : 'Mark as Resolved',
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
