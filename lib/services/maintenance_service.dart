import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/contractor.dart';
import '../models/maintenance_request.dart';

class MaintenanceService {
  MaintenanceService._();

  static final instance = MaintenanceService._();

  final _supabase = Supabase.instance.client;
  static const String _bucketName = 'maintenance_attachments';

  /// Fetch all active maintenance requests across landlord's organization
  Future<List<MaintenanceRequest>> getActiveMaintenanceRequests() async {
    try {
      final response = await _supabase
        .from('maintenance_requests')
        .select('*, contractors(id, name, phone, specialty)')
        .inFilter('status', ['open', 'in_progress'])
        .order('created_at', ascending: false);

      return (response as List)
        .map((item) => MaintenanceRequest.fromMap(item as Map<String, dynamic>))
        .toList();
    } catch (e) {
      throw Exception('Failed to fetch maintenance requests: $e');
    }
  }

  /// Fetch maintenance history for a specific unit
  Future<List<MaintenanceRequest>> getUnitMaintenanceHistory(String unitId) async {
    try {
      final response = await _supabase
        .from('maintenance_requests')
        .select('*, contractors(id, name, phone, specialty)')
        .eq('unit_id', unitId)
        .order('created_at', ascending: false);

      return (response as List)
        .map((item) => MaintenanceRequest.fromMap(item as Map<String, dynamic>))
        .toList();
    } catch (e) {
      throw Exception('Failed to fetch unit maintenance history: $e');
    }
  }

  /// Create a new maintenance request
  Future<MaintenanceRequest> createMaintenanceRequest({
    required String unitId,
    required String title,
    required String description,
    required String category,
    required MaintenancePriority priority,
    double? estimatedCost,
    String? imageUrl,
    String? contractorId,
  }) async {
    try {
      final response = await _supabase
        .from('maintenance_requests')
        .insert({
          'unit_id': unitId,
          'title': title,
          'description': description,
          'category': category,
          'priority': priority.value,
          'status': 'open',
          'estimated_cost': estimatedCost,
          'image_url': imageUrl,
          'contractor_id': contractorId,
        })
        .select('*, contractors(id, name, phone, specialty)')
        .single();

      return MaintenanceRequest.fromMap(response);
    } catch (e) {
      throw Exception('Failed to create maintenance request: $e');
    }
  }

  Future<List<Contractor>> getContractors() async {
    try {
      final response = await _supabase
        .from('contractors')
        .select()
        .order('name', ascending: true);

      return (response as List)
          .map((item) => Contractor.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch contractors: $e');
    }
  }

  Future<MaintenanceRequest> getMaintenanceRequestById(String requestId) async {
    try {
      final response = await _supabase
          .from('maintenance_requests')
          .select('*, contractors(id, name, phone, specialty)')
          .eq('id', requestId)
          .single();

      return MaintenanceRequest.fromMap(response);
    } catch (e) {
      throw Exception('Failed to fetch maintenance request: $e');
    }
  }

  Future<void> resolveMaintenanceRequest({
    required String requestId,
    required double actualCost,
    String? afterImageUrl,
  }) async {
    try {
      await _supabase
        .from('maintenance_requests')
        .update({
          'status': MaintenanceStatus.completed.value,
          'actual_cost': actualCost,
          'resolved_at': DateTime.now().toUtc().toIso8601String(),
          if (afterImageUrl != null) 'after_image_url': afterImageUrl,
        })
        .eq('id', requestId);
    } catch (e) {
      throw Exception('Failed to resolve maintenance request: $e');
    }
  }

  /// Update maintenance request status
  Future<void> updateMaintenanceStatus(
    String requestId,
    MaintenanceStatus status, {
    double? actualCost,
  }) async {
    try {
      await _supabase
        .from('maintenance_requests')
        .update({
          'status': status.value,
          if (actualCost != null) 'actual_cost': actualCost,
        })
        .eq('id', requestId);
    } catch (e) {
      throw Exception('Failed to update maintenance status: $e');
    }
  }

  /// Upload image to Supabase Storage bucket with mounted check support
  Future<String> uploadMaintenanceImage(
    File imageFile,
    String unitId,
    String requestId,
  ) async {
    try {
      // Ensure bucket exists (bucket must be created in Supabase Dashboard first)
      final fileName = 'maintenance/$unitId/$requestId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      final response = await _supabase.storage
        .from(_bucketName)
        .upload(fileName, imageFile);

      if (response.isEmpty) {
        throw Exception('Upload returned empty path');
      }

      final fullUrl = getImageUrl(fileName);
      print('Maintenance upload URL: $fullUrl');

      return fileName;
    } catch (e) {
      throw Exception('Failed to upload maintenance image: $e');
    }
  }

  Future<String> uploadAfterMaintenanceImage(
    File imageFile,
    String unitId,
    String requestId,
  ) async {
    try {
      final fileName = 'maintenance/$unitId/$requestId/after_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final response = await _supabase.storage
          .from(_bucketName)
          .upload(fileName, imageFile);

      if (response.isEmpty) {
        throw Exception('Upload returned empty path');
      }

      final fullUrl = getImageUrl(fileName);
      print('Maintenance after-image URL: $fullUrl');

      return fileName;
    } catch (e) {
      throw Exception('Failed to upload after image: $e');
    }
  }

  /// Get public image URL for completed upload
  String getImageUrl(String filePath) {
    return _supabase.storage
      .from(_bucketName)
      .getPublicUrl(filePath);
  }

  /// Delete maintenance request
  Future<void> deleteMaintenanceRequest(String requestId) async {
    try {
      // Fetch image URL before deletion to clean up storage
      final request = await _supabase
        .from('maintenance_requests')
        .select('image_url')
        .eq('id', requestId)
        .single();
      
      final imageUrl = request['image_url'] as String?;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          await _supabase.storage
            .from(_bucketName)
            .remove([imageUrl]);
        } catch (e) {
          // Keep deletion resilient even when storage cleanup fails.
          print('Maintenance cleanup warning: failed to delete image from storage: $e');
        }
      }

      await _supabase
        .from('maintenance_requests')
        .delete()
        .eq('id', requestId);
    } catch (e) {
      throw Exception('Failed to delete maintenance request: $e');
    }
  }
}
