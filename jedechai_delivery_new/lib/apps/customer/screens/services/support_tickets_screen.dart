import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../common/models/support_ticket.dart';
import '../../../../common/services/ticket_service.dart';
import '../../../../theme/app_theme.dart';

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

    final categories = [
      {'value': 'lost_item', 'label': 'ของหาย', 'icon': Icons.search_off},
      {'value': 'wrong_order', 'label': 'อาหาร/สินค้าผิด', 'icon': Icons.error_outline},
      {'value': 'rude_driver', 'label': 'คนขับไม่สุภาพ', 'icon': Icons.person_off},
      {'value': 'refund', 'label': 'ขอคืนเงิน', 'icon': Icons.money_off},
      {'value': 'app_bug', 'label': 'ปัญหาแอป', 'icon': Icons.bug_report},
      {'value': 'other', 'label': 'อื่นๆ', 'icon': Icons.help_outline},
    ];

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Icon(Icons.support_agent, color: AppTheme.primaryGreen),
                        const SizedBox(width: 8),
                        const Text(
                          'แจ้งปัญหา',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context, false),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Category
                    const Text('ประเภทปัญหา',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((c) {
                        final isSelected = category == c['value'];
                        return ChoiceChip(
                          avatar: Icon(c['icon'] as IconData,
                              size: 18,
                              color: isSelected ? Colors.white : Colors.grey),
                          label: Text(c['label'] as String),
                          selected: isSelected,
                          selectedColor: AppTheme.primaryGreen,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                          onSelected: (_) =>
                              setSheetState(() => category = c['value'] as String),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Subject
                    TextField(
                      controller: subjectCtrl,
                      decoration: const InputDecoration(
                        labelText: 'หัวข้อ',
                        hintText: 'เช่น ลืมของไว้ในรถ',
                        prefixIcon: Icon(Icons.title),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Description
                    TextField(
                      controller: descCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'รายละเอียด',
                        hintText: 'อธิบายปัญหาให้ละเอียด...',
                        prefixIcon: Icon(Icons.description),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (subjectCtrl.text.trim().isEmpty ||
                              descCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('กรุณากรอกข้อมูลให้ครบถ้วน')),
                            );
                            return;
                          }

                          final ticket = await _ticketService.createTicket(
                            category: category,
                            subject: subjectCtrl.text.trim(),
                            description: descCtrl.text.trim(),
                            bookingId: widget.bookingId,
                          );

                          if (ticket != null && context.mounted) {
                            Navigator.pop(context, true);
                          }
                        },
                        icon: const Icon(Icons.send),
                        label: const Text('ส่งแจ้งปัญหา',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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

    if (result == true) _loadTickets();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'lost_item':
        return Icons.search_off;
      case 'wrong_order':
        return Icons.error_outline;
      case 'rude_driver':
        return Icons.person_off;
      case 'refund':
        return Icons.money_off;
      case 'app_bug':
        return Icons.bug_report;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('แจ้งปัญหา / ร้องเรียน'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tickets.isEmpty
              ? _buildEmptyState()
              : _buildTicketList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('แจ้งปัญหา'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.support_agent, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'ยังไม่มีรายการแจ้งปัญหา',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'หากพบปัญหากดปุ่ม "แจ้งปัญหา" ด้านล่าง',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
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
    final dateStr = DateFormat('d MMM yyyy, HH:mm', 'th').format(ticket.createdAt);
    final color = _statusColor(ticket.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(_categoryIcon(ticket.category),
                    size: 20, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ticket.subject,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    ticket.statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Category + Date
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    ticket.categoryText,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
                const Spacer(),
                Text(
                  dateStr,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),

            // Description
            const SizedBox(height: 8),
            Text(
              ticket.description,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Resolution (if any)
            if (ticket.resolution != null && ticket.resolution!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ticket.resolution!,
                        style: TextStyle(fontSize: 13, color: Colors.green[800]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
