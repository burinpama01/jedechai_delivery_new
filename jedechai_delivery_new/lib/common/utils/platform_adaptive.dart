import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Helpers for platform-specific UI behavior.
///
/// Centralizing these branches keeps Android/iOS differences predictable.
class PlatformAdaptive {
  PlatformAdaptive._();

  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static IconData icon({required IconData android, IconData? ios}) {
    return isIOS ? (ios ?? android) : android;
  }

  static Future<DateTime?> pickDate({
    required BuildContext context,
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    Locale? locale,
    String? title,
  }) async {
    final clampedInitial = _clampDate(initialDate, firstDate, lastDate);

    if (!isIOS) {
      return showDatePicker(
        context: context,
        initialDate: clampedInitial,
        firstDate: firstDate,
        lastDate: lastDate,
        locale: locale,
      );
    }

    DateTime selectedDate = clampedInitial;

    return showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (sheetContext) {
        return _buildCupertinoSheet(
          context: sheetContext,
          title: title,
          onCancel: () => Navigator.of(sheetContext).pop(),
          onConfirm: () {
            Navigator.of(sheetContext).pop(
              DateTime(
                selectedDate.year,
                selectedDate.month,
                selectedDate.day,
              ),
            );
          },
          picker: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.date,
            initialDateTime: clampedInitial,
            minimumDate: firstDate,
            maximumDate: lastDate,
            onDateTimeChanged: (value) {
              selectedDate = value;
            },
          ),
        );
      },
    );
  }

  static Future<TimeOfDay?> pickTime({
    required BuildContext context,
    required TimeOfDay initialTime,
    bool alwaysUse24HourFormat = true,
    String? title,
  }) async {
    if (!isIOS) {
      return showTimePicker(
        context: context,
        initialTime: initialTime,
        builder: alwaysUse24HourFormat
            ? (pickerContext, child) => MediaQuery(
                  data: MediaQuery.of(pickerContext)
                      .copyWith(alwaysUse24HourFormat: true),
                  child: child!,
                )
            : null,
      );
    }

    final now = DateTime.now();
    DateTime selected = DateTime(
      now.year,
      now.month,
      now.day,
      initialTime.hour,
      initialTime.minute,
    );

    final picked = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (sheetContext) {
        return _buildCupertinoSheet(
          context: sheetContext,
          title: title,
          onCancel: () => Navigator.of(sheetContext).pop(),
          onConfirm: () => Navigator.of(sheetContext).pop(selected),
          picker: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.time,
            use24hFormat: alwaysUse24HourFormat,
            initialDateTime: selected,
            onDateTimeChanged: (value) {
              selected = value;
            },
          ),
        );
      },
    );

    if (picked == null) return null;
    return TimeOfDay.fromDateTime(picked);
  }

  static DateTime _clampDate(
    DateTime value,
    DateTime firstDate,
    DateTime lastDate,
  ) {
    if (value.isBefore(firstDate)) return firstDate;
    if (value.isAfter(lastDate)) return lastDate;
    return value;
  }

  static Widget _buildCupertinoSheet({
    required BuildContext context,
    required VoidCallback onCancel,
    required VoidCallback onConfirm,
    required Widget picker,
    String? title,
  }) {
    return Container(
      height: 320,
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    onPressed: onCancel,
                    child: const Text('ยกเลิก'),
                  ),
                  if (title != null)
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    onPressed: onConfirm,
                    child: const Text('ตกลง'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: picker),
          ],
        ),
      ),
    );
  }
}
