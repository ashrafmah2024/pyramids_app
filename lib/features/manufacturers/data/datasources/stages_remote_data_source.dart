import 'package:supabase_flutter/supabase_flutter.dart';

class StagesRemoteDataSource {
  final SupabaseClient client;
  StagesRemoteDataSource(this.client);

  Future<List<String>> listActiveStageNames() async {
    final res = await client
        .from('manufacturing_stages')
        .select('stage_name')
        .eq('is_active', true)
        .order('stage_name');
    return (res as List)
        .map((e) => (e as Map<String, dynamic>)['stage_name'] as String)
        .toList();
  }

  Future<List<Map<String, dynamic>>> listActiveStages() async {
    final res = await client
        .from('manufacturing_stages')
        .select('id, stage_name')
        .eq('is_active', true)
        .order('stage_name');
    return (res as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> createStage({required String stageName, String? description, bool isActive = true}) async {
    await client.from('manufacturing_stages').insert({
      'stage_name': stageName,
      if (description != null && description.isNotEmpty) 'description': description,
      'is_active': isActive,
    });
  }
}
