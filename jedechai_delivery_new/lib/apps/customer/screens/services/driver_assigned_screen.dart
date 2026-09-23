import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../common/models/booking.dart';
import '../../../../common/utils/order_code_formatter.dart';
import '../../../../common/services/auth_service.dart';
import '../../../../common/services/chat_service.dart';
import '../../../../common/widgets/chat_screen.dart';
import '../../../../common/widgets/app_network_image.dart';

/// Driver Assigned Screen
///
/// Shows when a driver has accepted the booking
class DriverAssignedScreen extends StatefulWidget {
  final Booking booking;

  const DriverAssignedScreen({
    super.key,
    required this.booking,
  });

  @override
  State<DriverAssignedScreen> createState() => _DriverAssignedScreenState();
}

class _DriverAssignedScreenState extends State<DriverAssignedScreen> {
  // Wave 1.5 b1food: Customer-DriverAssigned artboard layout

  /// เวลาโดยประมาณจนถึงลูกค้า คิดจากระยะทางที่เก็บไว้ในงาน (เฉลี่ย 25 กม./ชม. ในเมือง)
  /// บวกเวลาที่ร้าน/จุดรับ 8 นาที และไม่ต่ำกว่า 5 นาที
  int get _etaMinutes {
    final km = widget.booking.distanceKm;
    if (km <= 0) return 15;
    final minutes = (km / 25 * 60).round() + 8;
    return minutes < 5 ? 5 : minutes;
  }

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final driverName = widget.booking.driverName ?? l10n.driverAssignedOnTheWay;
    final driverPhone = widget.booking.driverPhone;
    final orderId = OrderCodeFormatter.formatByServiceType(
        widget.booking.id, serviceType: widget.booking.serviceType);
    return Scaffold(
      backgroundColor: jdc.paper,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero header (hero2 gradient) with checkmark
          Container(
            decoration: BoxDecoration(gradient: jdc.hero2),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 40, 20, 32),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: jdc.successPanel,
                        shape: BoxShape.circle,
                        border: Border.all(color: jdc.successPanelLine),
                      ),
                      child: Icon(Icons.check_rounded, color: jdc.onPanel, size: 32),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.driverAssignedFoundHeading,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: jdc.onPanel),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.driverAssignedFoundSubtitle,
                      style: TextStyle(fontSize: 13, color: jdc.panelDim),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Driver info card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: jdc.surface,
                      border: Border.all(color: jdc.line),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: jdc.panel,
                                shape: BoxShape.circle,
                              ),
                              clipBehavior: Clip.antiAlias,
                              // มาตรฐาน Wave 1.5: ช่องรูปที่ไม่มีรูป = โลโก้เทา ห้ามใช้ตัวย่อชื่อ
                              child: const GrayscaleLogoPlaceholder(
                                padding: EdgeInsets.all(10),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(driverName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: jdc.text), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text('#$orderId', style: TextStyle(fontSize: 12, color: jdc.muted)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(color: jdc.sunken, borderRadius: BorderRadius.circular(13)),
                          child: Row(
                            children: [
                              Icon(Icons.directions_bike_rounded, color: jdc.muted, size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Text(l10n.driverAssignedOnTheWay, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: jdc.text))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: _showContactDialog,
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: jdc.line),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.chat_bubble_outline_rounded, size: 18, color: jdc.text),
                                      const SizedBox(width: 8),
                                      Text(l10n.driverAssignedChatLabel, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: jdc.text)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (driverPhone != null) {
                                    final uri = Uri.parse('tel:${driverPhone.replaceAll(RegExp(r'[^0-9+]'), '')}');
                                    // ignore: avoid_print
                                    launchUrl(uri).catchError((_) { return false; });
                                  } else {
                                    _showContactDialog();
                                  }
                                },
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: jdc.panel,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.phone_rounded, size: 18, color: jdc.onPanel),
                                      const SizedBox(width: 8),
                                      Text(l10n.driverAssignedCallLabel, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: jdc.onPanel)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // ETA card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: jdc.brandSoft,
                      border: Border.all(color: jdc.brandLine),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time_rounded, color: jdc.brandOnSoft, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.driverAssignedEta,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: jdc.brandOnSoft),
                          ),
                        ),
                        Text(
                          l10n.driverAssignedEtaMinutes('$_etaMinutes'),
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: jdc.brandOnSoft),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom CTA
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
            decoration: BoxDecoration(
              color: jdc.surface,
              border: Border(top: BorderSide(color: jdc.line)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: jdc.cta,
                        foregroundColor: jdc.onCta,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(l10n.driverAssignedTrackMap, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  TextButton(
                    onPressed: _showCancelDialog,
                    child: Text(
                      l10n.driverAssignedCancel,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: jdc.danger),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showContactDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.driverAssignedContactTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone),
              title: Text(AppLocalizations.of(context)!.driverAssignedPhone),
              subtitle: Text(widget.booking.driverPhone ?? '-'),
              onTap: widget.booking.driverPhone != null
                  ? () async {
                      final phone = widget.booking.driverPhone!
                          .replaceAll(RegExp(r'[^0-9+]'), '');
                      final uri = Uri.parse('tel:$phone');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    }
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.message),
              title: Text(AppLocalizations.of(context)!.driverAssignedMessage),
              subtitle:
                  Text(AppLocalizations.of(context)!.driverAssignedMessageSub),
              onTap: () {
                Navigator.of(context).pop();
                _openChat();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.driverAssignedClose),
          ),
        ],
      ),
    );
  }

  /// เปิดห้องแชทกับคนขับ (รูปแบบเดียวกับหน้ารอคนขับ)
  Future<void> _openChat() async {
    final customerId = AuthService.userId;
    if (customerId == null) return;
    final room = await ChatService().getOrCreateBookingChatRoom(
      bookingId: widget.booking.id,
      customerId: customerId,
      driverId: widget.booking.driverId,
    );
    if (room == null || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          bookingId: widget.booking.id,
          chatRoomId: room.id,
          otherPartyName: widget.booking.driverName ??
              AppLocalizations.of(context)!.driverAssignedOnTheWay,
          roomType: 'booking',
        ),
      ),
    );
  }

  void _showCancelDialog() {
    final jdc = JdcColors.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.driverAssignedCancelTitle),
        content: Text(AppLocalizations.of(context)!.driverAssignedCancelBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.driverAssignedNo),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
            style: TextButton.styleFrom(
              foregroundColor: jdc.danger,
            ),
            child: Text(AppLocalizations.of(context)!.driverAssignedCancel),
          ),
        ],
      ),
    );
  }
}
