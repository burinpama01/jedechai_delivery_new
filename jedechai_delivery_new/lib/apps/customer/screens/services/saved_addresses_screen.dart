import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../common/models/saved_address.dart';
import '../../../../common/services/address_service.dart';
import '../../../../theme/app_theme.dart';
import 'delivery_map_picker_screen.dart';

/// Saved Addresses Screen
///
/// Allows customers to manage saved addresses (home, work, other)
class SavedAddressesScreen extends StatefulWidget {
  /// If true, the screen is in "pick" mode — tapping an address returns it
  final bool pickMode;

  const SavedAddressesScreen({super.key, this.pickMode = false});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  final AddressService _addressService = AddressService();
  List<SavedAddress> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() => _isLoading = true);
    final addresses = await _addressService.getAddresses();
    if (mounted) {
      setState(() {
        _addresses = addresses;
        _isLoading = false;
      });
    }
  }

  bool get _hasHome => _addresses.any((a) => a.label == 'home');
  bool get _hasWork => _addresses.any((a) => a.label == 'work');

  IconData _iconForLabel(String label) {
    switch (label) {
      case 'home':
        return Icons.home_rounded;
      case 'work':
        return Icons.work_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }

  Color _colorForLabel(String label) {
    switch (label) {
      case 'home':
        return Colors.blue;
      case 'work':
        return Colors.orange;
      default:
        return AppTheme.primaryGreen;
    }
  }

  String _displayLabel(String label) {
    final l10n = AppLocalizations.of(context)!;
    switch (label) {
      case 'home':
        return l10n.addrLabelHome;
      case 'work':
        return l10n.addrLabelWork;
      default:
        return l10n.addrLabelOther;
    }
  }

  Future<void> _showAddEditDialog({SavedAddress? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final addressController = TextEditingController(text: existing?.address ?? '');
    final noteController = TextEditingController(text: existing?.note ?? '');
    double? pickedLat = existing?.latitude;
    double? pickedLng = existing?.longitude;
    String pickedAddress = existing?.address ?? '';

    String selectedLabel = existing?.label ?? 'other';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                existing != null ? AppLocalizations.of(context)!.addrEditTitle : AppLocalizations.of(context)!.addrAddTitle,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Label selector
                    Text(
                      AppLocalizations.of(context)!.addrType,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (!_hasHome || existing?.label == 'home')
                          _buildLabelChip(
                            'home',
                            AppLocalizations.of(context)!.addrLabelHome,
                            Icons.home_rounded,
                            selectedLabel,
                            (val) => setDialogState(() => selectedLabel = val),
                          ),
                        if (!_hasWork || existing?.label == 'work')
                          _buildLabelChip(
                            'work',
                            AppLocalizations.of(context)!.addrLabelWork,
                            Icons.work_rounded,
                            selectedLabel,
                            (val) => setDialogState(() => selectedLabel = val),
                          ),
                        _buildLabelChip(
                          'other',
                          AppLocalizations.of(context)!.addrLabelOther,
                          Icons.location_on_rounded,
                          selectedLabel,
                          (val) => setDialogState(() => selectedLabel = val),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Name
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.addrPlaceName,
                        hintText: AppLocalizations.of(context)!.addrPlaceNameHint,
                        prefixIcon: Icon(Icons.edit),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Map pin picker button
                    InkWell(
                      onTap: () async {
                        final mapResult = await Navigator.of(context).push<Map<String, dynamic>>(
                          MaterialPageRoute(
                            builder: (_) => DeliveryMapPickerScreen(
                              initialPosition: pickedLat != null && pickedLng != null
                                  ? LatLng(pickedLat!, pickedLng!)
                                  : null,
                            ),
                          ),
                        );
                        if (mapResult != null) {
                          setDialogState(() {
                            pickedLat = mapResult['lat'] as double;
                            pickedLng = mapResult['lng'] as double;
                            pickedAddress = mapResult['address'] as String? ?? '';
                            if (addressController.text.isEmpty) {
                              addressController.text = pickedAddress;
                            }
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: pickedLat != null ? AppTheme.primaryGreen : Colors.grey.shade300,
                            width: pickedLat != null ? 2 : 1,
                          ),
                          color: pickedLat != null
                              ? AppTheme.primaryGreen.withValues(alpha: 0.05)
                              : Colors.grey.shade50,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              pickedLat != null ? Icons.check_circle : Icons.pin_drop,
                              color: pickedLat != null ? AppTheme.primaryGreen : Colors.grey,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pickedLat != null ? AppLocalizations.of(context)!.addrPinPlaced : AppLocalizations.of(context)!.addrPinOnMap,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: pickedLat != null
                                          ? AppTheme.primaryGreen
                                          : Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  if (pickedLat != null)
                                    Text(
                                      pickedAddress.isNotEmpty ? pickedAddress : '${pickedLat!.toStringAsFixed(5)}, ${pickedLng!.toStringAsFixed(5)}',
                                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: Colors.grey[400]),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Address
                    TextField(
                      controller: addressController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.addrAddressLabel,
                        hintText: AppLocalizations.of(context)!.addrAddressHint,
                        prefixIcon: Icon(Icons.map),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Note
                    TextField(
                      controller: noteController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.addrNoteLabel,
                        hintText: AppLocalizations.of(context)!.addrNoteHint,
                        prefixIcon: Icon(Icons.note),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(AppLocalizations.of(context)!.addrCancel),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty || pickedLat == null || pickedLng == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppLocalizations.of(context)!.addrValidation)),
                      );
                      return;
                    }

                    final address = addressController.text.trim().isNotEmpty
                        ? addressController.text.trim()
                        : pickedAddress;

                    await _addressService.saveAddress(
                      label: selectedLabel,
                      name: nameController.text.trim(),
                      address: address,
                      latitude: pickedLat!,
                      longitude: pickedLng!,
                      note: noteController.text.trim().isEmpty
                          ? null
                          : noteController.text.trim(),
                    );

                    if (context.mounted) Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                  ),
                  child: Text(AppLocalizations.of(context)!.addrSave),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      _loadAddresses();
    }
  }

  Widget _buildLabelChip(
    String value,
    String label,
    IconData icon,
    String selected,
    ValueChanged<String> onSelected,
  ) {
    final isSelected = value == selected;
    return ChoiceChip(
      avatar: Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.grey),
      label: Text(label),
      selected: isSelected,
      selectedColor: _colorForLabel(value),
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      onSelected: (_) => onSelected(value),
    );
  }

  Future<void> _deleteAddress(SavedAddress addr) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.addrDeleteTitle),
        content: Text(AppLocalizations.of(context)!.addrDeleteConfirm(addr.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.addrCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.addrDelete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _addressService.deleteAddress(addr.id);
      if (success) {
        _loadAddresses();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pickMode ? AppLocalizations.of(context)!.addrPickTitle : AppLocalizations.of(context)!.addrBookTitle),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _addresses.isEmpty
              ? _buildEmptyState()
              : _buildAddressList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add),
        label: Text(AppLocalizations.of(context)!.addrAddButton),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off_rounded,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.addrEmptyTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.addrEmptySubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          // Quick add buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildQuickAddButton('home', AppLocalizations.of(context)!.addrLabelHome, Icons.home_rounded, Colors.blue),
              const SizedBox(width: 16),
              _buildQuickAddButton('work', AppLocalizations.of(context)!.addrLabelWork, Icons.work_rounded, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddButton(String label, String name, IconData icon, Color color) {
    return OutlinedButton.icon(
      onPressed: () => _showAddEditDialog(
        existing: SavedAddress(
          id: '',
          userId: '',
          label: label,
          name: name,
          address: '',
          latitude: 0,
          longitude: 0,
          createdAt: DateTime.now(),
        ),
      ),
      icon: Icon(icon, color: color),
      label: Text(AppLocalizations.of(context)!.addrQuickAdd(name)),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildAddressList() {
    return RefreshIndicator(
      onRefresh: _loadAddresses,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _addresses.length,
        itemBuilder: (context, index) {
          final addr = _addresses[index];
          return _buildAddressCard(addr);
        },
      ),
    );
  }

  Widget _buildAddressCard(SavedAddress addr) {
    final color = _colorForLabel(addr.label);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        onTap: widget.pickMode
            ? () => Navigator.pop(context, addr)
            : () => _showAddEditDialog(existing: addr),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconForLabel(addr.label), color: color, size: 28),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          addr.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _displayLabel(addr.label),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      addr.address,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (addr.note != null && addr.note!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '📝 ${addr.note}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Actions
              if (!widget.pickMode)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteAddress(addr),
                )
              else
                Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
