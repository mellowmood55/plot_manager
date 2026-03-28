import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
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
        .select()
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
        .select()
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
    required MaintenancePriority priority,
    double? estimatedCost,
    String? imageUrl,
  }) async {
    try {
      final response = await _supabase
        .from('maintenance_requests')
        .insert({
          'unit_id': unitId,
          'title': title,
          'description': description,
          'priority': priority.value,
          'status': 'open',
          'estimated_cost': estimatedCost,
          'image_url': imageUrl,
        })
        .select()
        .single();

      return MaintenanceRequest.fromMap(response);
    } catch (e) {
      throw Exception('Failed to create maintenance request: $e');
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

      return fileName;
    } catch (e) {
      throw Exception('Failed to upload maintenance image: $e');
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
          // Log but don't fail deletion if image cleanup fails
          print('Warning: Failed to delete image from storage: $e');
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
