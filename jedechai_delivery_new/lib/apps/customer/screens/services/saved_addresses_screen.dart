import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../common/models/saved_address.dart';
import '../../../../common/services/address_service.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../theme/jdc_layout.dart';
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

  Future<void> _showAddEditDialog({
    SavedAddress? existing,
    String? initialLabel,
    String? initialName,
  }) async {
    final nameController =
        TextEditingController(text: existing?.name ?? initialName ?? '');
    final addressController =
        TextEditingController(text: existing?.address ?? '');
    final noteController = TextEditingController(text: existing?.note ?? '');
    double? pickedLat = existing?.latitude;
    double? pickedLng = existing?.longitude;
    String pickedAddress = existing?.address ?? '';

    String selectedLabel = existing?.label ?? initialLabel ?? 'other';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                existing != null
                    ? AppLocalizations.of(context)!.addrEditTitle
                    : AppLocalizations.of(context)!.addrAddTitle,
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
                        hintText:
                            AppLocalizations.of(context)!.addrPlaceNameHint,
                        prefixIcon: Icon(Icons.edit),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Map pin picker button
                    Builder(builder: (context) {
                      final jdc2 = JdcColors.of(context);
                      return InkWell(
                        onTap: () async {
                          final mapResult = await Navigator.of(context)
                              .push<Map<String, dynamic>>(
                            MaterialPageRoute(
                              builder: (_) => DeliveryMapPickerScreen(
                                initialPosition:
                                    pickedLat != null && pickedLng != null
                                        ? LatLng(pickedLat!, pickedLng!)
                                        : null,
                              ),
                            ),
                          );
                          if (mapResult != null) {
                            setDialogState(() {
                              pickedLat = mapResult['lat'] as double;
                              pickedLng = mapResult['lng'] as double;
                              pickedAddress =
                                  mapResult['address'] as String? ?? '';
                              if (addressController.text.isEmpty) {
                                addressController.text = pickedAddress;
                              }
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(JdcRadius.small),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: JdcSpacing.md,
                              vertical: JdcSpacing.lg),
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(JdcRadius.small),
                            border: Border.all(
                              color: pickedLat != null ? jdc2.cta : jdc2.line,
                              width: pickedLat != null ? 2 : 1,
                            ),
                            color:
                                pickedLat != null ? jdc2.brandSoft : jdc2.paper,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                pickedLat != null
                                    ? Icons.check_circle
                                    : Icons.pin_drop,
                                color:
                                    pickedLat != null ? jdc2.cta : jdc2.muted,
                                size: 22,
                              ),
                              const SizedBox(width: JdcSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pickedLat != null
                                          ? AppLocalizations.of(context)!
                                              .addrPinPlaced
                                          : AppLocalizations.of(context)!
                                              .addrPinOnMap,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: pickedLat != null
                                            ? jdc2.cta
                                            : jdc2.muted,
                                      ),
                                    ),
                                    if (pickedLat != null)
                                      Text(
                                        pickedAddress.isNotEmpty
                                            ? pickedAddress
                                            : '${pickedLat!.toStringAsFixed(5)}, ${pickedLng!.toStringAsFixed(5)}',
                                        style: TextStyle(
                                            fontSize: 11, color: jdc2.dim),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: jdc2.muted),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),

                    // Address
                    TextField(
                      controller: addressController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText:
                            AppLocalizations.of(context)!.addrAddressLabel,
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
                    if (nameController.text.trim().isEmpty ||
                        pickedLat == null ||
                        pickedLng == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                AppLocalizations.of(context)!.addrValidation)),
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
                    backgroundColor: JdcColors.of(context).cta,
                    foregroundColor: JdcColors.of(context).onCta,
                  ),
                  child: Text(AppLocalizations.of(context)!.addrSave),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    addressController.dispose();
    noteController.dispose();
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
    final jdc = JdcColors.of(context);
    final isSelected = value == selected;
    return ChoiceChip(
      avatar: Icon(icon, size: 18, color: isSelected ? jdc.onCta : jdc.muted),
      label: Text(label),
      selected: isSelected,
      selectedColor: jdc.cta,
      labelStyle: TextStyle(
        color: isSelected ? jdc.onCta : jdc.text,
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
        content:
            Text(AppLocalizations.of(context)!.addrDeleteConfirm(addr.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.addrCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: JdcColors.of(context).danger),
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

  Widget _buildQuickAddButton(
      String label, String name, IconData icon, Color color) {
    return OutlinedButton.icon(
      onPressed: () => _showAddEditDialog(
        initialLabel: label,
        initialName: name,
      ),
      icon: Icon(icon, color: color),
      label: Text(AppLocalizations.of(context)!.addrQuickAdd(name)),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(
            horizontal: JdcSpacing.xl, vertical: JdcSpacing.md),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JdcRadius.small)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    return Scaffold(
      backgroundColor: jdc.paper,
      appBar: AppBar(
        title: Text(widget.pickMode
            ? AppLocalizations.of(context)!.addrPickTitle
            : AppLocalizations.of(context)!.addrBookTitle),
        backgroundColor: jdc.surface,
        foregroundColor: jdc.text,
        titleTextStyle:
            Theme.of(context).textTheme.titleLarge?.copyWith(color: jdc.text),
        shape: Border(bottom: BorderSide(color: jdc.line)),
        iconTheme: IconThemeData(color: jdc.text),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: jdc.cta))
          : _addresses.isEmpty
              ? _buildEmptyState()
              : _buildAddressList(),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          decoration: BoxDecoration(
            color: jdc.surface,
            border: Border(top: BorderSide(color: jdc.line)),
          ),
          child: SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () => _showAddEditDialog(),
              icon: const Icon(Icons.add),
              label: Text(AppLocalizations.of(context)!.addrAddButton),
              style: ElevatedButton.styleFrom(
                backgroundColor: jdc.cta,
                foregroundColor: jdc.onCta,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final jdc = JdcColors.of(context);
    // Center คุมให้อยู่กลางจอ, ScrollView กันล้นบนจอเตี้ย/แนวนอน
    return Center(
      child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(JdcSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_off_rounded,
              size: 80,
              color: jdc.offTrack,
            ),
            const SizedBox(height: JdcSpacing.lg),
            Text(
              AppLocalizations.of(context)!.addrEmptyTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: jdc.muted,
              ),
            ),
            const SizedBox(height: JdcSpacing.sm),
            Text(
              AppLocalizations.of(context)!.addrEmptySubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: jdc.dim,
              ),
            ),
            const SizedBox(height: JdcSpacing.xxl),
            // ปุ่มลัดสองปุ่มยาวเกินจอแคบ ใช้ Wrap ให้ตกบรรทัดแทนการล้น
            Wrap(
              alignment: WrapAlignment.center,
              spacing: JdcSpacing.lg,
              runSpacing: JdcSpacing.md,
              children: [
                _buildQuickAddButton(
                    'home',
                    AppLocalizations.of(context)!.addrLabelHome,
                    Icons.home_rounded,
                    jdc.infoInk),
                _buildQuickAddButton(
                    'work',
                    AppLocalizations.of(context)!.addrLabelWork,
                    Icons.work_rounded,
                    jdc.link),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildAddressList() {
    return RefreshIndicator(
      onRefresh: _loadAddresses,
      child: ListView.builder(
        padding: const EdgeInsets.all(JdcSpacing.lg),
        itemCount: _addresses.length,
        itemBuilder: (context, index) {
          final addr = _addresses[index];
          return _buildAddressCard(addr);
        },
      ),
    );
  }

  Widget _buildAddressCard(SavedAddress addr) {
    final jdc = JdcColors.of(context);
    final isDefault = addr.label == 'home';
    return Container(
      margin: const EdgeInsets.only(bottom: JdcSpacing.md),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        border: Border.all(
            color: isDefault ? jdc.brandLine : jdc.line,
            width: isDefault ? 2 : 1),
      ),
      child: InkWell(
        onTap: widget.pickMode
            ? () => Navigator.pop(context, addr)
            : () => _showAddEditDialog(existing: addr),
        borderRadius: BorderRadius.circular(JdcRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(JdcSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isDefault ? jdc.brandSoft : jdc.sunken,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      _iconForLabel(addr.label),
                      color: isDefault ? jdc.brandOnSoft : jdc.muted,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: JdcSpacing.sm),
                  Expanded(
                    child: Text(
                      addr.name,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: jdc.text),
                    ),
                  ),
                  if (isDefault)
                    Text(
                      AppLocalizations.of(context)!.addrDefaultBadge,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: jdc.brandOnSoft),
                    ),
                ],
              ),
              const SizedBox(height: JdcSpacing.sm),
              Text(
                addr.address,
                style: TextStyle(fontSize: 13, color: jdc.muted, height: 1.6),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (addr.note != null && addr.note!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  addr.note!,
                  style: TextStyle(fontSize: 12, color: jdc.dim),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: JdcSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showAddEditDialog(existing: addr),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: jdc.text,
                        side: BorderSide(color: jdc.line),
                        minimumSize: const Size(0, JdcTouch.minTarget),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(JdcRadius.small)),
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(AppLocalizations.of(context)!.addrEditAction,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: jdc.text)),
                    ),
                  ),
                  const SizedBox(width: JdcSpacing.sm),
                  if (!widget.pickMode)
                    OutlinedButton(
                      onPressed: () => _deleteAddress(addr),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: jdc.dangerInk,
                        side: BorderSide(color: jdc.dangerLine),
                        minimumSize: const Size(92, JdcTouch.minTarget),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(JdcRadius.small)),
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(AppLocalizations.of(context)!.addrDelete,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: jdc.dangerInk)),
                    )
                  else
                    Icon(Icons.chevron_right, color: jdc.muted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
