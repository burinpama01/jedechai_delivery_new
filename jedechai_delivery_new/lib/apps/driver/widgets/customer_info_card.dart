import 'package:flutter/material.dart';

/// Displays customer (and optionally merchant) contact info in the navigation bottom panel.
class CustomerInfoCard extends StatelessWidget {
  final String customerName;
  final String customerPhone;
  final String serviceType;
  final String merchantName;
  final String merchantPhone;
  final bool showMerchantCallButton;
  final VoidCallback onCallCustomer;
  final VoidCallback? onCallMerchant;

  const CustomerInfoCard({
    super.key,
    required this.customerName,
    required this.customerPhone,
    required this.serviceType,
    this.merchantName = '',
    this.merchantPhone = '',
    this.showMerchantCallButton = false,
    required this.onCallCustomer,
    this.onCallMerchant,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Customer card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.24),
                child: Icon(Icons.person, size: 18, color: colorScheme.onPrimary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customerName,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onPrimaryContainer),
                        overflow: TextOverflow.ellipsis),
                    Text(customerPhone,
                        style: TextStyle(fontSize: 11, color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8))),
                  ],
                ),
              ),
              InkWell(
                onTap: onCallCustomer,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: colorScheme.primaryContainer, shape: BoxShape.circle),
                  child: Icon(Icons.phone, size: 16, color: colorScheme.primary),
                ),
              ),
            ],
          ),
        ),

        // Merchant card (food only)
        if (serviceType == 'food' && merchantName.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colorScheme.secondary.withValues(alpha: 0.22)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colorScheme.secondary.withValues(alpha: 0.24),
                  child: Icon(Icons.store, size: 18, color: colorScheme.onSecondaryContainer),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(merchantName,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSecondaryContainer),
                          overflow: TextOverflow.ellipsis),
                      if (merchantPhone.isNotEmpty)
                        Text(merchantPhone,
                            style: TextStyle(fontSize: 11, color: colorScheme.onSecondaryContainer.withValues(alpha: 0.8))),
                    ],
                  ),
                ),
                if (showMerchantCallButton && onCallMerchant != null)
                  InkWell(
                    onTap: onCallMerchant,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: colorScheme.tertiaryContainer, shape: BoxShape.circle),
                      child: Icon(Icons.phone, size: 16, color: colorScheme.tertiary),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
