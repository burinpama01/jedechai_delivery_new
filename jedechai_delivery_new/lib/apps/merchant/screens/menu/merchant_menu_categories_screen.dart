import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MerchantMenuCategoriesScreen extends StatefulWidget {
  const MerchantMenuCategoriesScreen({super.key});

  @override
  State<MerchantMenuCategoriesScreen> createState() =>
      _MerchantMenuCategoriesScreenState();
}

class _MerchantMenuCategoriesScreenState
    extends State<MerchantMenuCategoriesScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final merchantId = _client.auth.currentUser?.id;
    if (merchantId == null) {
      setState(() {
        _error = 'ไม่พบข้อมูลผู้ใช้';
        _isLoading = false;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final rows = await _client
          .from('menu_categories')
          .select()
          .eq('merchant_id', merchantId)
          .order('sort_order');
      if (!mounted) return;
      setState(() {
        _categories = List<Map<String, dynamic>>.from(rows);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveCategory({Map<String, dynamic>? category}) async {
    final controller = TextEditingController(
      text: category?['name']?.toString() ?? '',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(category == null ? 'เพิ่มหมวดหมู่' : 'แก้ไขหมวดหมู่'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'ชื่อหมวดหมู่'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;

    final merchantId = _client.auth.currentUser?.id;
    if (merchantId == null) return;
    try {
      if (category == null) {
        await _client.from('menu_categories').insert({
          'merchant_id': merchantId,
          'name': name,
          'sort_order': _categories.length,
          'is_active': true,
        });
      } else {
        await _client
            .from('menu_categories')
            .update({'name': name}).eq('id', category['id']);
      }
    } catch (e) {
      _showError(e);
      return;
    }
    await _loadCategories();
  }

  Future<void> _toggleCategory(Map<String, dynamic> category) async {
    try {
      await _client.from('menu_categories').update({
        'is_active': category['is_active'] != true,
      }).eq('id', category['id']);
    } catch (e) {
      _showError(e);
      return;
    }
    await _loadCategories();
  }

  Future<void> _moveCategory(int index, int delta) async {
    final target = index + delta;
    if (target < 0 || target >= _categories.length) return;
    final current = _categories[index];
    final other = _categories[target];
    try {
      await Future.wait([
        _client.from('menu_categories').update({
          'sort_order': other['sort_order'] ?? target,
        }).eq('id', current['id']),
        _client.from('menu_categories').update({
          'sort_order': current['sort_order'] ?? index,
        }).eq('id', other['id']),
      ]);
    } catch (e) {
      _showError(e);
      return;
    }
    await _loadCategories();
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('จัดการหมวดหมู่ไม่สำเร็จ: $error'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('หมวดหมู่เมนู')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _saveCategory(),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loadCategories,
                          icon: const Icon(Icons.refresh),
                          label: const Text('ลองใหม่'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadCategories,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      return ListTile(
                        leading: Switch(
                          value: category['is_active'] == true,
                          onChanged: (_) => _toggleCategory(category),
                        ),
                        title: Text(category['name']?.toString() ?? ''),
                        subtitle: Text('ลำดับ ${index + 1}'),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_upward),
                              onPressed: index == 0
                                  ? null
                                  : () => _moveCategory(index, -1),
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_downward),
                              onPressed: index == _categories.length - 1
                                  ? null
                                  : () => _moveCategory(index, 1),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () =>
                                  _saveCategory(category: category),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
