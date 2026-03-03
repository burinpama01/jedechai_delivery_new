import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

/// Landing Page — Public-facing page for JDC Delivery
///
/// Separate from Admin web panel.
/// Shows app features, download links, and login button.
class PublicLandingScreen extends StatelessWidget {
  const PublicLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildNavBar(context, isWide, l10n),
            _buildHeroSection(context, isWide, l10n),
            _buildServicesSection(context, isWide, l10n),
            _buildHowItWorksSection(context, isWide, l10n),
            _buildDriverCTASection(context, isWide, l10n),
            _buildFooter(context, isWide),
          ],
        ),
      ),
    );
  }

  // ─── Navigation Bar ─────────────────────────────────
  Widget _buildNavBar(BuildContext context, bool isWide, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 80 : 24,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
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
              Text(
                'Jedechai',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
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
            child: Text(l10n.landingLogin, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ─── Hero Section ───────────────────────────────────
  Widget _buildHeroSection(BuildContext context, bool isWide, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    final content = Column(
      crossAxisAlignment: isWide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          l10n.landingHeadline,
          textAlign: isWide ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            fontSize: isWide ? 48 : 32,
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
            height: 1.2,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.landingSubheadline,
          textAlign: isWide ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            fontSize: isWide ? 18 : 15,
            color: colorScheme.onSurfaceVariant,
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
              label: Text(l10n.landingStart),
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
  Widget _buildServicesSection(BuildContext context, bool isWide, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    final services = [
      _ServiceItem(
        icon: Icons.local_taxi_rounded,
        title: l10n.landingServiceRideTitle,
        description: l10n.landingServiceRideDesc,
        color: const Color(0xFF3B82F6),
      ),
      _ServiceItem(
        icon: Icons.restaurant_rounded,
        title: l10n.landingServiceFoodTitle,
        description: l10n.landingServiceFoodDesc,
        color: const Color(0xFFEF6C00),
      ),
      _ServiceItem(
        icon: Icons.inventory_2_rounded,
        title: l10n.landingServiceParcelTitle,
        description: l10n.landingServiceParcelDesc,
        color: const Color(0xFF16A34A),
      ),
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 80 : 24,
        vertical: 64,
      ),
      color: colorScheme.surface,
      child: Column(
        children: [
          Text(
            l10n.landingServicesTitle,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.landingServicesSubtitle,
            style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 40),
          isWide
              ? Row(
                  children: services
                      .map((s) => Expanded(child: _buildServiceCard(context, s)))
                      .toList(),
                )
              : Column(
                  children: services.map((s) => _buildServiceCard(context, s)).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context, _ServiceItem item) {
    final colorScheme = Theme.of(context).colorScheme;
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
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ─── How It Works ───────────────────────────────────
  Widget _buildHowItWorksSection(BuildContext context, bool isWide, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    final steps = [
      _StepItem(
        number: l10n.landingHowStep1Number,
        title: l10n.landingHowStep1Title,
        description: l10n.landingHowStep1Desc,
      ),
      _StepItem(
        number: l10n.landingHowStep2Number,
        title: l10n.landingHowStep2Title,
        description: l10n.landingHowStep2Desc,
      ),
      _StepItem(
        number: l10n.landingHowStep3Number,
        title: l10n.landingHowStep3Title,
        description: l10n.landingHowStep3Desc,
      ),
      _StepItem(
        number: l10n.landingHowStep4Number,
        title: l10n.landingHowStep4Title,
        description: l10n.landingHowStep4Desc,
      ),
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 80 : 24,
        vertical: 64,
      ),
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          Text(
            l10n.landingHowTitle,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: colorScheme.onSurface),
          ),
          const SizedBox(height: 40),
          isWide
              ? Row(
                  children: steps
                      .map((s) => Expanded(child: _buildStepCard(context, s)))
                      .toList(),
                )
              : Column(
                  children: steps.map((s) => _buildStepCard(context, s)).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildStepCard(BuildContext context, _StepItem item) {
    final colorScheme = Theme.of(context).colorScheme;
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
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // ─── Driver CTA ─────────────────────────────────────
  Widget _buildDriverCTASection(BuildContext context, bool isWide, AppLocalizations l10n) {
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
          Text(
            l10n.landingDriverCtaTitle,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.landingDriverCtaSubtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 15),
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
            child: Text(
              l10n.landingSignupNow,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Footer ─────────────────────────────────────────
  Widget _buildFooter(BuildContext context, bool isWide) {
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
                'JDC Delivery',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '© ${DateTime.now().year} JDC Delivery. All rights reserved.',
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
