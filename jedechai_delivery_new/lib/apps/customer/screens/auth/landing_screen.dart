import 'package:flutter/material.dart';

import '../../../../theme/jdc_colors.dart';

import '../../../../common/services/system_config_service.dart';
import '../../../../common/widgets/app_network_image.dart';
import '../../../../common/widgets/language_switcher.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  String? _logoUrl;

  @override
  void initState() {
    super.initState();
    _loadLogo();
  }

  Future<void> _loadLogo() async {
    try {
      final configService = SystemConfigService();
      await configService.fetchSettings();
      if (!mounted) return;
      setState(() => _logoUrl = configService.logoUrl);
    } catch (_) {
      // Keep default placeholder logo
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JdcColors.of(context).panel,
      body: Stack(
        children: [
          Positioned(
            top: -140,
            left: -80,
            child: _GlowOrb(
              size: 320,
              color: JdcColors.of(context).cta.withValues(alpha: 0.30),
            ),
          ),
          Positioned(
            bottom: -130,
            right: -90,
            child: _GlowOrb(
              size: 280,
              color: JdcColors.of(context).linkHover.withValues(alpha: 0.22),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          _buildBrandHeader(),
                          const SizedBox(height: 24),
                          _buildHeroCard(),
                          const SizedBox(height: 20),
                          _buildFeatureRow(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildActionPanel(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandHeader() {
    // จอแคบ (360) ไม่มีที่พอสำหรับโลโก้ 64px + ข้อความ จึงย่อโลโก้ลง
    final logoSize = MediaQuery.sizeOf(context).width < 380 ? 48.0 : 64.0;
    return Row(
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: JdcColors.of(context).surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AppNetworkImage(
              imageUrl: _logoUrl,
              width: logoSize,
              height: logoSize,
              fit: BoxFit.contain,
              backgroundColor: JdcColors.of(context).surface,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'JDC DELIVERY',
                style: TextStyle(
                  color: JdcColors.of(context).onPanel,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'ส่งไว เรียกง่าย ครบทุกบริการ',
                style: TextStyle(
                  color: JdcColors.of(context).panelDim,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const LanguageSwitcher(),
      ],
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            JdcColors.of(context).brand,
            JdcColors.of(context).cta,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'พร้อมส่งทุกความต้องการ\nในแอปเดียว',
            style: TextStyle(
              color: JdcColors.of(context).panel,
              fontSize: 28,
              height: 1.2,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'เรียกรถ ส่งอาหาร ส่งพัสดุ และติดตามสถานะแบบเรียลไทม์',
            style: TextStyle(
              color: JdcColors.of(context).panel,
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _ServicePill(icon: Icons.delivery_dining, label: 'เรียกรถ'),
              _ServicePill(icon: Icons.fastfood, label: 'อาหาร'),
              _ServicePill(icon: Icons.inventory_2, label: 'พัสดุ'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow() {
    return Row(
      children: [
        Expanded(
          child: _FeatureCard(
            icon: Icons.route,
            title: 'ติดตามสด',
            subtitle: 'เห็นตำแหน่งแบบเรียลไทม์',
            color: JdcColors.of(context).cta,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _FeatureCard(
            icon: Icons.security,
            title: 'ปลอดภัย',
            subtitle: 'ตรวจสอบได้ทุกขั้นตอน',
            color: JdcColors.of(context).linkHover,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _FeatureCard(
            icon: Icons.bolt,
            title: 'เร็วทันใจ',
            subtitle: 'จับคู่คนขับไว',
            color: JdcColors.of(context).brand,
          ),
        ),
      ],
    );
  }

  Widget _buildActionPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: JdcColors.of(context).cta,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'เริ่มใช้งาน',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 50,
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: JdcColors.of(context).cta, width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'สมัครสมาชิกใหม่',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: JdcColors.of(context).cta,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServicePill extends StatelessWidget {
  const _ServicePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: JdcColors.of(context).panel),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: JdcColors.of(context).panel,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: JdcColors.of(context).panelSoft2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: JdcColors.of(context).panelDim,
              fontSize: 10.5,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
