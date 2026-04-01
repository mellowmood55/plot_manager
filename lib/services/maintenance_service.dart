import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/contractor.dart';
import '../models/maintenance_request.dart';

class MaintenanceService {
  MaintenanceService._();

  static final instance = MaintenanceService._();

  final _supabase = Supabase.instance.client;
  static const String _bucketName = 'maintenance_attachments';
  static const List<String> contractorSpecialties = [
    'General Handyman',
    'Plumbing',
    'Electrical',
    'Painting',
    'Carpentry',
    'Masonry',
  ];

  String normalizeContractorSpecialty(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    if (value.isEmpty) {
      return 'General Handyman';
    }

    if (value.contains('plumb') || value.contains('pipe')) {
      return 'Plumbing';
    }
    if (value.contains('elect') || value.contains('wire') || value.contains('socket')) {
      return 'Electrical';
    }
    if (value.contains('paint')) {
      return 'Painting';
    }
    if (value.contains('carp') || value.contains('wood')) {
      return 'Carpentry';
    }
    if (value.contains('mason') || value.contains('brick') || value.contains('wall')) {
      return 'Masonry';
    }

    return contractorSpecialties.firstWhere(
      (specialty) => specialty.toLowerCase() == value,
      orElse: () => 'General Handyman',
    );
  }

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
        .select('*, contractors(id, name, phone, specialty, organization_id, reliability_score)')
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
        .select('*, contractors(id, name, phone, specialty, organization_id, reliability_score)')
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
        .select('*, contractors(id, name, phone, specialty, organization_id, reliability_score)')
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

  Future<List<Contractor>> getContractors({
    String? organizationId,
    String? specialty,
    String? locationScope,
  }) async {
    return getContractorsByOrganization(
      organizationId: organizationId ?? await SupabaseService.instance.getCurrentOrganizationId(),
      specialty: specialty ?? locationScope,
    );
  }

  Future<List<Contractor>> getContractorsByOrganization({
    String? organizationId,
    String? specialty,
  }) async {
    try {
      final resolvedOrganizationId = organizationId ?? await SupabaseService.instance.getCurrentOrganizationId();
      if (resolvedOrganizationId == null || resolvedOrganizationId.isEmpty) {
        return [];
      }

      final normalizedSpecialty = specialty == null ? null : normalizeContractorSpecialty(specialty);
      final specialtyFilter = normalizedSpecialty == null ||
              normalizedSpecialty.isEmpty ||
              normalizedSpecialty.toLowerCase() == 'general'
          ? null
          : normalizedSpecialty;

      final query = _supabase
          .from('contractors')
          .select('id, name, phone, specialty, organization_id, reliability_score, location_scope')
          .eq('organization_id', resolvedOrganizationId);

      final response = specialtyFilter == null
          ? await query.order('reliability_score', ascending: false).order('name', ascending: true)
          : await query
              .ilike('specialty', '%$specialtyFilter%')
              .order('reliability_score', ascending: false)
              .order('name', ascending: true);

      return (response as List)
          .map((item) => Contractor.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch contractors: $e');
    }
  }

  Future<Map<String, int>> getActiveTicketCountsByContractor({String? organizationId}) async {
    try {
      final resolvedOrganizationId = organizationId ?? await SupabaseService.instance.getCurrentOrganizationId();
      if (resolvedOrganizationId == null || resolvedOrganizationId.isEmpty) {
        return {};
      }

      final response = await _supabase
          .from('maintenance_requests')
          .select('contractor_id, status')
          .inFilter('status', ['open', 'in_progress']);

      final counts = <String, int>{};
      for (final row in response as List) {
        final contractorId = row['contractor_id']?.toString();
        if (contractorId == null || contractorId.isEmpty) {
          continue;
        }

        counts[contractorId] = (counts[contractorId] ?? 0) + 1;
      }

      return counts;
    } catch (e) {
      throw Exception('Failed to fetch contractor ticket counts: $e');
    }
  }

  Future<List<Contractor>> getSmartContractorsForCategory(
    String category, {
    String? organizationId,
  }) async {
    try {
      final resolvedOrganizationId = organizationId ?? await SupabaseService.instance.getCurrentOrganizationId();
      if (resolvedOrganizationId == null || resolvedOrganizationId.isEmpty) {
        return [];
      }

      final contractors = await getContractorsByOrganization(
        organizationId: resolvedOrganizationId,
        specialty: category,
      );
      final activeTicketCounts = await getActiveTicketCountsByContractor(
        organizationId: resolvedOrganizationId,
      );

      contractors.sort((left, right) {
        final leftActive = activeTicketCounts[left.id] ?? 0;
        final rightActive = activeTicketCounts[right.id] ?? 0;

        final leftRecommended = leftActive == 0;
        final rightRecommended = rightActive == 0;
        if (leftRecommended != rightRecommended) {
          return leftRecommended ? -1 : 1;
        }

        final scoreCompare = right.reliabilityScore.compareTo(left.reliabilityScore);
        if (scoreCompare != 0) {
          return scoreCompare;
        }

        final activeCompare = leftActive.compareTo(rightActive);
        if (activeCompare != 0) {
          return activeCompare;
        }

        return left.name.toLowerCase().compareTo(right.name.toLowerCase());
      });

      return contractors;
    } catch (e) {
      throw Exception('Failed to fetch smart contractor suggestions: $e');
    }
  }

  Future<Contractor?> saveContractor({
    required String name,
    required String phone,
    required String specialty,
    required String organizationId,
    double reliabilityScore = 0,
  }) async {
    final normalizedName = name.trim();
    final normalizedPhone = phone.trim();
    final normalizedSpecialty = normalizeContractorSpecialty(specialty);
    final normalizedScore = reliabilityScore.clamp(0, 5).toDouble();

    if (normalizedName.isEmpty || normalizedPhone.isEmpty) {
      return null;
    }

    try {
      final existing = await _supabase
          .from('contractors')
          .select('id')
          .eq('organization_id', organizationId)
          .eq('phone', normalizedPhone)
          .maybeSingle();

      if (existing != null) {
        final contractorId = existing['id'] as String;
        await _supabase
            .from('contractors')
            .update({
              'name': normalizedName,
              'phone': normalizedPhone,
              'specialty': normalizedSpecialty,
              'organization_id': organizationId,
              'reliability_score': normalizedScore,
            })
            .eq('id', contractorId);

        return await getContractorById(contractorId);
      }

      final created = await _supabase
          .from('contractors')
          .insert({
            'name': normalizedName,
            'phone': normalizedPhone,
            'specialty': normalizedSpecialty,
            'organization_id': organizationId,
            'reliability_score': normalizedScore,
          })
          .select('id, name, phone, specialty, organization_id, reliability_score, location_scope')
          .single();

      return Contractor.fromMap(created);
    } catch (e) {
      throw Exception('Failed to save contractor: $e');
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

  Future<List<MaintenanceRequest>> getMaintenanceRequestsByContractor(String contractorId) async {
    try {
      final response = await _supabase
          .from('maintenance_requests')
          .select('*, contractors(id, name, phone, specialty)')
          .eq('contractor_id', contractorId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => MaintenanceRequest.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch contractor history: $e');
    }
  }

  Future<double> getUnitMaintenanceSpend(String unitId) async {
    try {
      final response = await _supabase
          .from('maintenance_requests')
          .select('actual_cost, status')
          .eq('unit_id', unitId)
          .inFilter('status', ['completed', 'closed'])
          .not('actual_cost', 'is', null);

      double total = 0;
      for (final row in response as List) {
        final raw = row['actual_cost'];
        total += raw is num ? raw.toDouble() : double.tryParse(raw.toString()) ?? 0;
      }

      return total;
    } catch (e) {
      throw Exception('Failed to fetch unit maintenance spend: $e');
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
    String? organizationId,
    String? locationScope,
    double reliabilityScore = 0,
  }) async {
    try {
      final resolvedOrganizationId = organizationId ?? await SupabaseService.instance.getCurrentOrganizationId();
      if (resolvedOrganizationId == null || resolvedOrganizationId.isEmpty) {
        return null;
      }

      final contractor = await saveContractor(
        name: name,
        phone: phone,
        specialty: normalizeContractorSpecialty(specialty),
        organizationId: resolvedOrganizationId,
        reliabilityScore: reliabilityScore,
      );

      return contractor?.id;
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
