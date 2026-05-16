import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'supabase_service.dart';

class CustomerFavoriteService {
  const CustomerFavoriteService();

  Future<Set<String>> getFavoriteMerchantIds() async {
    final user = AuthService.currentUser;
    if (user == null) return {};

    final rows = await SupabaseService.client
        .from('customer_favorites')
        .select('merchant_id')
        .eq('customer_id', user.id);

    return {
      for (final row in rows)
        if (row['merchant_id'] != null) row['merchant_id'] as String,
    };
  }

  Future<bool> isFavorite(String merchantId) async {
    final user = AuthService.currentUser;
    if (user == null) return false;

    final row = await SupabaseService.client
        .from('customer_favorites')
        .select('id')
        .eq('customer_id', user.id)
        .eq('merchant_id', merchantId)
        .maybeSingle();
    return row != null;
  }

  Future<bool> setFavorite({
    required String merchantId,
    required bool favorite,
  }) async {
    final user = AuthService.currentUser;
    if (user == null) {
      throw const AuthException('Login required to update favorites');
    }

    if (favorite) {
      await SupabaseService.client.from('customer_favorites').upsert({
        'customer_id': user.id,
        'merchant_id': merchantId,
      }, onConflict: 'customer_id,merchant_id');
      return true;
    }

    await SupabaseService.client
        .from('customer_favorites')
        .delete()
        .eq('customer_id', user.id)
        .eq('merchant_id', merchantId);
    return false;
  }
}
