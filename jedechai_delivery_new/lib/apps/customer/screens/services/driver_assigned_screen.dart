import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../theme/jdc_layout.dart';
import '../../../../common/models/booking.dart';
import '../../../../common/utils/order_code_formatter.dart';

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
  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    return Scaffold(
      backgroundColor: jdc.paper,
      appBar: AppBar(
        backgroundColor: jdc.panel,
        foregroundColor: jdc.onPanel,
        title: Text(AppLocalizations.of(context)!.driverAssignedTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            Navigator.of(context).popUntil((r) => r.isFirst);
          },
        ),
      ),
      body: SafeArea(
        // จอเตี้ย (มือถือแนวนอน) Column + Spacer จะล้น ต้องเลื่อนได้
        // ส่วนจอสูงยังดันเนื้อหาให้เต็มเหมือนเดิมด้วย minHeight + IntrinsicHeight
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(JdcSpacing.xxl),
                  child: JdcContentFrame(
                    padded: false,
                    child: Column(
                      children: [
                        const Spacer(flex: 2),

                        // Success icon
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: jdc.cta,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: jdc.cta.withValues(alpha: 0.3),
                                blurRadius: 30,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.check_circle,
                            color: jdc.onCta,
                            size: 60,
                          ),
                        ),

                        const SizedBox(height: JdcSpacing.xxxl + JdcSpacing.sm),

                        // Success message
                        Text(
                          AppLocalizations.of(context)!.driverAssignedHeading,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: jdc.text,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: JdcSpacing.lg),

                        Text(
                          AppLocalizations.of(context)!.driverAssignedSubtitle,
                          style: TextStyle(fontSize: 16, color: jdc.muted),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: JdcSpacing.sm),

                        // Booking ID
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: JdcSpacing.lg,
                              vertical: JdcSpacing.sm),
                          decoration: BoxDecoration(
                            color: jdc.sunken,
                            borderRadius: BorderRadius.circular(JdcRadius.chip),
                            border: Border.all(color: jdc.line),
                          ),
                          child: Text(
                            'Booking ID: ${OrderCodeFormatter.formatByServiceType(widget.booking.id, serviceType: widget.booking.serviceType)}',
                            style: TextStyle(fontSize: 14, color: jdc.muted),
                          ),
                        ),

                        const Spacer(flex: 2),

                        // Driver info
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(JdcSpacing.xl),
                          decoration: BoxDecoration(
                            color: jdc.surface,
                            borderRadius: BorderRadius.circular(JdcRadius.card),
                            border: Border.all(color: jdc.line),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: jdc.brandSoft,
                                child:
                                    Icon(Icons.person, color: jdc.brandOnSoft),
                              ),
                              const SizedBox(width: JdcSpacing.lg),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.booking.driverName ??
                                          AppLocalizations.of(context)!
                                              .driverAssignedOnTheWay,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: jdc.text,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      widget.booking.driverPhone ??
                                          AppLocalizations.of(context)!
                                              .driverAssignedEta,
                                      style: TextStyle(
                                          fontSize: 14, color: jdc.muted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: JdcSpacing.xxl),

                        // Action buttons
                        Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: JdcTouch.button,
                              child: OutlinedButton.icon(
                                onPressed: _showContactDialog,
                                icon: const Icon(Icons.phone),
                                label: Text(AppLocalizations.of(context)!
                                    .driverAssignedContact),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(JdcRadius.field),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: JdcSpacing.md),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                onPressed: _showCancelDialog,
                                child: Text(
                                  AppLocalizations.of(context)!
                                      .driverAssignedCancelBooking,
                                  style: TextStyle(
                                      fontSize: 16, color: jdc.danger),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
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
