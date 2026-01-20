import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/profile_service.dart';
import '../models/booking.dart';
import '../services/booking_service.dart';
import '../theme/app_theme.dart';
import 'auth/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BookingService _bookingService = BookingService();
  final ProfileService _profileService = ProfileService();
  late Future<List<Booking>> _bookingsFuture;
  late Future<Map<String, dynamic>?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _bookingsFuture = _bookingService.getUserBookings();
    _profileFuture = _profileService.getCurrentProfile();
  }

  Future<void> _refreshBookings() async {
    setState(() {
      _bookingsFuture = _bookingService.getUserBookings();
      _profileFuture = _profileService.getCurrentProfile();
    });
  }

  Future<void> _logout() async {
    await SupabaseService.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  String _getRoleLabel(String? role) {
    switch (role) {
      case 'customer':
        return 'ลูกค้า';
      case 'driver':
        return 'คนขับ';
      case 'merchant':
        return 'ร้านค้า';
      case 'admin':
        return 'ผู้ดูแลระบบ';
      default:
        return 'ผู้ใช้';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jedechai Delivery'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'ออกจากระบบ',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshBookings,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // User Info Card
            FutureBuilder<Map<String, dynamic>?>(
              future: _profileFuture,
              builder: (context, snapshot) {
                final profile = snapshot.data;
                final fullName = profile?['full_name'] as String?;
                final role = profile?['role'] as String?;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person,
                                size: 30,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ยินดีต้อนรับ',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Colors.grey.shade600,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    fullName ?? user?.email ?? 'ผู้ใช้',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryGreen
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _getRoleLabel(role),
                                      style: const TextStyle(
                                        color: AppTheme.primaryGreen,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            
            // Service Selection
            Text(
              'เลือกบริการ',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ServiceCard(
                    icon: Icons.restaurant,
                    title: 'ส่งอาหาร',
                    color: Colors.orange,
                    onTap: () {
                      // Navigate to food delivery
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ServiceCard(
                    icon: Icons.inventory_2,
                    title: 'ส่งพัสดุ',
                    color: Colors.blue,
                    onTap: () {
                      // Navigate to parcel delivery
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ServiceCard(
                    icon: Icons.directions_car,
                    title: 'รับส่ง',
                    color: Colors.green,
                    onTap: () {
                      // Navigate to transport
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Recent Bookings
            Text(
              'การจองล่าสุด',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Booking>>(
              future: _bookingsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'),
                  );
                }

                final bookings = snapshot.data ?? [];

                if (bookings.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('ยังไม่มีรายการจอง'),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    final booking = bookings[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text('Booking #${booking.id.substring(0, 8)}'),
                        subtitle: Text('สถานะ: ${booking.status}'),
                        trailing: Icon(_getStatusIcon(booking.status)),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending;
      case 'accepted':
        return Icons.check_circle_outline;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }
}

class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
