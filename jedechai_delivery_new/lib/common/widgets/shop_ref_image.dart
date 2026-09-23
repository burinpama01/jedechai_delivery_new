import 'package:flutter/material.dart';

import '../../theme/jdc_colors.dart';
import '../../theme/jdc_layout.dart';
import '../services/shop_service.dart';

/// รูปตัวอย่างที่ลูกค้าแนบกับรายการฝากซื้อ
///
/// รูปอยู่ใน bucket ส่วนตัว -> ขอ signed URL ครั้งเดียวตอนสร้าง widget
/// (ไม่ขอใหม่ทุก build) แตะเพื่อดูเต็มจอ
class ShopRefImage extends StatefulWidget {
  const ShopRefImage({super.key, required this.path, this.label, this.size = 64});

  final String path;
  final String? label;
  final double size;

  @override
  State<ShopRefImage> createState() => _ShopRefImageState();
}

class _ShopRefImageState extends State<ShopRefImage> {
  late Future<String?> _url;

  @override
  void initState() {
    super.initState();
    _url = ShopService().signedRefImageUrl(widget.path);
  }

  @override
  void didUpdateWidget(covariant ShopRefImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _url = ShopService().signedRefImageUrl(widget.path);
    }
  }

  void _openFull(String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        child: GestureDetector(
          onTap: () => Navigator.of(ctx).pop(),
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final s = widget.size;

    return FutureBuilder<String?>(
      future: _url,
      builder: (context, snap) {
        final url = snap.data;
        Widget thumb;
        if (snap.connectionState != ConnectionState.done) {
          thumb = Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: jdc.muted),
            ),
          );
        } else if (url == null) {
          thumb = Icon(Icons.broken_image_outlined, color: jdc.muted);
        } else {
          thumb = Image.network(
            url,
            fit: BoxFit.cover,
            cacheWidth: (s * 3).round(),
            errorBuilder: (_, __, ___) =>
                Icon(Icons.broken_image_outlined, color: jdc.muted),
          );
        }

        return GestureDetector(
          onTap: url == null ? null : () => _openFull(url),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(JdcRadius.small),
                child: Container(
                  width: s,
                  height: s,
                  color: jdc.surface,
                  child: thumb,
                ),
              ),
              if (widget.label != null) ...[
                const SizedBox(width: 8),
                Text(widget.label!,
                    style: TextStyle(fontSize: 11.5, color: jdc.muted)),
              ],
            ],
          ),
        );
      },
    );
  }
}
