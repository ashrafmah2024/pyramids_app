import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/manufacturer.dart';

class ManufacturersRemoteDataSource {
  final SupabaseClient client;
  ManufacturersRemoteDataSource(this.client);

  static const String table = 'manufacturers';

  Future<List<Manufacturer>> list({String? search, String? type}) async {
    var builder = client.from(table).select();
    if (search != null && search.trim().isNotEmpty) {
      builder = builder.ilike('name', '%${search.trim()}%');
    }
    if (type != null && type.trim().isNotEmpty) {
      builder = builder.eq('type', type.trim());
    }
    final res = await builder.order('created_at', ascending: false);
    return (res as List).map((e) => Manufacturer.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  Future<Manufacturer> create(ManufacturerInput input, {String? userId, String? userName}) async {
    final payload = {
      ...input.toMap(updatedBy: userId),
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    final inserted = await client.from(table).insert(payload).select().single();

    // activity log
    try {
      if (userId != null) {
        await client.from('activity_logs').insert({
          'user_id': userId,
          'user_name': userName ?? 'User',
          'action': 'CREATE_MANUFACTURER',
          'description': 'تم إضافة مصنع: ${payload['name']}',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}

    return Manufacturer.fromMap(Map<String, dynamic>.from(inserted));
  }

  Future<Manufacturer> update(String id, ManufacturerInput input, {String? userId, String? userName}) async {
    final payload = {
      ...input.toMap(updatedBy: userId),
      'updated_at': DateTime.now().toIso8601String(),
    };
    final updated = await client.from(table).update(payload).eq('id', id).select().single();

    // activity log
    try {
      if (userId != null) {
        await client.from('activity_logs').insert({
          'user_id': userId,
          'user_name': userName ?? 'User',
          'action': 'UPDATE_MANUFACTURER',
          'description': 'تم تعديل مصنع: $id',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}

    return Manufacturer.fromMap(Map<String, dynamic>.from(updated));
  }

  Future<bool> delete(String id, {String? userId, String? userName}) async {
    await client.from(table).delete().eq('id', id);

    // activity log
    try {
      if (userId != null) {
        await client.from('activity_logs').insert({
          'user_id': userId,
          'user_name': userName ?? 'User',
          'action': 'DELETE_MANUFACTURER',
          'description': 'تم حذف مصنع: $id',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}

    return true;
  }

  // === Manufacturer ↔ Stages (Many-to-Many by stage_id) ===
  Future<List<String>> listStageIdsForManufacturer(String manufacturerId) async {
    final res = await client
        .from('manufacturer_stage_assignments')
        .select('stage_id')
        .eq('manufacturer_id', manufacturerId)
        .order('stage_id');
    return (res as List)
        .map((e) => (e as Map<String, dynamic>)['stage_id'] as String)
        .toList();
  }

  Future<void> replaceStagesForManufacturer(String manufacturerId, List<String> stageIds) async {
    // delete old
    await client.from('manufacturer_stage_assignments').delete().eq('manufacturer_id', manufacturerId);
    if (stageIds.isEmpty) return;
    final rows = stageIds.map((sid) => {
          'manufacturer_id': manufacturerId,
          'stage_id': sid,
        }).toList();
    await client.from('manufacturer_stage_assignments').insert(rows);
  }
}
