import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../common/services/auth_service.dart';
import '../../../../theme/app_theme.dart';
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
      _showErrorDialog('รหัสผ่านไม่ตรงกัน\nกรุณาตรวจสอบแล้วลองใหม่');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final phone = _phoneController.text.trim();
      
      // ── ตรวจสอบข้อมูลซ้ำก่อนสมัคร ──
      try {
        // ตรวจสอบเบอร์โทรซ้ำ
        final phoneCheck = await Supabase.instance.client
            .from('profiles')
            .select('id')
            .eq('phone_number', phone)
            .maybeSingle();
        if (phoneCheck != null) {
          _showErrorDialog('เบอร์โทรศัพท์นี้ถูกใช้งานแล้ว\nกรุณาใช้เบอร์โทรอื่นหรือเข้าสู่ระบบ');
          return;
        }
        
        // ตรวจสอบอีเมลซ้ำใน profiles
        final emailCheck = await Supabase.instance.client
            .from('profiles')
            .select('id')
            .eq('email', email)
            .maybeSingle();
        if (emailCheck != null) {
          _showErrorDialog('อีเมลนี้ถูกใช้งานแล้ว\nกรุณาเข้าสู่ระบบหรือใช้อีเมลอื่น');
          return;
        }
      } catch (dupCheckError) {
        // profiles อาจไม่มี email column — ไม่บล็อกการสมัคร
        // Supabase auth จะตรวจ email ซ้ำเอง
        debugLog('⚠️ Duplicate check error (non-blocking): $dupCheckError');
      }
      
      final userData = {
        'full_name': _fullNameController.text.trim(),
        'phone_number': phone,
        'role': _selectedRole,
      };
      
      debugLog('═══════════════════════════════════════');
      debugLog('🚀 เริ่มสมัครสมาชิก');
      debugLog('📧 Email: $email');
      debugLog('👤 Role: $_selectedRole');
      debugLog('📋 UserData: $userData');
      debugLog('═══════════════════════════════════════');
      
      // 1. Sign up with AuthService
      final response = await AuthService.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        userData: userData,
      );
      
      debugLog('═══════════════════════════════════════');
      debugLog('📦 SignUp Response:');
      debugLog('   user: ${response.user?.id}');
      debugLog('   email: ${response.user?.email}');
      debugLog('   session: ${response.session != null ? "มี session" : "ไม่มี session (email confirmation?)"}');
      debugLog('   metadata: ${response.user?.userMetadata}');
      debugLog('═══════════════════════════════════════');

      if (response.user == null) {
        debugLog('❌ response.user เป็น null — ไม่สามารถสร้าง user ได้');
        throw Exception('Failed to create user');
      }

      // 2. ตรวจสอบว่า profile ถูกสร้างหรือยัง
      try {
        final profileCheck = await Supabase.instance.client
            .from('profiles')
            .select('id, role, approval_status')
            .eq('id', response.user!.id)
            .maybeSingle();
        
        if (profileCheck != null) {
          debugLog('✅ Profile ถูกสร้างเรียบร้อย: $profileCheck');
        } else {
          debugLog('⚠️ Profile ยังไม่ถูกสร้าง — อาจต้องรอ trigger หรือสร้างตอน login');
        }
      } catch (checkError) {
        debugLog('⚠️ ไม่สามารถตรวจสอบ profile ได้: $checkError');
      }

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e, stackTrace) {
      debugLog('═══════════════════════════════════════');
      debugLog('❌ สมัครสมาชิกล้มเหลว!');
      debugLog('   Error: $e');
      debugLog('   Type: ${e.runtimeType}');
      debugLog('   StackTrace: $stackTrace');
      debugLog('═══════════════════════════════════════');
      if (mounted) {
        _showErrorDialog(_getThaiErrorMessage(e.toString()));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getThaiErrorMessage(String error) {
    if (error.contains('already registered') || error.contains('already exists') || error.contains('User already registered')) {
      return 'อีเมลนี้ถูกใช้งานแล้ว\nกรุณาเข้าสู่ระบบหรือใช้อีเมลอื่น';
    } else if (error.contains('weak password') || error.contains('Password')) {
      return 'รหัสผ่านไม่ปลอดภัย\nกรุณาใช้รหัสผ่านที่มีความยาวอย่างน้อย 6 ตัวอักษร';
    } else if (error.contains('invalid email') || error.contains('Invalid email')) {
      return 'รูปแบบอีเมลไม่ถูกต้อง\nกรุณาตรวจสอบอีเมลของคุณ';
    } else if (error.contains('SocketException') || error.contains('Failed host lookup') || error.contains('เชื่อมต่อ')) {
      return 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้\nกรุณาตรวจสอบอินเทอร์เน็ตของคุณ';
    } else if (error.contains('Too many requests') || error.contains('rate_limit')) {
      return 'คุณลองบ่อยเกินไป\nกรุณารอสักครู่แล้วลองใหม่';
    }
    return 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.error_outline, color: Colors.red, size: 48),
        title: const Text(
          'สมัครไม่สำเร็จ',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('ตกลง', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 48),
        title: const Text(
          'สมัครสำเร็จ!',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: const Text(
          'ลงทะเบียนเรียบร้อยแล้ว\nกรุณาเข้าสู่ระบบเพื่อเริ่มใช้งาน',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(this.context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('เข้าสู่ระบบ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
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
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
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
              Text(
                'สร้างบัญชีใหม่',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'กรุณากรอกข้อมูลเพื่อสมัครสมาชิก',
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),

              // Role Selection
              Text(
                'เลือกประเภทบัญชี',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
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
                          debugLog('🔄 Role selected: ${role['value']} (was: $_selectedRole)');
                          setState(() {
                            _selectedRole = role['value'] as String;
                          });
                          debugLog('✅ Role updated to: $_selectedRole');
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
                  Text(
                    'มีบัญชีแล้ว? ',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
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
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: isSelected
                ? color
                : colorScheme.outlineVariant.withValues(alpha: 0.8),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : colorScheme.onSurfaceVariant,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? color : colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
