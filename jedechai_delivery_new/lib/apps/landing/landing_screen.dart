import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Landing Page — Public-facing page for Jedechai Delivery
///
/// Separate from Admin web panel.
/// Shows app features, download links, and login button.
class PublicLandingScreen extends StatelessWidget {
  const PublicLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildNavBar(context, isWide),
            _buildHeroSection(context, isWide),
            _buildServicesSection(isWide),
            _buildHowItWorksSection(isWide),
            _buildDriverCTASection(context, isWide),
            _buildFooter(isWide),
          ],
        ),
      ),
    );
  }

  // ─── Navigation Bar ─────────────────────────────────
  Widget _buildNavBar(BuildContext context, bool isWide) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 80 : 24,
        vertical: 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Logo
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Jedechai',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Login button
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('เข้าสู่ระบบ', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ─── Hero Section ───────────────────────────────────
  Widget _buildHeroSection(BuildContext context, bool isWide) {
    final content = Column(
      crossAxisAlignment: isWide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'บริการเรียกรถ\nส่งอาหาร & พัสดุ',
          textAlign: isWide ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            fontSize: isWide ? 48 : 32,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            height: 1.2,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'แพลตฟอร์ม Super App สำหรับชุมชน\nเรียกรถ สั่งอาหาร ส่งพัสดุ ครบจบในแอปเดียว',
          textAlign: isWide ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            fontSize: isWide ? 18 : 15,
            color: AppTheme.textSecondary,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: isWide ? WrapAlignment.start : WrapAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              icon: const Icon(Icons.phone_android, size: 20),
              label: const Text('เริ่มใช้งาน'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ],
    );

    final illustration = Container(
      height: isWide ? 400 : 240,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGreen.withValues(alpha: 0.08),
            AppTheme.primaryGreenLight.withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Icon(
          Icons.delivery_dining_rounded,
          size: isWide ? 160 : 100,
          color: AppTheme.primaryGreen.withValues(alpha: 0.3),
        ),
      ),
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 80 : 24,
        vertical: isWide ? 80 : 48,
      ),
      color: const Color(0xFFFAF8F5),
      child: isWide
          ? Row(
              children: [
                Expanded(child: content),
                const SizedBox(width: 60),
                Expanded(child: illustration),
              ],
            )
          : Column(
              children: [
                content,
                const SizedBox(height: 40),
                illustration,
              ],
            ),
    );
  }

  // ─── Services Section ───────────────────────────────
  Widget _buildServicesSection(bool isWide) {
    final services = [
      _ServiceItem(
        icon: Icons.local_taxi_rounded,
        title: 'เรียกรถ',
        description: 'เรียกรถมอเตอร์ไซค์หรือรถยนต์\nไปไหนก็ได้ สะดวก ปลอดภัย',
        color: const Color(0xFF3B82F6),
      ),
      _ServiceItem(
        icon: Icons.restaurant_rounded,
        title: 'สั่งอาหาร',
        description: 'สั่งอาหารจากร้านใกล้คุณ\nส่งถึงบ้านรวดเร็ว',
        color: const Color(0xFFEF6C00),
      ),
      _ServiceItem(
        icon: Icons.inventory_2_rounded,
        title: 'ส่งพัสดุ',
        description: 'ส่งพัสดุถึงปลายทาง\nราคาประหยัด ติดตามได้',
        color: const Color(0xFF16A34A),
      ),
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 80 : 24,
        vertical: 64,
      ),
      color: Colors.white,
      child: Column(
        children: [
          const Text(
            'บริการของเรา',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ครบทุกบริการในแอปเดียว',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 40),
          isWide
              ? Row(
                  children: services
                      .map((s) => Expanded(child: _buildServiceCard(s)))
                      .toList(),
                )
              : Column(
                  children: services.map((s) => _buildServiceCard(s)).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(_ServiceItem item) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: item.color, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            item.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            item.description,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
          ),
        ],
      ),
    );
  }

  // ─── How It Works ───────────────────────────────────
  Widget _buildHowItWorksSection(bool isWide) {
    final steps = [
      _StepItem(number: '1', title: 'สมัครสมาชิก', description: 'ลงทะเบียนด้วยเบอร์โทร'),
      _StepItem(number: '2', title: 'เลือกบริการ', description: 'เรียกรถ สั่งอาหาร หรือส่งพัสดุ'),
      _StepItem(number: '3', title: 'ยืนยันออเดอร์', description: 'เลือกจุดหมายและวิธีชำระเงิน'),
      _StepItem(number: '4', title: 'รับบริการ', description: 'คนขับรับงานและมาหาคุณ'),
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 80 : 24,
        vertical: 64,
      ),
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          const Text(
            'ใช้งานง่าย 4 ขั้นตอน',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 40),
          isWide
              ? Row(
                  children: steps
                      .map((s) => Expanded(child: _buildStepCard(s)))
                      .toList(),
                )
              : Column(
                  children: steps.map((s) => _buildStepCard(s)).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildStepCard(_StepItem item) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                item.number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            item.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            item.description,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // ─── Driver CTA ─────────────────────────────────────
  Widget _buildDriverCTASection(BuildContext context, bool isWide) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 80 : 24,
        vertical: 64,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryGreen, AppTheme.primaryGreenDark],
        ),
      ),
      child: Column(
        children: [
          const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 48),
          const SizedBox(height: 16),
          const Text(
            'สมัครเป็นคนขับ Jedechai',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'สร้างรายได้เสริม ทำงานอิสระ เลือกเวลาเอง',
            style: TextStyle(color: Colors.white70, fontSize: 15),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryGreen,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('สมัครเลย', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  // ─── Footer ─────────────────────────────────────────
  Widget _buildFooter(bool isWide) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 80 : 24,
        vertical: 32,
      ),
      color: const Color(0xFF0F172A),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'Jedechai Delivery',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '© ${DateTime.now().year} Jedechai Delivery. All rights reserved.',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Data models ──────────────────────────────────────
class _ServiceItem {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  _ServiceItem({required this.icon, required this.title, required this.description, required this.color});
}

class _StepItem {
  final String number;
  final String title;
  final String description;
  _StepItem({required this.number, required this.title, required this.description});
}
