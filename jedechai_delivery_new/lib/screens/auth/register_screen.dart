import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import 'login_screen.dart';

/// Register Screen
/// Allows users to create an account with role selection
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedRole = 'customer'; // Default role
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final List<Map<String, dynamic>> _roles = [
    {
      'value': 'customer',
      'label': 'ลูกค้า',
      'icon': Icons.person,
      'color': AppTheme.primaryGreen,
    },
    {
      'value': 'driver',
      'label': 'คนขับ',
      'icon': Icons.local_taxi,
      'color': AppTheme.accentBlue,
    },
    {
      'value': 'merchant',
      'label': 'ร้านค้า',
      'icon': Icons.store,
      'color': AppTheme.accentOrange,
    },
  ];

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if passwords match
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('รหัสผ่านไม่ตรงกัน')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Sign up with Supabase Auth
      final response = await SupabaseService.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {
          'full_name': _fullNameController.text.trim(),
          'phone': _phoneController.text.trim(),
        },
      );

      if (response.user == null) {
        throw Exception('Failed to create user');
      }

      // 2. Insert profile data into profiles table
      await SupabaseService.client.from('profiles').insert({
        'id': response.user!.id,
        'full_name': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': _selectedRole,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ลงทะเบียนสำเร็จ! กรุณาเข้าสู่ระบบ'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );

        // Navigate to login screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('สมัครสมาชิก'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              
              // Welcome Text
              const Text(
                'สร้างบัญชีใหม่',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'กรุณากรอกข้อมูลเพื่อสมัครสมาชิก',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 32),

              // Role Selection
              const Text(
                'เลือกประเภทบัญชี',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: _roles.map((role) {
                  final isSelected = _selectedRole == role['value'];
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _RoleChip(
                        label: role['label'] as String,
                        icon: role['icon'] as IconData,
                        color: role['color'] as Color,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            _selectedRole = role['value'] as String;
                          });
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // Full Name Field
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'ชื่อ-นามสกุล',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'กรุณากรอกชื่อ-นามสกุล';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Phone Field
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'เบอร์โทรศัพท์',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'กรุณากรอกเบอร์โทรศัพท์';
                  }
                  if (value.length < 10) {
                    return 'เบอร์โทรศัพท์ไม่ถูกต้อง';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email Field
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'อีเมล',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'กรุณากรอกอีเมล';
                  }
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'อีเมลไม่ถูกต้อง';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Password Field
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'รหัสผ่าน',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'กรุณากรอกรหัสผ่าน';
                  }
                  if (value.length < 6) {
                    return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Confirm Password Field
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'ยืนยันรหัสผ่าน',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscureConfirmPassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'กรุณายืนยันรหัสผ่าน';
                  }
                  if (value != _passwordController.text) {
                    return 'รหัสผ่านไม่ตรงกัน';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Register Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'สมัครสมาชิก',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Login Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('มีบัญชีแล้ว? '),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: const Text(
                      'เข้าสู่ระบบ',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
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

/// Role Selection Chip Widget
class _RoleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade100,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey.shade600,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? color : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
