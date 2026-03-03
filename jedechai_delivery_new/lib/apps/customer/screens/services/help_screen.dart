import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/app_theme.dart';
import 'support_tickets_screen.dart';

/// Help Screen
/// 
/// Shows FAQ, contact info, and problem reporting
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  List<Map<String, String>> _getFaqs(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      {'q': l10n.helpFaq1Q, 'a': l10n.helpFaq1A},
      {'q': l10n.helpFaq2Q, 'a': l10n.helpFaq2A},
      {'q': l10n.helpFaq3Q, 'a': l10n.helpFaq3A},
      {'q': l10n.helpFaq4Q, 'a': l10n.helpFaq4A},
      {'q': l10n.helpFaq5Q, 'a': l10n.helpFaq5A},
      {'q': l10n.helpFaq6Q, 'a': l10n.helpFaq6A},
    ];
  }

  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.helpTitle),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryGreen, AppTheme.primaryGreen.withValues(alpha: 0.8)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.support_agent, size: 48, color: Colors.white),
                  const SizedBox(height: 12),
                  Text(AppLocalizations.of(context)!.helpCenterTitle,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(AppLocalizations.of(context)!.helpCenterSubtitle,
                      style: const TextStyle(fontSize: 14, color: Colors.white70)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ช่องทางติดต่อ
            Text(AppLocalizations.of(context)!.helpContactTitle,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildContactCard(
                  icon: Icons.phone,
                  label: AppLocalizations.of(context)!.helpPhone,
                  detail: '02-XXX-XXXX',
                  color: AppTheme.primaryGreen,
                  onTap: () => _launchUrl('tel:02XXXXXXXX'),
                )),
                const SizedBox(width: 12),
                Expanded(child: _buildContactCard(
                  icon: Icons.chat_bubble,
                  label: 'LINE',
                  detail: '@jedechai',
                  color: const Color(0xFF06C755),
                  onTap: () => _launchUrl('https://line.me/R/'),
                )),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildContactCard(
                  icon: Icons.email,
                  label: AppLocalizations.of(context)!.helpEmail,
                  detail: 'support@jedechai.com',
                  color: AppTheme.accentBlue,
                  onTap: () => _launchUrl('mailto:support@jedechai.com'),
                )),
                const SizedBox(width: 12),
                Expanded(child: _buildContactCard(
                  icon: Icons.facebook,
                  label: 'Facebook',
                  detail: 'Jedechai',
                  color: const Color(0xFF1877F2),
                  onTap: () => _launchUrl('https://facebook.com/'),
                )),
              ],
            ),

            const SizedBox(height: 28),

            // คำถามที่พบบ่อย
            Text(AppLocalizations.of(context)!.helpFaqTitle,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...List.generate(_getFaqs(context).length, (i) {
              final faq = _getFaqs(context)[i];
              final isExpanded = _expandedIndex == i;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => setState(() => _expandedIndex = isExpanded ? null : i),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isExpanded ? AppTheme.primaryGreen : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.help_outline,
                                color: isExpanded ? AppTheme.primaryGreen : Colors.grey, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(faq['q']!,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isExpanded
                                        ? AppTheme.primaryGreen
                                        : colorScheme.onSurface,
                                  )),
                            ),
                            Icon(
                              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                        if (isExpanded) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(faq['a']!,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: colorScheme.onSurface,
                                )),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 24),

            // ปุ่มรายงานปัญหา
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SupportTicketsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.report_problem_outlined),
                label: Text(AppLocalizations.of(context)!.helpReportProblem, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String label,
    required String detail,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(detail, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }
}
