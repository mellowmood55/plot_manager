import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/property.dart';
import '../../../services/supabase_service.dart';

final propertiesProvider = FutureProvider<List<Property>>((ref) async {
  final organizationId = await SupabaseService.instance.getCurrentOrganizationId();
  if (organizationId == null) {
    return [];
  }

  return SupabaseService.instance.fetchPropertiesByOrganization(organizationId);
});
