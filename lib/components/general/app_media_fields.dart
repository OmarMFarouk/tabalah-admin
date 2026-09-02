import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../src/app_colors.dart';
import '../../src/sport_icons.dart';
import 'app_field.dart';

// ─────────────────────────────────────────────
//  ICON PICKER — اختيار أيقونة
//
//  A wrapping grid of every icon key the backend
//  accepts. Deliberately not a dropdown: an admin
//  picking a picture wants to see the pictures,
//  and forty rows of text in a menu is worse at
//  that than one glance at a grid.
// ─────────────────────────────────────────────
class IconPickerField extends StatelessWidget {
  const IconPickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'الأيقونة',
    this.keys,
  });

  /// The selected icon key, or null for "no icon".
  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;

  /// Defaults to the keys this build knows glyphs for. Passing the list the
  /// server sent lets the panel offer a newer catalogue than it shipped
  /// with — unknown keys still render, just with the fallback glyph.
  final List<String>? keys;

  @override
  Widget build(BuildContext context) {
    final options = keys ?? SportIcons.keys;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: GlobalColors.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GlobalColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.emoji_symbols_rounded,
                size: 16,
                color: GlobalColors.accentSoft,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: GlobalColors.textSecondary(context),
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              if (value != null)
                TextButton.icon(
                  onPressed: () => onChanged(null),
                  icon: const Icon(Icons.close_rounded, size: 14),
                  label: const Text(
                    'بدون أيقونة',
                    style: TextStyle(fontSize: 11),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: GlobalColors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Capped so a long catalogue scrolls inside the dialog instead of
          // pushing the save button off the bottom of the screen.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 168),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: options.map((key) {
                  final selected = key == value;

                  return Tooltip(
                    message: SportIcons.label(key),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onChanged(key),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: selected
                              ? GlobalColors.accent.withValues(alpha: 0.18)
                              : GlobalColors.bg(context),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected
                                ? GlobalColors.accent
                                : GlobalColors.border(context),
                            width: selected ? 1.6 : 1,
                          ),
                        ),
                        child: Icon(
                          SportIcons.of(key),
                          size: 20,
                          color: selected
                              ? GlobalColors.accent
                              : GlobalColors.textSecondary(context),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  IMAGE FIELD — صورة (رفع أو رابط)
//
//  Three ways to set a picture and one to clear
//  it, in one block: choose a file from disk,
//  paste a URL, or keep what is already there.
//  The preview is the point — an admin who can
//  see the current artwork does not have to open
//  the member app to check what they changed.
// ─────────────────────────────────────────────
class ImageField extends StatelessWidget {
  const ImageField({
    super.key,
    required this.urlController,
    required this.onPickFile,
    required this.onDropPicked,
    required this.onRemove,
    this.pickedPath,
    this.currentUrl,
    this.markedForRemoval = false,
    this.label = 'الصورة',
    this.hint = 'اختياري — تُعرض في التطبيق',
  });

  /// Bound to the "paste a URL" field.
  final TextEditingController urlController;

  /// A file chosen from disk but not uploaded yet.
  final String? pickedPath;

  /// The artwork the row already has, if any.
  final String? currentUrl;

  /// True once "remove" was pressed and before the form is saved.
  final bool markedForRemoval;

  final VoidCallback onPickFile;
  final VoidCallback onDropPicked;
  final VoidCallback onRemove;

  final String label;
  final String hint;

  bool get _hasCurrent => (currentUrl ?? '').isNotEmpty && !markedForRemoval;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GlobalColors.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GlobalColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.image_rounded,
                size: 16,
                color: GlobalColors.accentSoft,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: GlobalColors.textSecondary(context),
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hint,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: GlobalColors.textSecondary(
                      context,
                    ).withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _preview(context),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onPickFile,
                            icon: const Icon(Icons.upload_rounded, size: 16),
                            label: const Text(
                              'رفع صورة',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: GlobalColors.accent,
                              side: BorderSide(
                                color: GlobalColors.border(context),
                              ),
                            ),
                          ),
                        ),
                        if (pickedPath != null || _hasCurrent) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: pickedPath != null
                                  ? onDropPicked
                                  : onRemove,
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 16,
                              ),
                              label: Text(
                                pickedPath != null
                                    ? 'إلغاء الاختيار'
                                    : 'حذف الصورة',
                                style: const TextStyle(fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: GlobalColors.red,
                                side: BorderSide(
                                  color: GlobalColors.border(context),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    AppField(
                      controller: urlController,
                      label: 'أو رابط صورة',
                      icon: Icons.link_rounded,
                      hint: 'https://...',
                      // A URL and an uploaded file are mutually exclusive
                      // server-side, so the field goes quiet while a file is
                      // selected rather than letting the admin fill both in
                      // and meet a 422 on save.
                      enabled: pickedPath == null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (pickedPath != null) ...[
            const SizedBox(height: 8),
            Text(
              'سيتم رفع: ${_basename(pickedPath!)}',
              style: TextStyle(color: GlobalColors.green, fontSize: 11),
            ),
          ],
          if (markedForRemoval) ...[
            const SizedBox(height: 8),
            Text(
              'سيتم حذف الصورة عند الحفظ.',
              style: TextStyle(color: GlobalColors.red, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  static String _basename(String path) {
    final cut = path.lastIndexOf(RegExp(r'[\\/]'));
    return cut < 0 ? path : path.substring(cut + 1);
  }

  Widget _preview(BuildContext context) {
    Widget content;

    if (pickedPath != null) {
      // A freshly picked file is on disk, not on the server yet, so it is
      // read straight off the filesystem rather than through the network
      // image cache.
      content = Image.file(
        File(pickedPath!),
        fit: BoxFit.cover,
        width: 84,
        height: 84,
        errorBuilder: (_, __, ___) => Icon(
          Icons.broken_image_rounded,
          color: GlobalColors.textSecondary(context),
        ),
      );
    } else if (_hasCurrent) {
      content = CachedNetworkImage(
        imageUrl: currentUrl!,
        fit: BoxFit.cover,
        width: 84,
        height: 84,
        errorWidget: (_, __, ___) => Icon(
          Icons.broken_image_rounded,
          color: GlobalColors.textSecondary(context),
        ),
      );
    } else {
      content = Icon(
        Icons.image_outlined,
        color: GlobalColors.textSecondary(context).withValues(alpha: 0.5),
      );
    }

    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: GlobalColors.bg(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GlobalColors.border(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(child: content),
    );
  }
}

// ─────────────────────────────────────────────
//  SPORT BADGE — أيقونة/صورة الرياضة في الجداول
//
//  One tile that resolves the "photo if there is
//  one, glyph otherwise" rule, so every table and
//  dropdown that shows a sport agrees on it.
// ─────────────────────────────────────────────
class SportBadge extends StatelessWidget {
  const SportBadge({
    super.key,
    this.imageUrl,
    this.icon,
    this.size = 36,
    this.radius = 10,
  });

  final String? imageUrl;
  final String? icon;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final hasImage = (imageUrl ?? '').isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: GlobalColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: GlobalColors.border(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _glyph(),
            )
          : _glyph(),
    );
  }

  Widget _glyph() => Center(
    child: Icon(
      SportIcons.of(icon),
      size: size * 0.55,
      color: GlobalColors.accentSoft,
    ),
  );
}
