import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/contractor.dart';
import '../models/maintenance_request.dart';

class MaintenanceService {
  MaintenanceService._();

  static final instance = MaintenanceService._();

  final _supabase = Supabase.instance.client;
  static const String _bucketName = 'maintenance_attachments';

  String normalizeLocationScope(String? location) {
    final raw = (location ?? '').trim().toLowerCase();
    if (raw.isEmpty) {
      return 'unscoped';
    }

    return raw
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
  }

  String _normalizeImageUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '';
    }

    final trimmed = value.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    return getImageUrl(trimmed);
  }

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
      final normalizedImageUrl = imageUrl == null || imageUrl.trim().isEmpty
          ? null
          : _normalizeImageUrl(imageUrl);

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
          'image_url': normalizedImageUrl,
          'contractor_id': contractorId,
        })
        .select('*, contractors(id, name, phone, specialty)')
        .single();

      return MaintenanceRequest.fromMap(response);
    } catch (e) {
      throw Exception('Failed to create maintenance request: $e');
    }
  }

  Future<String?> getLocationScopeByUnit(String unitId) async {
    try {
      final unitRow = await _supabase
          .from('units')
          .select('property_id')
          .eq('id', unitId)
          .maybeSingle();

      final propertyId = unitRow?['property_id'] as String?;
      if (propertyId == null || propertyId.isEmpty) {
        return null;
      }

      final propertyRow = await _supabase
          .from('properties')
          .select('location')
          .eq('id', propertyId)
          .maybeSingle();

      final location = propertyRow?['location'] as String?;
      if (location == null || location.trim().isEmpty) {
        return null;
      }

      return normalizeLocationScope(location);
    } catch (e) {
      throw Exception('Failed to resolve location scope by unit: $e');
    }
  }

  Future<List<Contractor>> getContractors({String? locationScope}) async {
    try {
      final scopedLocation = normalizeLocationScope(locationScope);
      final query = _supabase
          .from('contractors')
          .select();

      final response = scopedLocation == 'unscoped'
          ? await query.order('name', ascending: true)
          : await query
              .eq('location_scope', scopedLocation)
              .order('name', ascending: true);

      return (response as List)
          .map((item) => Contractor.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch contractors: $e');
    }
  }

  Future<Contractor?> getContractorById(String contractorId) async {
    try {
      final response = await _supabase
          .from('contractors')
          .select()
          .eq('id', contractorId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return Contractor.fromMap(response);
    } catch (e) {
      throw Exception('Failed to fetch contractor: $e');
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
      final normalizedAfterImageUrl = afterImageUrl == null || afterImageUrl.trim().isEmpty
          ? null
          : _normalizeImageUrl(afterImageUrl);

      await _supabase
        .from('maintenance_requests')
        .update({
          'status': MaintenanceStatus.completed.value,
          'actual_cost': actualCost,
          'resolved_at': DateTime.now().toUtc().toIso8601String(),
          if (normalizedAfterImageUrl != null) 'after_image_url': normalizedAfterImageUrl,
        })
        .eq('id', requestId);
    } catch (e) {
      throw Exception('Failed to resolve maintenance request: $e');
    }
  }

  Future<void> updateMaintenanceRequest({
    required String requestId,
    required String title,
    required String description,
    required String category,
    required MaintenancePriority priority,
    double? estimatedCost,
    String? imageUrl,
    String? contractorId,
  }) async {
    try {
      final normalizedImageUrl = imageUrl == null || imageUrl.trim().isEmpty
          ? null
          : _normalizeImageUrl(imageUrl);

      await _supabase
          .from('maintenance_requests')
          .update({
            'title': title,
            'description': description,
            'category': category,
            'priority': priority.value,
            'estimated_cost': estimatedCost,
            if (normalizedImageUrl != null) 'image_url': normalizedImageUrl,
            'contractor_id': contractorId,
          })
          .eq('id', requestId);
    } catch (e) {
      throw Exception('Failed to update maintenance request: $e');
    }
  }

  /// Update maintenance request status
  Future<void> updateMaintenanceStatus(
    String requestId,
    MaintenanceStatus status, {
    double? actualCost,
    String? imageUrl,
    String? afterImageUrl,
  }) async {
    try {
      final normalizedImageUrl = imageUrl == null || imageUrl.trim().isEmpty
          ? null
          : _normalizeImageUrl(imageUrl);
      final normalizedAfterImageUrl = afterImageUrl == null || afterImageUrl.trim().isEmpty
          ? null
          : _normalizeImageUrl(afterImageUrl);

      await _supabase
        .from('maintenance_requests')
        .update({
          'status': status.value,
          if (actualCost != null) 'actual_cost': actualCost,
          if (normalizedImageUrl != null) 'image_url': normalizedImageUrl,
          if (normalizedAfterImageUrl != null) 'after_image_url': normalizedAfterImageUrl,
        })
        .eq('id', requestId);
    } catch (e) {
      throw Exception('Failed to update maintenance status: $e');
    }
  }

  Future<String?> findOrCreateContractor({
    required String name,
    required String phone,
    required String specialty,
    required String locationScope,
  }) async {
    final normalizedName = name.trim();
    final normalizedPhone = phone.trim();
    final normalizedSpecialty = specialty.trim().isEmpty ? 'General Handyman' : specialty.trim();
    final normalizedLocationScope = normalizeLocationScope(locationScope);

    if (normalizedName.isEmpty || normalizedPhone.isEmpty) {
      return null;
    }

    try {
      final existing = await _supabase
          .from('contractors')
          .select('id, specialty, name')
          .eq('phone', normalizedPhone)
          .eq('location_scope', normalizedLocationScope)
          .maybeSingle();

      if (existing != null) {
        final existingId = existing['id'] as String;
        final currentSpecialty = (existing['specialty'] as String?) ?? '';

        final currentRoles = currentSpecialty
            .split(RegExp(r'[,/;|]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet();

        final newRoles = normalizedSpecialty
            .split(RegExp(r'[,/;|]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet();

        final mergedRoles = {...currentRoles, ...newRoles};
        final mergedSpecialty = mergedRoles.join(', ');

        final existingName = (existing['name'] as String?)?.trim() ?? '';

        await _supabase
            .from('contractors')
            .update({
              'name': existingName.isEmpty ? normalizedName : existingName,
              'specialty': mergedSpecialty.isEmpty ? normalizedSpecialty : mergedSpecialty,
              'location_scope': normalizedLocationScope,
            })
            .eq('id', existingId);

        return existingId;
      }

      final created = await _supabase
          .from('contractors')
          .insert({
            'name': normalizedName,
            'phone': normalizedPhone,
            'specialty': normalizedSpecialty,
            'location_scope': normalizedLocationScope,
          })
          .select('id')
          .single();

      return created['id'] as String;
    } catch (e) {
      throw Exception('Failed to create contractor: $e');
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

  String resolveImageUrl(String storedPathOrUrl) {
    if (storedPathOrUrl.startsWith('http://') ||
        storedPathOrUrl.startsWith('https://')) {
      return storedPathOrUrl;
    }
    return getImageUrl(storedPathOrUrl);
  }

  String _extractStoragePathFromUrl(String urlValue) {
    final uri = Uri.tryParse(urlValue);
    if (uri == null) {
      return urlValue;
    }

    final segments = uri.pathSegments;
    final publicIdx = segments.indexOf('public');
    if (publicIdx >= 0 && publicIdx + 2 < segments.length) {
      return segments.sublist(publicIdx + 2).join('/');
    }

    final signIdx = segments.indexOf('sign');
    if (signIdx >= 0 && signIdx + 2 < segments.length) {
      return segments.sublist(signIdx + 2).join('/');
    }

    return urlValue;
  }

  Future<String> getAccessibleImageUrl(String storedPathOrUrl) async {
    if (storedPathOrUrl.trim().isEmpty) {
      return '';
    }

    final normalized = storedPathOrUrl.trim();
    final looksLikeUrl =
        normalized.startsWith('http://') || normalized.startsWith('https://');

    final path = looksLikeUrl ? _extractStoragePathFromUrl(normalized) : normalized;

    print('Maintenance image resolve input: $normalized');
    print('Maintenance image resolve derived path: $path');

    if (path.trim().isEmpty) {
      return '';
    }

    try {
      final signedUrl = await _supabase.storage
          .from(_bucketName)
          .createSignedUrl(path, 60 * 60);
      if (signedUrl.isNotEmpty) {
        return signedUrl;
      }
    } catch (_) {
      // Fallback to public URL/original URL below.
    }

    if (looksLikeUrl && normalized.contains('/object/public/')) {
      return normalized;
    }

    return getImageUrl(path);
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
