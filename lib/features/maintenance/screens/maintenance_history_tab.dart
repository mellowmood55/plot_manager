import 'package:flutter/material.dart';
import '../../../models/maintenance_request.dart';
import '../../../services/maintenance_service.dart';
import 'add_maintenance_screen.dart';
import 'maintenance_detail_screen.dart';

class MaintenanceHistoryTab extends StatefulWidget {
  final String unitId;
  final VoidCallback? onMaintenanceChanged;

  const MaintenanceHistoryTab({
    Key? key,
    required this.unitId,
    this.onMaintenanceChanged,
  }) : super(key: key);

  @override
  State<MaintenanceHistoryTab> createState() => _MaintenanceHistoryTabState();
}

class _MaintenanceHistoryTabState extends State<MaintenanceHistoryTab> {
  late Future<List<MaintenanceRequest>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    _historyFuture = MaintenanceService.instance.getUnitMaintenanceHistory(widget.unitId);
  }

  Color _getPriorityColor(MaintenancePriority priority) {
    switch (priority) {
      case MaintenancePriority.high:
        return Colors.red;
      case MaintenancePriority.medium:
        return Colors.orange;
      case MaintenancePriority.low:
        return Colors.teal;
    }
  }

  Color _getStatusColor(MaintenanceStatus status) {
    switch (status) {
      case MaintenanceStatus.open:
        return Colors.red;
      case MaintenanceStatus.inProgress:
        return Colors.orange;
      case MaintenanceStatus.completed:
        return Colors.green;
      case MaintenanceStatus.closed:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MaintenanceRequest>>(
      future: _historyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(fontFamily: 'Comic Sans MS'),
            ),
          );
        }

        final requests = snapshot.data ?? [];

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (context) => AddMaintenanceScreen(
                          unitId: widget.unitId,
                        ),
                      ),
                    )
                    .then((_) {
                      if (mounted) {
                        setState(() => _loadHistory());
                      }
                      widget.onMaintenanceChanged?.call();
                    });
                },
                icon: const Icon(Icons.add),
                label: const Text(
                  'Report Issue',
                  style: TextStyle(fontFamily: 'Comic Sans MS'),
                ),
              ),
            ),
            Expanded(
              child: requests.isEmpty
                ? Center(
                    child: Text(
                      'No maintenance records',
                      style: const TextStyle(fontFamily: 'Comic Sans MS'),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final request = requests[index];
                      return GestureDetector(
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MaintenanceDetailScreen(requestId: request.id),
                            ),
                          );
                          if (!mounted) return;
                          setState(_loadHistory);
                          widget.onMaintenanceChanged?.call();
                        },
                        child: _MaintenanceCard(
                          request: request,
                          priorityColor: _getPriorityColor(request.priority),
                          statusColor: _getStatusColor(request.status),
                        ),
                      );
                    },
                  ),
            ),
          ],
        );
      },
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  final MaintenanceRequest request;
  final Color priorityColor;
  final Color statusColor;

  const _MaintenanceCard({
    required this.request,
    required this.priorityColor,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    request.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Comic Sans MS',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(
                  width: isSmallScreen ? 80 : 100,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      request.priority.displayName.split(' ').first,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: priorityColor,
                        fontFamily: 'Comic Sans MS',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (request.description.isNotEmpty)
              Text(
                request.description,
                style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'Comic Sans MS',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text(
                    request.status.displayName,
                    style: const TextStyle(
                      fontFamily: 'Comic Sans MS',
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: statusColor.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: statusColor,
                    fontFamily: 'Comic Sans MS',
                  ),
                ),
                Text(
                  _formatDate(request.createdAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontFamily: 'Comic Sans MS',
                  ),
                ),
              ],
            ),
            if (request.estimatedCost != null || request.actualCost != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (request.estimatedCost != null)
                    Text(
                      'Est: \$${request.estimatedCost!.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'Comic Sans MS',
                      ),
                    ),
                  if (request.actualCost != null)
                    Text(
                      'Actual: \$${request.actualCost!.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'Comic Sans MS',
                        color: Color(0xFF8B7355),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
