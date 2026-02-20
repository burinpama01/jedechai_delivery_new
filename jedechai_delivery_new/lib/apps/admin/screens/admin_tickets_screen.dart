import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../common/models/support_ticket.dart';
import '../../../common/services/ticket_service.dart';

/// Admin Tickets Screen
///
/// Admin view for managing support tickets
class AdminTicketsScreen extends StatefulWidget {
  const AdminTicketsScreen({super.key});

  @override
  State<AdminTicketsScreen> createState() => _AdminTicketsScreenState();
}

class _AdminTicketsScreenState extends State<AdminTicketsScreen>
    with SingleTickerProviderStateMixin {
  final TicketService _ticketService = TicketService();
  late TabController _tabController;
  List<SupportTicket> _tickets = [];
  Map<String, int> _stats = {};
  bool _isLoading = true;
  String _currentFilter = 'all';

  final _filters = [
    {'value': 'all', 'label': 'ทั้งหมด'},
    {'value': 'open', 'label': 'เปิด'},
    {'value': 'in_progress', 'label': 'กำลังดำเนินการ'},
    {'value': 'resolved', 'label': 'แก้ไขแล้ว'},
    {'value': 'closed', 'label': 'ปิดแล้ว'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filters.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _currentFilter = _filters[_tabController.index]['value']!;
        _loadTickets();
      }
    });
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadTickets(), _loadStats()]);
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    final tickets = await _ticketService.getAllTickets(
      statusFilter: _currentFilter == 'all' ? null : _currentFilter,
    );
    if (mounted) {
      setState(() {
        _tickets = tickets;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStats() async {
    final stats = await _ticketService.getTicketStats();
    if (mounted) setState(() => _stats = stats);
  }

  Future<void> _showUpdateDialog(SupportTicket ticket) async {
    String selectedStatus = ticket.status;
    final resolutionCtrl = TextEditingController(text: ticket.resolution ?? '');

    final statuses = ['open', 'in_progress', 'resolved', 'closed'];
    final statusLabels = {
      'open': 'เปิด',
      'in_progress': 'กำลังดำเนินการ',
      'resolved': 'แก้ไขแล้ว',
      'closed': 'ปิดแล้ว',
    };

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('อัพเดท Ticket',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('หัวข้อ: ${ticket.subject}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(ticket.description,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  const Divider(height: 24),

                  // Status selector
                  const Text('สถานะ',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: statuses.map((s) {
                      final isSelected = s == selectedStatus;
                      return ChoiceChip(
                        label: Text(statusLabels[s] ?? s),
                        selected: isSelected,
                        selectedColor: _statusColor(s),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        onSelected: (_) =>
                            setDialogState(() => selectedStatus = s),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Resolution
                  TextField(
                    controller: resolutionCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'ผลการแก้ไข',
                      hintText: 'อธิบายผลการแก้ไข...',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('ยกเลิก'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _ticketService.updateTicketStatus(
                      ticket.id,
                      selectedStatus,
                      resolution: resolutionCtrl.text.trim().isEmpty
                          ? null
                          : resolutionCtrl.text.trim(),
                    );
                    if (context.mounted) Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                  ),
                  child: const Text('บันทึก'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) _loadData();
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
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการ Tickets'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: _filters.map((f) {
            final count = f['value'] == 'all'
                ? _stats['total'] ?? 0
                : _stats[f['value']] ?? 0;
            return Tab(text: '${f['label']} ($count)');
          }).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tickets.isEmpty
              ? Center(
                  child: Text(
                    'ไม่มี Ticket ในหมวดนี้',
                    style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _tickets.length,
                    itemBuilder: (context, index) =>
                        _buildTicketCard(_tickets[index]),
                  ),
                ),
    );
  }

  Widget _buildTicketCard(SupportTicket ticket) {
    final dateStr =
        DateFormat('d MMM yyyy, HH:mm', 'th').format(ticket.createdAt);
    final color = _statusColor(ticket.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showUpdateDialog(ticket),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_categoryIcon(ticket.category),
                      size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ticket.subject,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ticket.statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                ticket.description,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    ticket.categoryText,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const Spacer(),
                  Text(
                    dateStr,
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
