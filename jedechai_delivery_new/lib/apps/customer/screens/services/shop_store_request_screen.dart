import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../theme/jdc_layout.dart';
import '../../../../common/services/shop_service.dart';
import 'delivery_map_picker_screen.dart';

/// ฟอร์มขอเพิ่มตำแหน่งร้าน (ฝั่งลูกค้า)
///
/// ใช้ชุดข้อมูลเดียวกับฟอร์มร้านในหน้าแอดมิน — ชื่อ, ประเภท, ที่อยู่, พิกัด,
/// ลิงก์ Google Maps, เปิด 24 ชม., หมายเหตุ — เพื่อให้แอดมินกดอนุมัติแล้วได้ร้าน
/// ที่ข้อมูลครบทันที ไม่ต้องไล่ถามลูกค้าย้อนหลัง
///
/// ข้อมูลที่ลูกค้าตั้งเองไม่ได้คือ **เวลาเปิด-ปิด** กับ **การเปิดใช้งานร้าน**
/// ทั้งสองอย่างยังเป็นของแอดมินตามข้อกำหนดเดิม (ร้านที่อนุมัติแล้วจะยังปิดอยู่
/// จนกว่าแอดมินจะตั้งเวลาให้)
class ShopStoreRequestScreen extends StatefulWidget {
  const ShopStoreRequestScreen({
    super.key,
    this.initialPosition,
    this.initialName,
  });

  /// ตำแหน่งตั้งต้นของหมุด — ปกติคือตำแหน่งปัจจุบันของลูกค้า
  final LatLng? initialPosition;

  /// ชื่อที่ลูกค้าพิมพ์ค้างไว้ในช่องค้นหาร้าน (หาไม่เจอเลยกดขอเพิ่ม)
  final String? initialName;

  @override
  State<ShopStoreRequestScreen> createState() => _ShopStoreRequestScreenState();
}

class _ShopStoreRequestScreenState extends State<ShopStoreRequestScreen> {
  final _shop = ShopService();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _mapsUrlController = TextEditingController();
  final _noteController = TextEditingController();

  String _category = 'grocery';
  bool _is24h = false;
  double? _lat;
  double? _lng;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName?.trim() ?? '';
    _lat = widget.initialPosition?.latitude;
    _lng = widget.initialPosition?.longitude;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _mapsUrlController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_submitting &&
      _nameController.text.trim().isNotEmpty &&
      _lat != null &&
      _lng != null;

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => DeliveryMapPickerScreen(
          initialPosition: (_lat != null && _lng != null)
              ? LatLng(_lat!, _lng!)
              : widget.initialPosition,
        ),
      ),
    );
    if (result == null || !mounted) return;
    final lat = (result['lat'] as num?)?.toDouble();
    final lng = (result['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return;
    setState(() {
      _lat = lat;
      _lng = lng;
      // เติมที่อยู่ให้เฉพาะตอนที่ลูกค้ายังไม่ได้พิมพ์เอง จะได้ไม่ลบของที่พิมพ์ไว้
      final addr = result['address']?.toString() ?? '';
      if (addr.isNotEmpty && _addressController.text.trim().isEmpty) {
        _addressController.text = addr;
      }
    });
  }

  String _errorText(AppLocalizations l10n, String? code) {
    switch (code) {
      case 'name_required':
        return l10n.shopReqErrName;
      case 'invalid_location':
        return l10n.shopReqErrLocation;
      case 'store_exists':
        return l10n.shopReqErrExists;
      case 'request_exists':
        return l10n.shopReqErrPending;
      case 'daily_limit_reached':
        return l10n.shopReqErrLimit;
      case 'requests_disabled':
        return l10n.shopReqErrDisabled;
      default:
        return l10n.shopErrGeneric;
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_canSubmit) return;

    // ลิงก์ไม่บังคับ แต่ถ้าใส่มาต้องเป็น http(s) — แอดมินใช้เปิดตรวจหมุด
    final mapsUrl = _textOrNull(_mapsUrlController);
    if (mapsUrl != null) {
      final uri = Uri.tryParse(mapsUrl);
      if (uri == null ||
          !(uri.scheme == 'http' || uri.scheme == 'https') ||
          uri.host.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.shopReqMapsUrlInvalid)),
        );
        return;
      }
    }

    setState(() => _submitting = true);
    final res = await _shop.createStoreRequest(
      name: _nameController.text.trim(),
      category: _category,
      lat: _lat!,
      lng: _lng!,
      address: _textOrNull(_addressController),
      mapsUrl: mapsUrl,
      is24h: _is24h,
      note: _textOrNull(_noteController),
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (res['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorText(l10n, res['error']?.toString()))),
      );
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.shopReqSent)));
    Navigator.of(context).pop(true);
  }

  String? _textOrNull(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final jdc = JdcColors.of(context);

    return Scaffold(
      backgroundColor: jdc.paper,
      appBar: AppBar(
        title: Text(l10n.shopReqTitle),
        backgroundColor: jdc.surface,
        foregroundColor: jdc.text,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: jdc.line),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              l10n.shopReqIntro,
              style: TextStyle(fontSize: 12.5, height: 1.5, color: jdc.muted),
            ),
            const SizedBox(height: 14),
            _card(
              jdc,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameController,
                    onChanged: (_) => setState(() {}),
                    decoration:
                        _dec(jdc, l10n.shopReqName, l10n.shopReqNameHint),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: _dec(jdc, l10n.shopReqCategory, ''),
                    items: [
                      DropdownMenuItem(
                          value: 'grocery', child: Text(l10n.shopCatGrocery)),
                      DropdownMenuItem(
                          value: 'mall', child: Text(l10n.shopCatMall)),
                      DropdownMenuItem(
                          value: 'market', child: Text(l10n.shopCatMarket)),
                      DropdownMenuItem(
                          value: 'convenience',
                          child: Text(l10n.shopCatConvenience)),
                      DropdownMenuItem(
                          value: 'pharmacy', child: Text(l10n.shopCatPharmacy)),
                    ],
                    onChanged: (v) =>
                        setState(() => _category = v ?? 'grocery'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _addressController,
                    decoration:
                        _dec(jdc, l10n.shopReqAddress, l10n.shopReqAddressHint),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _sectionTitle(jdc, l10n.shopReqLocation),
            _card(
              jdc,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _lat == null
                            ? Icons.location_off_rounded
                            : Icons.place_rounded,
                        color: _lat == null ? jdc.muted : jdc.link,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _lat == null
                              ? l10n.shopReqLocationNone
                              : '${_lat!.toStringAsFixed(6)}, ${_lng!.toStringAsFixed(6)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: _lat == null ? jdc.muted : jdc.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _pickLocation,
                    icon: const Icon(Icons.pin_drop_rounded, size: 18),
                    label: Text(l10n.shopReqPickOnMap),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(JdcTouch.minTarget),
                      side: BorderSide(color: jdc.line),
                      foregroundColor: jdc.text,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(JdcRadius.small),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _mapsUrlController,
                    keyboardType: TextInputType.url,
                    decoration:
                        _dec(jdc, l10n.shopReqMapsUrl, l10n.shopReqMapsUrlHint),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _card(
              jdc,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _is24h,
                    onChanged: (v) => setState(() => _is24h = v),
                    title: Text(
                      l10n.shopReq24h,
                      style: TextStyle(fontSize: 14, color: jdc.text),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _noteController,
                    maxLines: 3,
                    decoration:
                        _dec(jdc, l10n.shopReqNote, l10n.shopReqNoteHint),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _canSubmit ? _submit : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(JdcTouch.button),
              backgroundColor: jdc.cta,
              foregroundColor: jdc.onCta,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(JdcRadius.small),
              ),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    l10n.shopReqSubmit,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(JdcColors jdc, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800, color: jdc.text),
        ),
      );

  Widget _card(JdcColors jdc, {required Widget child}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: jdc.surface,
          borderRadius: BorderRadius.circular(JdcRadius.card),
          border: Border.all(color: jdc.line),
        ),
        child: child,
      );

  InputDecoration _dec(JdcColors jdc, String label, String hint) =>
      InputDecoration(
        labelText: label,
        hintText: hint.isEmpty ? null : hint,
        isDense: true,
        filled: true,
        fillColor: jdc.sunken,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(JdcRadius.field),
          borderSide: BorderSide(color: jdc.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(JdcRadius.field),
          borderSide: BorderSide(color: jdc.line),
        ),
      );
}
