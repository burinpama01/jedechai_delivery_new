import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../theme/jdc_layout.dart';
import 'support_tickets_screen.dart';

/// Help Screen
///
/// UI ตาม Design: Customer-Help.dc.html
/// header hero2 + ช่องค้นหา + grid topic + FAQ list + ปุ่มแจ้งปัญหา
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
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final faqs = _getFaqs(context);
    final filtered = _searchQuery.isEmpty
        ? faqs
        : faqs.where((f) => (f['q'] ?? '').toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    final topics = [
      {'tag': 'รถ', 'name': 'การเดินทาง', 'bg': jdc.brandSoft, 'fg': jdc.brandOnSoft},
      {'tag': 'อาหาร', 'name': 'สั่งอาหาร', 'bg': jdc.successSoft, 'fg': jdc.successInk},
      {'tag': 'จ่าย', 'name': 'การชำระเงิน', 'bg': jdc.infoSoft, 'fg': jdc.infoInk},
    ];

    return Scaffold(
      backgroundColor: jdc.paper,
      body: Column(
        children: [
          // header hero2 — ย้อนกลับ + ชื่อ + ช่องค้นหา
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + JdcSpacing.lg,
              left: JdcSpacing.xl,
              right: JdcSpacing.xl,
              bottom: JdcSpacing.lg,
            ),
            decoration: BoxDecoration(gradient: jdc.hero2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // ใช้ปุ่มจริงแทน GestureDetector เพื่อให้มี semantics และ ripple
                    // (margin ติดลบทำให้ Container โยน assertion — ใช้ Transform แทน)
                    Transform.translate(
                      offset: const Offset(-JdcSpacing.md, 0),
                      child: IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        tooltip: MaterialLocalizations.of(context)
                            .backButtonTooltip,
                        constraints: const BoxConstraints(
                          minWidth: JdcTouch.minTarget,
                          minHeight: JdcTouch.minTarget,
                        ),
                        icon: Icon(Icons.chevron_left,
                            color: jdc.onPanel, size: 26),
                      ),
                    ),
                    const SizedBox(width: JdcSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.helpCenterTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: jdc.onPanel),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: JdcSpacing.lg),
                // ช่องค้นหา
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: jdc.surface,
                    borderRadius: BorderRadius.circular(JdcRadius.chip),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: JdcSpacing.lg),
                      Icon(Icons.search, color: jdc.muted, size: 18),
                      const SizedBox(width: JdcSpacing.sm),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(fontSize: 14, color: jdc.text),
                          decoration: InputDecoration(
                            hintText: 'ค้นหาคำถามที่พบบ่อย',
                            hintStyle: TextStyle(color: jdc.muted, fontSize: 14),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // body
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                JdcSpacing.xl,
                JdcSpacing.lg,
                JdcSpacing.xl,
                JdcSpacing.xl,
              ),
              child: JdcContentFrame(
                padded: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // grid หัวข้อ 3 ช่อง
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: JdcSpacing.sm,
                      mainAxisSpacing: JdcSpacing.sm,
                      childAspectRatio: 0.9,
                      children: [
                        for (final t in topics)
                          _TopicCard(
                            tag: t['tag'] as String,
                            name: t['name'] as String,
                            bg: t['bg'] as Color,
                            fg: t['fg'] as Color,
                            jdc: jdc,
                          ),
                      ],
                    ),
                    const SizedBox(height: JdcSpacing.lg),

                    // FAQ
                    Text(
                      l10n.helpFaqTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: jdc.text),
                    ),
                    const SizedBox(height: JdcSpacing.sm),
                    ...List.generate(filtered.length, (i) {
                      final faq = filtered[i];
                      final isExpanded = _expandedIndex == i;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: JdcSpacing.sm),
                        child: GestureDetector(
                          onTap: () => setState(() => _expandedIndex = isExpanded ? null : i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(JdcSpacing.lg),
                            decoration: BoxDecoration(
                              color: jdc.surface,
                              borderRadius: BorderRadius.circular(JdcRadius.small),
                              border: Border.all(
                                color: isExpanded ? jdc.cta : jdc.line,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        faq['q']!,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: jdc.text,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: JdcSpacing.sm),
                                    Icon(
                                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_right,
                                      color: jdc.muted,
                                      size: 17,
                                    ),
                                  ],
                                ),
                                if (isExpanded) ...[
                                  const SizedBox(height: JdcSpacing.md),
                                  Text(
                                    faq['a']!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.6,
                                      color: jdc.muted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: JdcSpacing.lg),

                    // ช่องทางติดต่อ
                    Text(
                      l10n.helpContactTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: jdc.text),
                    ),
                    const SizedBox(height: JdcSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _ContactCard(
                            icon: Icons.phone,
                            label: l10n.helpPhone,
                            detail: '083-982-5982',
                            jdc: jdc,
                            onTap: () => _launchUrl('tel:0839825982'),
                          ),
                        ),
                        const SizedBox(width: JdcSpacing.md),
                        Expanded(
                          child: _ContactCard(
                            icon: Icons.chat_bubble,
                            label: 'LINE',
                            detail: '@jdcdelivery',
                            jdc: jdc,
                            onTap: () => _launchUrl('https://line.me/R/ti/p/%40jdcdelivery'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: JdcSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: _ContactCard(
                            icon: Icons.email,
                            label: l10n.helpEmail,
                            detail: 'jdcdelivery2026@gmail.com',
                            jdc: jdc,
                            onTap: () => _launchUrl('mailto:jdcdelivery2026@gmail.com'),
                          ),
                        ),
                        const SizedBox(width: JdcSpacing.md),
                        Expanded(
                          child: _ContactCard(
                            icon: Icons.facebook,
                            label: 'Facebook',
                            detail: 'jdc.delivery',
                            jdc: jdc,
                            onTap: () => _launchUrl('https://www.facebook.com/jdc.delivery/'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // footer — ปุ่มแจ้งปัญหา
          Container(
            padding: EdgeInsets.fromLTRB(
              JdcSpacing.xl,
              JdcSpacing.lg,
              JdcSpacing.xl,
              JdcSpacing.xl + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: jdc.surface,
              border: Border(top: BorderSide(color: jdc.line)),
            ),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: JdcTouch.button,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SupportTicketsScreen()),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, size: 19),
                    label: Text(
                      l10n.helpReportProblem,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: jdc.cta,
                      foregroundColor: jdc.onCta,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(JdcRadius.card),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: JdcSpacing.sm),
                Text(
                  'ทีมงานตอบกลับภายใน 24 ชั่วโมง',
                  style: TextStyle(fontSize: 11, color: jdc.muted),
                ),
              ],
            ),
          ),
        ],
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

class _TopicCard extends StatelessWidget {
  const _TopicCard({
    required this.tag,
    required this.name,
    required this.bg,
    required this.fg,
    required this.jdc,
  });

  final String tag;
  final String name;
  final Color bg;
  final Color fg;
  final JdcColors jdc;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: JdcSpacing.lg, horizontal: JdcSpacing.xs),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        border: Border.all(color: jdc.line),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(JdcRadius.small),
            ),
            alignment: Alignment.center,
            child: Text(
              tag,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
            ),
          ),
          const SizedBox(height: JdcSpacing.sm),
          Text(
            name,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: jdc.text),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.icon,
    required this.label,
    required this.detail,
    required this.jdc,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final JdcColors jdc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(JdcSpacing.lg),
        decoration: BoxDecoration(
          color: jdc.surface,
          borderRadius: BorderRadius.circular(JdcRadius.small),
          border: Border.all(color: jdc.line),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(JdcSpacing.sm),
              decoration: BoxDecoration(
                color: jdc.brandSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: jdc.cta, size: 22),
            ),
            const SizedBox(height: JdcSpacing.sm),
            Text(
              label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: jdc.text),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              detail,
              style: TextStyle(fontSize: 11, color: jdc.muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
