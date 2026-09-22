import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../common/providers/language_provider.dart';
import '../../../../common/models/support_ticket.dart';
import '../../../../common/services/ticket_service.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../theme/jdc_layout.dart';

/// Support Tickets Screen (Customer/Driver/Merchant)
///
/// List of user's tickets + create new ticket
class SupportTicketsScreen extends StatefulWidget {
  final String? bookingId;

  const SupportTicketsScreen({super.key, this.bookingId});

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  final TicketService _ticketService = TicketService();
  List<SupportTicket> _tickets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    final tickets = await _ticketService.getMyTickets();
    if (mounted) {
      setState(() {
        _tickets = tickets;
        _isLoading = false;
      });
    }
  }

  Future<void> _showCreateDialog() async {
    final subjectCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'other';
    var isSubmitting = false;

    final l10n = AppLocalizations.of(context)!;
    final jdc = JdcColors.of(context);
    final categories = [
      {'value': 'lost_item', 'label': l10n.ticketCatLostItem, 'icon': Icons.search_off},
      {'value': 'wrong_order', 'label': l10n.ticketCatWrongOrder, 'icon': Icons.error_outline},
      {'value': 'rude_driver', 'label': l10n.ticketCatRudeDriver, 'icon': Icons.person_off},
      {'value': 'refund', 'label': l10n.ticketCatRefund, 'icon': Icons.money_off},
      {'value': 'app_bug', 'label': l10n.ticketCatAppBug, 'icon': Icons.bug_report},
      {'value': 'other', 'label': l10n.ticketCatOther, 'icon': Icons.help_outline},
    ];

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(JdcRadius.sheet)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: JdcSpacing.xl,
                right: JdcSpacing.xl,
                top: JdcSpacing.xl,
                bottom: MediaQuery.of(context).viewInsets.bottom + JdcSpacing.xl,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(Icons.support_agent, color: jdc.cta),
                        const SizedBox(width: JdcSpacing.sm),
                        Text(
                          l10n.ticketCreateTitle,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: jdc.text),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context, false),
                          icon: Icon(Icons.close, color: jdc.muted),
                        ),
                      ],
                    ),
                    Divider(color: jdc.line),
                    const SizedBox(height: JdcSpacing.sm),

                    // Category
                    Text(l10n.ticketCategoryLabel,
                        style: TextStyle(fontWeight: FontWeight.w600, color: jdc.text)),
                    const SizedBox(height: JdcSpacing.sm),
                    Wrap(
                      spacing: JdcSpacing.sm,
                      runSpacing: JdcSpacing.sm,
                      children: categories.map((c) {
                        final isSelected = category == c['value'];
                        return ChoiceChip(
                          avatar: Icon(c['icon'] as IconData,
                              size: 18,
                              color: isSelected ? jdc.onCta : jdc.muted),
                          label: Text(c['label'] as String),
                          selected: isSelected,
                          selectedColor: jdc.cta,
                          labelStyle: TextStyle(
                            color: isSelected ? jdc.onCta : jdc.text,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                          onSelected: (_) =>
                              setSheetState(() => category = c['value'] as String),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: JdcSpacing.lg),

                    // Subject
                    TextField(
                      controller: subjectCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.ticketSubjectLabel,
                        hintText: l10n.ticketSubjectHint,
                        prefixIcon: const Icon(Icons.title),
                      ),
                    ),
                    const SizedBox(height: JdcSpacing.md),

                    // Description
                    TextField(
                      controller: descCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: l10n.ticketDescLabel,
                        hintText: l10n.ticketDescHint,
                        prefixIcon: const Icon(Icons.description),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: JdcSpacing.xl),

                    // Submit
                    SizedBox(
                      width: double.infinity,
                      height: JdcTouch.button,
                      child: ElevatedButton.icon(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (subjectCtrl.text.trim().isEmpty ||
                                    descCtrl.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(l10n.ticketValidation)),
                                  );
                                  return;
                                }

                                setSheetState(() => isSubmitting = true);
                                try {
                                  final ticket = await _ticketService.createTicket(
                                    category: category,
                                    subject: subjectCtrl.text.trim(),
                                    description: descCtrl.text.trim(),
                                    bookingId: widget.bookingId,
                                  );
                                  if (ticket != null && context.mounted) {
                                    Navigator.pop(context, true);
                                  }
                                } finally {
                                  if (context.mounted) {
                                    setSheetState(() => isSubmitting = false);
                                  }
                                }
                              },
                        icon: isSubmitting
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: jdc.onCta),
                              )
                            : const Icon(Icons.send),
                        label: Text(l10n.ticketSubmit,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: jdc.cta,
                          foregroundColor: jdc.onCta,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(JdcRadius.small),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    subjectCtrl.dispose();
    descCtrl.dispose();
    if (result == true) _loadTickets();
  }

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    return Scaffold(
      backgroundColor: jdc.paper,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.ticketTitle),
        backgroundColor: jdc.surface,
        foregroundColor: jdc.text,
        shape: Border(bottom: BorderSide(color: jdc.line)),
        iconTheme: IconThemeData(color: jdc.text),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: jdc.cta))
          : _tickets.isEmpty
              ? _buildEmptyState()
              : _buildTicketList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: Text(AppLocalizations.of(context)!.ticketFab),
        backgroundColor: jdc.cta,
        foregroundColor: jdc.onCta,
      ),
    );
  }

  Widget _buildEmptyState() {
    final jdc = JdcColors.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.support_agent, size: 80, color: jdc.offTrack),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.ticketEmptyTitle,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: jdc.muted),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.ticketEmptySubtitle,
            style: TextStyle(fontSize: 14, color: jdc.dim),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketList() {
    return RefreshIndicator(
      onRefresh: _loadTickets,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tickets.length,
        itemBuilder: (context, index) => _buildTicketCard(_tickets[index]),
      ),
    );
  }

  Widget _buildTicketCard(SupportTicket ticket) {
    final jdc = JdcColors.of(context);
    final locale = context.watch<LanguageProvider>().localeOverride?.languageCode ?? 'th';
    final dateStr = DateFormat('d MMM yyyy, HH:mm', locale).format(ticket.createdAt);
    final statusBg = ticket.status == 'open' || ticket.status == 'in_progress'
        ? jdc.brandSoft
        : jdc.sunken;
    final statusFg = ticket.status == 'open' || ticket.status == 'in_progress'
        ? jdc.brandOnSoft
        : jdc.muted;

    return Container(
      margin: const EdgeInsets.only(bottom: JdcSpacing.md),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        border: Border.all(color: jdc.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(JdcRadius.card),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(JdcSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // status + id
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(JdcRadius.chip),
                    ),
                    child: Text(
                      ticket.statusText,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusFg),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    dateStr,
                    style: TextStyle(fontSize: 11, color: jdc.muted),
                  ),
                ],
              ),
              const SizedBox(height: JdcSpacing.sm),
              Text(
                ticket.subject,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: jdc.text),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: JdcSpacing.xs),
              Text(
                ticket.description,
                style: TextStyle(fontSize: 12, color: jdc.muted, height: 1.6),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (ticket.resolution != null && ticket.resolution!.isNotEmpty) ...[
                const SizedBox(height: JdcSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(JdcSpacing.sm),
                  decoration: BoxDecoration(
                    color: jdc.successSoft,
                    borderRadius: BorderRadius.circular(JdcSpacing.sm),
                    border: Border.all(color: jdc.successLine),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle, size: 16, color: jdc.successInk),
                      const SizedBox(width: JdcSpacing.sm),
                      Expanded(
                        child: Text(
                          ticket.resolution!,
                          style: TextStyle(fontSize: 13, color: jdc.successInk),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: JdcSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  ticket.status == 'open' || ticket.status == 'in_progress'
                      ? 'ดูบทสนทนา'
                      : 'ดูรายละเอียด',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: jdc.link),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
