import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// AI Menu Import — ถ่าย/อัปโหลดรูปป้ายเมนูให้ AI อ่านเป็นรายการแบบร่าง
///
/// ทุกการเขียนผ่าน RPC/Edge Function (ตาราง import ไม่มี policy ให้ client เขียน)
/// แผน: Plan/JDC_AI_Merchant_Quick_Setup_Plan_v7.html
class AiMenuImportService {
  AiMenuImportService({SupabaseClient? client}) : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  // lazy — ให้ subclass จำลองใน test/dev preview สร้างได้โดยไม่ init Supabase
  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  static const String bucket = 'merchant-imports';
  static const String functionName = 'merchant-ai-menu-import';

  Future<AiImportStatus> fetchStatus() async {
    final res = await _client.rpc('merchant_ai_import_status');
    return AiImportStatus.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// สร้าง job → อัปโหลดรูป → สั่งประมวลผล คืน job id
  Future<String> startImport(List<Uint8List> images) async {
    final created = Map<String, dynamic>.from(
      await _client.rpc('merchant_create_import_job',
          params: {'p_file_count': images.length}) as Map,
    );
    final jobId = created['job_id'] as String;
    final prefix = created['upload_prefix'] as String;
    for (var i = 0; i < images.length; i++) {
      await _client.storage.from(bucket).uploadBinary(
            '$prefix${i.toString().padLeft(2, '0')}.jpg',
            images[i],
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
    }
    await process(jobId);
    return jobId;
  }

  /// สั่งประมวลผล (ใช้ทั้งครั้งแรกและลองใหม่เมื่อ failed)
  Future<void> process(String jobId) async {
    await _invoke({'action': 'process', 'job_id': jobId});
  }

  Future<AiImportJob?> fetchJob(String jobId) async {
    final row = await _client
        .from('merchant_import_jobs')
        .select()
        .eq('id', jobId)
        .maybeSingle();
    return row == null ? null : AiImportJob.fromJson(row);
  }

  Future<List<AiImportJob>> fetchJobs({int limit = 30}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _client
        .from('merchant_import_jobs')
        .select()
        .eq('merchant_id', uid)
        .neq('status', 'uploading')
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map<AiImportJob>((r) => AiImportJob.fromJson(r)).toList();
  }

  Future<List<AiImportItem>> fetchItems(String jobId) async {
    final rows = await _client
        .from('merchant_import_items')
        .select()
        .eq('import_job_id', jobId)
        .order('sort_order');
    return rows.map<AiImportItem>((r) => AiImportItem.fromJson(r)).toList();
  }

  Future<void> reviewItem(String itemId, String action,
      [Map<String, dynamic> patch = const {}]) async {
    await _client.rpc('merchant_review_import_item', params: {
      'p_item_id': itemId,
      'p_action': action,
      'p_patch': patch,
    });
  }

  Future<int> bulkApprove(String jobId) async {
    final res = await _client
        .rpc('merchant_bulk_approve_import', params: {'p_job_id': jobId});
    return (res as num?)?.toInt() ?? 0;
  }

  Future<List<AiTemplateSuggestion>> suggestTemplates(
      String jobId, String storeType) async {
    final data = await _invoke({
      'action': 'suggest_templates',
      'job_id': jobId,
      'store_type': storeType,
    });
    final list = (data['suggestions'] as List?) ?? const [];
    return list
        .map((e) => AiTemplateSuggestion.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchSavedSelections(String jobId) async {
    final rows = await _client
        .from('merchant_import_template_selections')
        .select()
        .eq('import_job_id', jobId)
        .order('sort_order');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> saveTemplateSelections(String jobId, String storeType,
      List<AiTemplateSuggestion> selected) async {
    await _client.rpc('merchant_save_template_selections', params: {
      'p_job_id': jobId,
      'p_store_type': storeType,
      'p_selections': selected.map((s) => s.toSelectionJson()).toList(),
    });
  }

  /// คืน result map: {ok, created_items, ...} หรือ {ok:false, reason:'duplicates_found', names}
  Future<Map<String, dynamic>> publish(String jobId,
      {required bool live, required bool confirmed}) async {
    final res = await _client.rpc('merchant_publish_import', params: {
      'p_job_id': jobId,
      'p_visibility': live ? 'live' : 'hidden',
      'p_confirmed': confirmed,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<int> hideImportedItems(String jobId) async {
    final res = await _client
        .rpc('merchant_hide_import_items', params: {'p_job_id': jobId});
    return (res as num?)?.toInt() ?? 0;
  }

  Future<void> cancelJob(String jobId) async {
    await _client.rpc('merchant_cancel_import_job', params: {'p_job_id': jobId});
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    try {
      final res = await _client.functions.invoke(functionName, body: body);
      final data = res.data;
      return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    } on FunctionException catch (e) {
      final details = e.details;
      final code = details is Map ? details['error']?.toString() : null;
      throw AiImportException(code ?? 'http_${e.status}');
    }
  }

  /// แปลงข้อความ error จาก RPC/Edge Function เป็นรหัสสั้น (เช่น ai_import_forbidden)
  static String errorCode(Object error) {
    if (error is AiImportException) return error.code;
    final text = error is PostgrestException ? error.message : error.toString();
    final match = RegExp(r'ai_(?:import|not)_[a-z_]+(?::[a-z_]+)?').firstMatch(text);
    return match?.group(0) ?? 'unknown';
  }
}

class AiImportException implements Exception {
  AiImportException(this.code);
  final String code;
  @override
  String toString() => code;
}

class AiImportStatus {
  AiImportStatus({
    required this.allowed,
    required this.reason,
    required this.mode,
    required this.quotaUsed,
    required this.quotaLimit,
    required this.activeJobId,
    required this.maxFiles,
  });

  factory AiImportStatus.fromJson(Map<String, dynamic> j) => AiImportStatus(
        allowed: j['allowed'] == true,
        reason: j['reason'] as String?,
        mode: (j['mode'] as String?) ?? 'onboarding',
        quotaUsed: (j['quota_used'] as num?)?.toInt() ?? 0,
        quotaLimit: (j['quota_limit'] as num?)?.toInt() ?? 0,
        activeJobId: j['active_job_id'] as String?,
        maxFiles: (j['max_files'] as num?)?.toInt() ?? 8,
      );

  final bool allowed;
  final String? reason;
  final String mode;
  final int quotaUsed;
  final int quotaLimit;
  final String? activeJobId;
  final int maxFiles;

  bool get isAppend => mode == 'append';

  /// แสดงปุ่มในหน้าเมนูไหม (ปิด feature / ไม่อยู่ในกลุ่มทดลอง / ร้านซักรีด = ซ่อน)
  bool get visible =>
      allowed || reason == 'quota_exceeded' || activeJobId != null;
}

class AiImportJob {
  AiImportJob.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        mode = (j['mode'] as String?) ?? 'onboarding',
        status = j['status'] as String,
        storeType = j['store_type'] as String?,
        storeTypeGuess = j['store_type_guess'] as String?,
        visibility = j['visibility'] as String?,
        totalFiles = (j['total_files'] as num?)?.toInt() ?? 0,
        totalItems = (j['total_items'] as num?)?.toInt() ?? 0,
        attempts = (j['attempts'] as num?)?.toInt() ?? 0,
        error = j['error'] as String?,
        unreadableRegions =
            List<String>.from((j['unreadable_regions'] as List?) ?? const []),
        createdAt = DateTime.tryParse(j['created_at']?.toString() ?? ''),
        publishedAt = DateTime.tryParse(j['published_at']?.toString() ?? ''),
        hiddenAt = DateTime.tryParse(j['hidden_at']?.toString() ?? '');

  final String id;
  final String mode;
  final String status;
  final String? storeType;
  final String? storeTypeGuess;
  final String? visibility;
  final int totalFiles;
  final int totalItems;
  final int attempts;
  final String? error;
  final List<String> unreadableRegions;
  final DateTime? createdAt;
  final DateTime? publishedAt;
  final DateTime? hiddenAt;

  bool get isProcessing => status == 'queued' || status == 'processing';
  bool get isReviewable => status == 'review_required' || status == 'ready';
  bool get isFailed => status == 'failed';
  bool get isPublished => status == 'published';
}

class AiVariant {
  AiVariant(this.label, this.price);
  factory AiVariant.fromJson(Map<String, dynamic> j) =>
      AiVariant(j['label']?.toString() ?? '', (j['price'] as num?)?.toDouble());
  final String label;
  final double? price;
  Map<String, dynamic> toJson() => {'label': label, 'price': price};
}

class AiAddon {
  AiAddon(this.group, this.label, this.priceDelta);
  factory AiAddon.fromJson(Map<String, dynamic> j) => AiAddon(
      j['group'] as String?,
      j['label']?.toString() ?? '',
      (j['price_delta'] as num?)?.toDouble());
  final String? group;
  final String label;
  final double? priceDelta;
  Map<String, dynamic> toJson() =>
      {'group': group, 'label': label, 'price_delta': priceDelta};
}

class AiImportItem {
  AiImportItem.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        sourceIndex = (j['source_index'] as num?)?.toInt(),
        category = j['category'] as String?,
        name = j['name']?.toString() ?? '',
        description = j['description'] as String?,
        price = (j['price'] as num?)?.toDouble(),
        variantGroup = j['variant_group'] as String?,
        variants = ((j['variants_json'] as List?) ?? const [])
            .map((e) => AiVariant.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        addons = ((j['addons_json'] as List?) ?? const [])
            .map((e) => AiAddon.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        priceTextRaw = j['price_text_raw'] as String?,
        issues = List<String>.from((j['issues'] as List?) ?? const []),
        conflictPrices = (((j['conflict_json'] as Map?)?['prices'] as List?) ??
                const [])
            .map((e) => (e as num).toDouble())
            .toList(),
        status = j['status'] as String,
        matchType = (j['match_type'] as String?) ?? 'new',
        matchedPrice = (j['matched_price'] as num?)?.toDouble(),
        action = (j['action'] as String?) ?? 'create',
        isNewCategory = j['is_new_category'] == true;

  final String id;
  final int? sourceIndex;
  final String? category;
  final String name;
  final String? description;
  final double? price;
  final String? variantGroup;
  final List<AiVariant> variants;
  final List<AiAddon> addons;
  final String? priceTextRaw;
  final List<String> issues;
  final List<double> conflictPrices;
  final String status;
  final String matchType;
  final double? matchedPrice;
  final String action;
  final bool isNewCategory;

  bool get willCreate => action == 'create' && status != 'rejected';
  bool get isConfirmed => status == 'approved' || status == 'edited';
  bool get hasPriceConflict => issues.contains('price_conflict');

  /// ต้องตรวจก่อน: จะสร้าง แต่ยังไม่ได้ยืนยัน และมี issue
  bool get needsReview => willCreate && !isConfirmed && issues.isNotEmpty;

  /// พร้อม: จะสร้าง ไม่มี issue (รออนุมัติทั้งหมด หรืออนุมัติแล้ว)
  bool get isReady => willCreate && (isConfirmed || issues.isEmpty);
}

class AiTemplateOption {
  AiTemplateOption(this.label, this.price);
  String label;
  int price;
  Map<String, dynamic> toJson() => {'label': label, 'price': price};
}

/// ข้อเสนอแม่แบบ + สิ่งที่ร้านเลือก (แก้ได้ในหน้า)
class AiTemplateSuggestion {
  AiTemplateSuggestion({
    required this.templateId,
    required this.name,
    required this.minSelection,
    required this.maxSelection,
    required this.options,
    required this.itemIds,
    required this.skippedItemIds,
    required this.templatePriced,
  });

  factory AiTemplateSuggestion.fromJson(Map<String, dynamic> j) {
    final options = ((j['options'] as List?) ?? const [])
        .map((o) => AiTemplateOption(
              o['label']?.toString() ?? '',
              (o['price'] as num?)?.round() ?? 0,
            ))
        .toList();
    return AiTemplateSuggestion(
      templateId: j['template_id'] as String?,
      name: j['name']?.toString() ?? '',
      minSelection: (j['min_selection'] as num?)?.toInt() ?? 0,
      maxSelection: (j['max_selection'] as num?)?.toInt() ?? 1,
      options: options,
      itemIds: Set<String>.from((j['item_ids'] as List?) ?? const []),
      skippedItemIds: List<String>.from((j['skipped_item_ids'] as List?) ?? const []),
      templatePriced: options.any((o) => o.price > 0),
    );
  }

  final String? templateId;
  String name;
  int minSelection;
  int maxSelection;
  List<AiTemplateOption> options;
  Set<String> itemIds;
  final List<String> skippedItemIds;

  /// ตัวเลือกบางตัวมีราคาจากแม่แบบ → ติดป้าย "ราคาจากแม่แบบ ตรวจก่อน" (D10)
  final bool templatePriced;

  /// D11: ไม่ติ๊กให้ล่วงหน้า — ร้านกด "ใช้" เอง
  bool selected = false;

  Map<String, dynamic> toSelectionJson() => {
        'template_id': templateId,
        'name': name,
        'min_selection': minSelection,
        'max_selection': maxSelection,
        'options': options.map((o) => o.toJson()).toList(),
        'import_item_ids': itemIds.toList(),
      };
}
