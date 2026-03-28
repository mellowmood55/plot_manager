class MaintenanceRequest {
  final String id;
  final String unitId;
  final String title;
  final String description;
  final MaintenancePriority priority;
  final MaintenanceStatus status;
  final double? estimatedCost;
  final double? actualCost;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  MaintenanceRequest({
    required this.id,
    required this.unitId,
    required this.title,
    required this.description,
    required this.priority,
    required this.status,
    this.estimatedCost,
    this.actualCost,
    this.imageUrl,
    required this.createdAt,
    this.updatedAt,
  });

  factory MaintenanceRequest.fromMap(Map<String, dynamic> map) {
    return MaintenanceRequest(
      id: map['id'] as String,
      unitId: map['unit_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      priority: MaintenancePriority.fromString(map['priority'] as String),
      status: MaintenanceStatus.fromString(map['status'] as String),
      estimatedCost: map['estimated_cost'] != null 
        ? (map['estimated_cost'] as num).toDouble() 
        : null,
      actualCost: map['actual_cost'] != null 
        ? (map['actual_cost'] as num).toDouble() 
        : null,
      imageUrl: map['image_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      updatedAt: map['updated_at'] != null 
        ? DateTime.parse(map['updated_at'] as String).toLocal()
        : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'unit_id': unitId,
      'title': title,
      'description': description,
      'priority': priority.value,
      'status': status.value,
      'estimated_cost': estimatedCost,
      'actual_cost': actualCost,
      'image_url': imageUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

enum MaintenancePriority {
  low('low'),
  medium('medium'),
  high('high');

  final String value;
  
  const MaintenancePriority(this.value);

  factory MaintenancePriority.fromString(String value) {
    return MaintenancePriority.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MaintenancePriority.medium,
    );
  }

  String get displayName {
    switch (this) {
      case MaintenancePriority.low:
        return 'Low Priority';
      case MaintenancePriority.medium:
        return 'Medium Priority';
      case MaintenancePriority.high:
        return 'High Priority';
    }
  }
}

enum MaintenanceStatus {
  open('open'),
  inProgress('in_progress'),
  completed('completed'),
  closed('closed');

  final String value;
  
  const MaintenanceStatus(this.value);

  factory MaintenanceStatus.fromString(String value) {
    return MaintenanceStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MaintenanceStatus.open,
    );
  }

  String get displayName {
    switch (this) {
      case MaintenanceStatus.open:
        return 'Open';
      case MaintenanceStatus.inProgress:
        return 'In Progress';
      case MaintenanceStatus.completed:
        return 'Completed';
      case MaintenanceStatus.closed:
        return 'Closed';
    }
  }
}
