import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../common/services/referral_service.dart';
import '../../../../common/services/notification_service.dart';
import '../../../../common/services/auth_service.dart';
import '../../../../theme/app_theme.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({Key? key}) : super(key: key);

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;

  final ReferralService _referralService = ReferralService();
  String myReferralCode = '-';
  int totalReferrals = 0;
  double totalRewards = 0.0;

  bool _didCheckReferralRewardDialog = false;

  @override
  void initState() {
    super.initState();
    _loadReferralData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowReferralRewardDialogIfAny();
    });
  }

  Future<void> _checkAndShowReferralRewardDialogIfAny() async {
    if (!mounted) return;
    if (_didCheckReferralRewardDialog) return;
    _didCheckReferralRewardDialog = true;

    final userId = AuthService.userId;
    if (userId == null) return;

    final unread = await NotificationService.getUnreadByTypes(
      userId,
      const ['referral_reward_referrer'],
      limit: 1,
    );
    if (!mounted) return;
    if (unread.isEmpty) return;

    final n = unread.first;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(n.title),
        content: Text(n.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );

    await NotificationService.markAsRead(n.id);
  }
  
  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadReferralData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final code = await _referralService.getOrCreateMyReferralCode();
      final count = await _referralService.getMyTotalReferrals();

      if (!mounted) return;
      setState(() {
        myReferralCode = code;
        totalReferrals = count;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: myReferralCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('คัดลอกโค้ดชวนเพื่อนแล้ว')),
    );
  }

  void _submitCode() async {
    if (_codeController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _referralService.submitReferralCode(_codeController.text);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ใช้โค้ดสำเร็จ!')),
      );
      _codeController.clear();
      await _loadReferralData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ชวนเพื่อนรับรางวัล', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primaryGreen,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeroSection(),
            _buildMyCodeSection(),
            _buildEnterCodeSection(),
            _buildStatsSection(),
            _buildHowItWorks(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      color: AppTheme.primaryGreen,
      padding: const EdgeInsets.only(bottom: 32, left: 24, right: 24),
      child: Column(
        children: [
          const Icon(Icons.people_alt, size: 80, color: Colors.white),
          const SizedBox(height: 16),
          const Text(
            'ชวนเพื่อนใช้แอป\nรับคูปองทั้งคู่!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'รับคูปองส่วนลด 20 บาท ทันที\nเมื่อเพื่อนของคุณสั่งอาหารครั้งแรกสำเร็จ',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyCodeSection() {
    final colorScheme = Theme.of(context).colorScheme;

    return Transform.translate(
      offset: const Offset(0, -20),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'โค้ดชวนเพื่อนของคุณ',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    myReferralCode,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen,
                      letterSpacing: 2,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: AppTheme.primaryGreen),
                    onPressed: _copyToClipboard,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _copyToClipboard,
                icon: const Icon(Icons.share),
                label: const Text('แชร์ให้เพื่อน'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnterCodeSection() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'มีโค้ดชวนเพื่อนไหม?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'กรอกโค้ดจากเพื่อนเพื่อรับคูปองต้อนรับทันที',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    hintText: 'กรอกโค้ดที่นี่',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading 
                    ? const SizedBox(
                        width: 20, 
                        height: 20, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                    : const Text('ใช้โค้ด'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outline.withOpacity(0.12)),
        ),
        child: Column(
          children: [
            Icon(Icons.people, color: colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              '$totalReferrals',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            Text(
              'ชวนสำเร็จ',
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorks() {
    return Container(
      margin: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ทำงานอย่างไร?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildStepItem(
            '1', 
            'แชร์โค้ดให้เพื่อน', 
            'ส่งโค้ดของคุณให้เพื่อนที่ยังไม่เคยใช้แอป'
          ),
          _buildStepItem(
            '2', 
            'เพื่อนสั่งอาหารครั้งแรก', 
            'เพื่อนสมัครและสั่งอาหารสำเร็จเป็นครั้งแรก'
          ),
          _buildStepItem(
            '3', 
            'รับคูปองส่วนลด!', 
            'คุณจะได้คูปองส่วนลดส่งตรงเข้ากระเป๋าทันที'
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(String number, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: AppTheme.primaryGreen,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
