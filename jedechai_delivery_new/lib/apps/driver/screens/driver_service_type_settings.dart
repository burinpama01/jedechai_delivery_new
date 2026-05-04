import 'package:flutter/material.dart';
import '../../../common/services/services.dart';

/// Bottom sheet widget สำหรับให้คนขับเลือกประเภทงานที่จะรับ
class DriverServiceTypeSettings extends StatefulWidget {
  final List<String>? initialServiceTypes;
  final String driverId;

  const DriverServiceTypeSettings({
    super.key,
    required this.initialServiceTypes,
    required this.driverId,
  });

  @override
  State<DriverServiceTypeSettings> createState() =>
      _DriverServiceTypeSettingsState();
}

class _DriverServiceTypeSettingsState
    extends State<DriverServiceTypeSettings> {
  late Set<String> _selected;
  bool _isSaving = false;

  static const _serviceTypes = ['food', 'ride', 'parcel'];
  static const _labels = {
    'food': 'อาหาร (Food)',
    'ride': 'เรียกรถ (Ride)',
    'parcel': 'พัสดุ (Parcel)',
  };
  static const _icons = {
    'food': Icons.restaurant_rounded,
    'ride': Icons.directions_car_rounded,
    'parcel': Icons.inventory_2_rounded,
  };

  @override
  void initState() {
    super.initState();
    _selected = widget.initialServiceTypes != null
        ? Set<String>.from(widget.initialServiceTypes!)
        : Set<String>.from(_serviceTypes);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final types = _selected.length == _serviceTypes.length
          ? null
          : _selected.toList();
      await SupabaseService.client
          .from('profiles')
          .update({'accepted_service_types': types})
          .eq('id', widget.driverId);

      if (mounted) {
        Navigator.of(context).pop(types ?? []);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ประเภทงานที่รับ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'เลือกประเภทงานที่ต้องการรับ (ไม่เลือก = รับทั้งหมด)',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            for (final type in _serviceTypes)
              CheckboxListTile(
                title: Row(
                  children: [
                    Icon(_icons[type], size: 20),
                    const SizedBox(width: 8),
                    Text(_labels[type] ?? type),
                  ],
                ),
                value: _selected.contains(type),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _selected.add(type);
                    } else {
                      _selected.remove(type);
                    }
                  });
                },
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('บันทึก'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
