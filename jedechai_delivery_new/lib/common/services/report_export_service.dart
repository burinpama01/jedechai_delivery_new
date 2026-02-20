import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../utils/debug_logger.dart';
import 'auth_service.dart';

/// Report Export Service
///
/// Generates CSV reports for bookings/orders and shares them
/// Used by Admin and Merchant dashboards
class ReportExportService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Export bookings to CSV for Admin (all bookings)
  Future<void> exportAdminBookingsCSV(
    BuildContext context, {
    DateTime? startDate,
    DateTime? endDate,
    String? serviceTypeFilter,
    String? statusFilter,
  }) async {
    try {
      var query = _client.from('bookings').select();

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }
      if (serviceTypeFilter != null && serviceTypeFilter != 'all') {
        query = query.eq('service_type', serviceTypeFilter);
      }
      if (statusFilter != null && statusFilter != 'all') {
        query = query.eq('status', statusFilter);
      }

      final response = await query.order('created_at', ascending: false);
      final rows = response as List;

      if (rows.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่มีข้อมูลสำหรับ export')),
          );
        }
        return;
      }

      final csv = _buildBookingsCSV(rows);
      await _shareCSV(context, csv, 'admin_bookings');
    } catch (e) {
      debugLog('❌ Error exporting admin CSV: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    }
  }

  /// Export bookings to CSV for Merchant (own orders only)
  Future<void> exportMerchantBookingsCSV(
    BuildContext context, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final merchantId = AuthService.userId;
    if (merchantId == null) return;

    try {
      var query = _client
          .from('bookings')
          .select()
          .eq('merchant_id', merchantId);

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query.order('created_at', ascending: false);
      final rows = response as List;

      if (rows.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่มีข้อมูลสำหรับ export')),
          );
        }
        return;
      }

      final csv = _buildMerchantCSV(rows);
      await _shareCSV(context, csv, 'merchant_orders');
    } catch (e) {
      debugLog('❌ Error exporting merchant CSV: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    }
  }

  /// Export driver earnings to CSV
  Future<void> exportDriverEarningsCSV(
    BuildContext context, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final driverId = AuthService.userId;
    if (driverId == null) return;

    try {
      var query = _client
          .from('bookings')
          .select()
          .eq('driver_id', driverId)
          .eq('status', 'completed');

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query.order('created_at', ascending: false);
      final rows = response as List;

      if (rows.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่มีข้อมูลสำหรับ export')),
          );
        }
        return;
      }

      final csv = _buildDriverEarningsCSV(rows);
      await _shareCSV(context, csv, 'driver_earnings');
    } catch (e) {
      debugLog('❌ Error exporting driver CSV: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    }
  }

  // ── CSV Builders ──

  String _buildBookingsCSV(List rows) {
    final buf = StringBuffer();
    // BOM for Excel UTF-8
    buf.write('\uFEFF');
    // Header
    buf.writeln(
      'ID,วันที่,ประเภท,สถานะ,ลูกค้า ID,คนขับ ID,ร้านค้า ID,'
      'จุดรับ,จุดส่ง,ระยะทาง (km),ราคา,ค่าส่ง,รายได้คนขับ,รายได้แพลตฟอร์ม,วิธีชำระ',
    );

    for (final row in rows) {
      buf.writeln([
        _esc(row['id']),
        _fmtDate(row['created_at']),
        _esc(row['service_type']),
        _esc(row['status']),
        _esc(row['customer_id']),
        _esc(row['driver_id']),
        _esc(row['merchant_id']),
        _esc(row['pickup_address']),
        _esc(row['destination_address']),
        row['distance_km'] ?? '',
        row['price'] ?? '',
        row['delivery_fee'] ?? '',
        row['driver_earnings'] ?? '',
        row['app_earnings'] ?? '',
        _esc(row['payment_method']),
      ].join(','));
    }

    return buf.toString();
  }

  String _buildMerchantCSV(List rows) {
    final buf = StringBuffer();
    buf.write('\uFEFF');
    buf.writeln(
      'ID,วันที่,สถานะ,ราคาอาหาร,ค่าส่ง,จุดส่ง,หมายเหตุ,วิธีชำระ',
    );

    for (final row in rows) {
      buf.writeln([
        _esc(row['id']),
        _fmtDate(row['created_at']),
        _esc(row['status']),
        row['price'] ?? '',
        row['delivery_fee'] ?? '',
        _esc(row['destination_address']),
        _esc(row['notes']),
        _esc(row['payment_method']),
      ].join(','));
    }

    return buf.toString();
  }

  String _buildDriverEarningsCSV(List rows) {
    final buf = StringBuffer();
    buf.write('\uFEFF');
    buf.writeln(
      'ID,วันที่,ประเภท,เก็บลูกค้า,ค่าอาหาร,ค่าส่ง,ค่าบริการระบบ,รายได้สุทธิ,ระยะทาง (km)',
    );

    for (final row in rows) {
      final price = (row['price'] as num?)?.toDouble() ?? 0;
      final deliveryFee = (row['delivery_fee'] as num?)?.toDouble() ?? 0;
      final driverEarnings = row['driver_earnings'];
      final appEarnings = row['app_earnings'];
      final isFood = row['service_type'] == 'food';
      final totalCollect = isFood ? price + deliveryFee : price;

      buf.writeln([
        _esc(row['id']),
        _fmtDate(row['created_at']),
        _esc(row['service_type']),
        totalCollect,
        isFood ? price : '',
        isFood ? deliveryFee : '',
        appEarnings ?? '',
        driverEarnings ?? '',
        row['distance_km'] ?? '',
      ].join(','));
    }

    return buf.toString();
  }

  // ── Helpers ──

  /// Escape CSV field (handle commas, quotes, newlines)
  String _esc(dynamic value) {
    if (value == null) return '';
    final str = value.toString();
    if (str.contains(',') || str.contains('"') || str.contains('\n')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return str;
  }

  /// Format date for CSV
  String _fmtDate(dynamic value) {
    if (value == null) return '';
    try {
      final dt = DateTime.parse(value.toString()).toLocal();
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    } catch (_) {
      return value.toString();
    }
  }

  /// Write CSV to temp file and share
  Future<void> _shareCSV(BuildContext context, String csv, String prefix) async {
    try {
      final dir = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final file = File('${dir.path}/${prefix}_$dateStr.csv');
      await file.writeAsString(csv);

      debugLog('✅ CSV exported: ${file.path} (${csv.length} chars)');

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '${prefix}_$dateStr.csv',
      );
    } catch (e) {
      debugLog('❌ Error sharing CSV: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ไม่สามารถแชร์ไฟล์ได้: $e')),
        );
      }
    }
  }
}
