import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../models/maintenance_request.dart';
import '../../../services/maintenance_service.dart';
import 'add_maintenance_screen.dart';

class MaintenanceListScreen extends StatefulWidget {
  const MaintenanceListScreen({Key? key}) : super(key: key);

  @override
  State<MaintenanceListScreen> createState() => _MaintenanceListScreenState();
}

class _MaintenanceListScreenState extends State<MaintenanceListScreen> {
  late Future<List<MaintenanceRequest>> _requestsFuture;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  void _loadRequests() {
    _requestsFuture = MaintenanceService.instance.getActiveMaintenanceRequests();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Maintenance Requests'),
        elevation: 0,
      ),
      body: FutureBuilder<List<MaintenanceRequest>>(
        future: _requestsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
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
          if (requests.isEmpty) {
            return Center(
              child: Text(
                'No active maintenance requests',
                style: const TextStyle(fontFamily: 'Comic Sans MS'),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return _MaintenanceRequestCard(
                request: request,
                priorityColor: _getPriorityColor(request.priority),
                onRefresh: _loadRequests,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (context) => const AddMaintenanceScreen(),
              ),
            )
            .then((_) {
              if (mounted) {
                setState(() => _loadRequests());
              }
            });
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _MaintenanceRequestCard extends StatelessWidget {
  final MaintenanceRequest request;
  final Color priorityColor;
  final VoidCallback onRefresh;

  const _MaintenanceRequestCard({
    required this.request,
    required this.priorityColor,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    request.priority.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: priorityColor,
                      fontFamily: 'Comic Sans MS',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              request.description,
              style: const TextStyle(
                fontSize: 14,
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
                    style: const TextStyle(fontFamily: 'Comic Sans MS'),
                  ),
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                ),
                Text(
                  _formatDate(request.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontFamily: 'Comic Sans MS',
                  ),
                ),
              ],
            ),
            if (request.estimatedCost != null) ...[
              const SizedBox(height: 8),
              Text(
                'Est. Cost: \$${request.estimatedCost!.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'Comic Sans MS',
                ),
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
      return '${diff.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
