import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../src/app_colors.dart';
import '../../src/app_presets.dart';

// ─────────────────────────────────────────────
//  APP FIELD — حقل نصي
// ─────────────────────────────────────────────
class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.isNumber = false,
    this.isObscure = false,
    this.maxLines = 1,
    this.hint,
    this.suffix,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isNumber;
  final bool isObscure;
  final int maxLines;
  final String? hint;
  final Widget? suffix;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: isObscure,
      maxLines: isObscure ? 1 : maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumber
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
          : null,
      style: TextStyle(color: GlobalColors.textPrimary(context), fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: GlobalColors.surface(context),
        hintStyle: TextStyle(
          color: GlobalColors.textSecondary(context).withValues(alpha: 0.6),
          fontSize: 12,
        ),
        labelStyle: TextStyle(
          color: GlobalColors.textSecondary(context),
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: GlobalColors.accentSoft, size: 18),
        suffixIcon: suffix,
        border: _border(context),
        enabledBorder: _border(context),
        disabledBorder: _border(context),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: GlobalColors.accent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }

  OutlineInputBorder _border(BuildContext context) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: GlobalColors.border(context)),
  );
}

// ─────────────────────────────────────────────
//  APP DROPDOWN — قائمة منسدلة
// ─────────────────────────────────────────────
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
    required this.label,
    required this.icon,
    this.emptyLabel,
  });

  final T? value;
  final List<T> items;
  final String Function(T) labelOf;
  final void Function(T?) onChanged;
  final String label;
  final IconData icon;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    // Two separate ways this widget can trip Flutter's
    // "exactly one item with this value" assertion, so guard both.
    //
    //  1. Duplicates. Callers merge lookup lists (staff + trainers, say) and
    //     an account present in both yields two items with equal values.
    //  2. A value that no longer matches anything, once a caller rebuilds
    //     its item list from scratch each frame.
    final unique = <T>[];
    for (final item in items) {
      if (!unique.contains(item)) unique.add(item);
    }
    final safe = unique.contains(value) ? value : null;

    return DropdownButtonFormField<T>(
      // Keyed on the resolved value so the field is driven by the parent
      // rather than holding a stale selection of its own. Without this the
      // form keeps the instance it was given first, and a rebuilt item list
      // leaves it pointing at something that is no longer there.
      key: ValueKey(safe == null ? null : labelOf(safe)),
      value: safe,
      isExpanded: true,
      dropdownColor: GlobalColors.card(context),
      borderRadius: BorderRadius.circular(12),
      icon: Icon(
        Icons.expand_more_rounded,
        color: GlobalColors.textSecondary(context),
        size: 20,
      ),
      style: TextStyle(color: GlobalColors.textPrimary(context), fontSize: 13),
      hint: Text(
        emptyLabel ?? 'اختر...',
        style: TextStyle(
          color: GlobalColors.textSecondary(context).withValues(alpha: 0.7),
          fontSize: 13,
        ),
      ),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: GlobalColors.surface(context),
        labelStyle: TextStyle(
          color: GlobalColors.textSecondary(context),
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: GlobalColors.accentSoft, size: 18),
        border: _border(context),
        enabledBorder: _border(context),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: GlobalColors.accent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
      ),
      items: unique
          .map(
            (e) => DropdownMenuItem<T>(
              value: e,
              child: Text(labelOf(e), overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  OutlineInputBorder _border(BuildContext context) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: GlobalColors.border(context)),
  );
}

// ─────────────────────────────────────────────
//  SEARCH FIELD — حقل البحث
// ─────────────────────────────────────────────
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = 'ابحث بالاسم...',
  });

  final TextEditingController controller;
  final void Function(String) onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: GlobalColors.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GlobalColors.border(context)),
      ),
      child: TextField(
        controller: controller,
        onSubmitted: onChanged,
        onChanged: (v) {
          if (v.isEmpty) onChanged(v);
        },
        style: TextStyle(
          color: GlobalColors.textPrimary(context),
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: GlobalColors.textSecondary(context).withValues(alpha: 0.7),
            fontSize: 13,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: GlobalColors.textSecondary(context),
            size: 20,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    color: GlobalColors.textSecondary(context),
                    size: 18,
                  ),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  DATE PICKER FIELD — اختيار التاريخ
// ─────────────────────────────────────────────
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.value,
    required this.onPicked,
    required this.label,
    this.firstDate,
  });

  final String? value;
  final void Function(String) onPicked;
  final String label;
  final DateTime? firstDate;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.tryParse(value ?? '') ?? now,
          firstDate: firstDate ?? DateTime(now.year - 3),
          lastDate: DateTime(now.year + 3),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: ColorScheme.dark(
                primary: GlobalColors.accent,
                surface: GlobalColors.card(context),
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) onPicked(AppPresets.date(picked));
      },
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: GlobalColors.surface(context),
          labelStyle: TextStyle(
            color: GlobalColors.textSecondary(context),
            fontSize: 13,
          ),
          prefixIcon: Icon(
            Icons.calendar_today_rounded,
            color: GlobalColors.accentSoft,
            size: 17,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: GlobalColors.border(context)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: GlobalColors.border(context)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
        child: Text(
          value ?? 'اختر التاريخ',
          style: TextStyle(
            color: value == null
                ? GlobalColors.textSecondary(context)
                : GlobalColors.textPrimary(context),
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  TIME PICKER FIELD — اختيار الوقت
// ─────────────────────────────────────────────
class TimeField extends StatelessWidget {
  const TimeField({
    super.key,
    required this.value,
    required this.onPicked,
    required this.label,
  });

  final TimeOfDay value;
  final void Function(TimeOfDay) onPicked;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: value,
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: ColorScheme.dark(
                primary: GlobalColors.accent,
                surface: GlobalColors.card(context),
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) onPicked(picked);
      },
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: GlobalColors.surface(context),
          labelStyle: TextStyle(
            color: GlobalColors.textSecondary(context),
            fontSize: 13,
          ),
          prefixIcon: Icon(
            Icons.schedule_rounded,
            color: GlobalColors.accentSoft,
            size: 17,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: GlobalColors.border(context)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: GlobalColors.border(context)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
        child: Text(
          AppPresets.time(value),
          style: TextStyle(
            color: GlobalColors.textPrimary(context),
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SWITCH TILE — مفتاح تبديل
// ─────────────────────────────────────────────
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.hint,
  });

  final bool value;
  final void Function(bool) onChanged;
  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: GlobalColors.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GlobalColors.border(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: GlobalColors.textPrimary(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hint != null)
                  Text(
                    hint!,
                    style: TextStyle(
                      color: GlobalColors.textSecondary(context),
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: GlobalColors.accent,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  FILTER CHIP — شريحة فلتر
// ─────────────────────────────────────────────
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: FilterChip(
        label: Text(label),
        selected: isActive,
        onSelected: (_) => onTap(),
        backgroundColor: GlobalColors.surface(context),
        selectedColor: GlobalColors.accent.withValues(alpha: 0.18),
        checkmarkColor: GlobalColors.accentSoft,
        labelStyle: TextStyle(
          color: isActive
              ? GlobalColors.accentSoft
              : GlobalColors.textSecondary(context),
          fontSize: 12,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
        ),
        side: BorderSide(
          color: isActive ? GlobalColors.accent : GlobalColors.border(context),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  TOOLBAR — شريط الأدوات
// ─────────────────────────────────────────────
class Toolbar extends StatelessWidget {
  const Toolbar({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
      child: Row(children: children),
    );
  }
}
