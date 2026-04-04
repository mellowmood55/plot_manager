import '../core/supabase_config.dart';
import '../models/property.dart';
import '../models/tenant.dart';
import '../models/unit.dart';
import '../models/unit_configuration.dart';

class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  String normalizeUnitNumber(String rawUnitNumber) {
    final candidate = rawUnitNumber
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), '');
    final match = RegExp(r'^A(\d{1,3})$').firstMatch(candidate);

    if (match == null) {
      return candidate;
    }

    final digits = match.group(1)!;
    if (digits.length == 1) {
      return 'A0$digits';
    }

    return 'A$digits';
  }

  String getCurrentAuthProvider() {
    final user = SupabaseConfig.getClient().auth.currentUser;

    if (user == null) {
      return 'unknown';
    }

    final providerFromMetadata = user.appMetadata['provider']?.toString();
    if (providerFromMetadata != null && providerFromMetadata.isNotEmpty) {
      return providerFromMetadata;
    }

    final providers = user.appMetadata['providers'];
    if (providers is List && providers.isNotEmpty) {
      return providers.first.toString();
    }

    return 'unknown';
  }

  Future<String?> getCurrentOrganizationId() async {
    final client = SupabaseConfig.getClient();
    final user = client.auth.currentUser;

    if (user == null) {
      return null;
    }

    final profile = await client
        .from('profiles')
        .select('organization_id')
        .eq('id', user.id)
        .maybeSingle();

    return profile?['organization_id'] as String?;
  }

  Future<String?> getOrganizationName(String organizationId) async {
    final client = SupabaseConfig.getClient();
    final row = await client
        .from('organizations')
        .select('name')
        .eq('id', organizationId)
        .maybeSingle();

    return row?['name'] as String?;
  }

  Future<List<Property>> fetchPropertiesByOrganization(String organizationId) async {
    final client = SupabaseConfig.getClient();
    final rows = await client
        .from('properties')
        .select('id, organization_id, name, location, property_type')
        .eq('organization_id', organizationId);

    return rows.map<Property>((row) => Property.fromJson(row)).toList();
  }

  Future<void> createProperty({
    required String organizationId,
    required String name,
    required String location,
    required String propertyType,
  }) async {
    final client = SupabaseConfig.getClient();
    await client.from('properties').insert({
      'organization_id': organizationId,
      'name': name,
      'location': location,
      'property_type': propertyType,
    });
  }

  Future<List<Unit>> fetchUnitsByProperty(String propertyId) async {
    final client = SupabaseConfig.getClient();
    final rows = await client
        .from('units')
        .select('id, property_id, unit_number, unit_type, status, rent_amount')
        .eq('property_id', propertyId);

    return rows.map<Unit>((row) => Unit.fromJson(row)).toList();
  }

  Future<Unit?> fetchUnitById(String unitId) async {
    final client = SupabaseConfig.getClient();
    final row = await client
        .from('units')
        .select('id, property_id, unit_number, unit_type, status, rent_amount, tenant_id')
        .eq('id', unitId)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return Unit.fromJson(row);
  }

  Future<void> createUnit({
    required String propertyId,
    required String unitNumber,
    double rentAmount = 0,
  }) async {
    final client = SupabaseConfig.getClient();
    await client.from('units').insert({
      'property_id': propertyId,
      'unit_number': unitNumber,
      'rent_amount': rentAmount,
      'status': 'vacant',
    });
  }

  Future<Tenant?> fetchTenantById(String tenantId) async {
    final client = SupabaseConfig.getClient();
    final row = await client
        .from('tenants')
        .select('id, unit_id, full_name, phone_number, national_id, occupants_count')
        .eq('id', tenantId)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return Tenant.fromJson(row);
  }

  Future<Tenant?> fetchTenantByUnitId(String unitId) async {
    final client = SupabaseConfig.getClient();
    final row = await client
        .from('tenants')
        .select('id, unit_id, full_name, phone_number, national_id, occupants_count')
        .eq('unit_id', unitId)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return Tenant.fromJson(row);
  }

  Future<Tenant> addTenantAndMarkUnitOccupied({
    required String unitId,
    required String fullName,
    required String phoneNumber,
    required String nationalId,
    required int occupantsCount,
  }) async {
    final client = SupabaseConfig.getClient();

    final tenantRow = await client
        .from('tenants')
        .insert({
          'unit_id': unitId,
          'full_name': fullName,
          'phone_number': phoneNumber,
          'national_id': nationalId,
          'occupants_count': occupantsCount,
        })
        .select('id, unit_id, full_name, phone_number, national_id, occupants_count')
        .single();

    final tenant = Tenant.fromJson(tenantRow);

    try {
      await client.from('units').update({
        'status': 'occupied',
        'tenant_id': tenant.id,
      }).eq('id', unitId);
    } catch (_) {
      await client.from('units').update({
        'status': 'occupied',
      }).eq('id', unitId);
    }

    return tenant;
  }

  Future<List<UnitConfiguration>> fetchUnitConfigurationsByOrganization(String organizationId) async {
    final client = SupabaseConfig.getClient();
    final rows = await client
        .from('unit_configurations')
        .select('id, organization_id, unit_type_name, default_rent, min_occupants, max_occupants')
        .eq('organization_id', organizationId)
        .order('unit_type_name');

    return rows.map<UnitConfiguration>((row) => UnitConfiguration.fromJson(row)).toList();
  }

  Future<void> createUnitConfiguration({
    required String organizationId,
    required String unitTypeName,
    required double defaultRent,
    required int minOccupants,
    required int maxOccupants,
  }) async {
    final resolvedRule = UnitConfiguration.resolveOccupancyRule(
      unitTypeName,
      minOccupants,
      maxOccupants,
    );

    final client = SupabaseConfig.getClient();
    await client.from('unit_configurations').insert({
      'organization_id': organizationId,
      'unit_type_name': unitTypeName,
      'default_rent': defaultRent,
      'min_occupants': resolvedRule.min,
      'max_occupants': resolvedRule.max,
    });
  }

  Future<void> updateUnitConfiguration({
    required String configurationId,
    required String unitTypeName,
    required double defaultRent,
    required int minOccupants,
    required int maxOccupants,
  }) async {
    final resolvedRule = UnitConfiguration.resolveOccupancyRule(
      unitTypeName,
      minOccupants,
      maxOccupants,
    );

    final client = SupabaseConfig.getClient();
    await client.from('unit_configurations').update({
      'unit_type_name': unitTypeName,
      'default_rent': defaultRent,
      'min_occupants': resolvedRule.min,
      'max_occupants': resolvedRule.max,
    }).eq('id', configurationId);
  }

  Future<UnitConfiguration?> getUnitConfigurationByType({
    required String organizationId,
    required String unitTypeName,
  }) async {
    final configurations = await fetchUnitConfigurationsByOrganization(organizationId);
    final normalizedName = unitTypeName.trim().toLowerCase();

    for (final configuration in configurations) {
      if (configuration.unitTypeName.trim().toLowerCase() == normalizedName) {
        return configuration;
      }
    }

    return null;
  }

  Future<bool> unitNumberExists({
    required String propertyId,
    required String unitNumber,
  }) async {
    final client = SupabaseConfig.getClient();
    final normalizedNumber = normalizeUnitNumber(unitNumber);

    final rows = await client
        .from('units')
        .select('id, unit_number')
        .eq('property_id', propertyId);

    for (final row in rows) {
      final existing = normalizeUnitNumber((row['unit_number'] ?? '').toString());
      if (existing == normalizedNumber) {
        return true;
      }
    }

    return false;
  }

  Future<void> deleteUnitConfiguration(String configurationId) async {
    final client = SupabaseConfig.getClient();
    await client.from('unit_configurations').delete().eq('id', configurationId);
  }

  Future<void> createUnitWithType({
    required String propertyId,
    required String unitNumber,
    required String unitType,
    double rentAmount = 0,
  }) async {
    final normalizedUnitNumber = normalizeUnitNumber(unitNumber);
    final unitPattern = RegExp(r'^A\d{1,3}$');

    if (!unitPattern.hasMatch(normalizedUnitNumber)) {
      throw Exception('Invalid unit number. Use format A + 1 to 3 digits (for example A01).');
    }

    if (await unitNumberExists(propertyId: propertyId, unitNumber: unitNumber)) {
      throw Exception('Unit number "$unitNumber" already exists for this plot.');
    }

    final client = SupabaseConfig.getClient();
    await client.from('units').insert({
      'property_id': propertyId,
      'unit_number': normalizedUnitNumber,
      'unit_type': unitType,
      'rent_amount': rentAmount,
      'status': 'vacant',
    });
  }

  Future<void> verifyCurrentUserPassword(String password) async {
    final client = SupabaseConfig.getClient();
    final user = client.auth.currentUser;

    if (user == null) {
      throw Exception('You must be logged in to perform this action.');
    }

    final email = user.email;
    if (email == null || email.isEmpty) {
      throw Exception('Unable to verify password for this account.');
    }

    await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> deleteUnitWithPassword({
    required String unitId,
    required String password,
  }) async {
    await verifyCurrentUserPassword(password);

    final client = SupabaseConfig.getClient();

    try {
      await client.from('units').delete().eq('id', unitId);
    } catch (error) {
      throw Exception('Failed to delete unit. If occupied, remove tenant first. $error');
    }
  }

  Future<void> deleteUnitWithVerification({
    required String unitId,
    required String verificationInput,
  }) async {
    final provider = getCurrentAuthProvider();

    if (provider == 'email') {
      await verifyCurrentUserPassword(verificationInput);
    } else {
      if (verificationInput.trim().toUpperCase() != 'CONFIRM') {
        throw Exception('Type CONFIRM to delete this unit.');
      }
    }

    final client = SupabaseConfig.getClient();
    try {
      await client.from('units').delete().eq('id', unitId);
    } catch (error) {
      throw Exception('Failed to delete unit. If occupied, move out tenant first. $error');
    }
  }
}
