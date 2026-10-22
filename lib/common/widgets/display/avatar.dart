import 'package:flutter/material.dart';

import '../../../theme/ts.dart';
import '../action/button.dart';

enum CommonAvatarTone { primary, secondary }

class CommonAvatar extends StatelessWidget {
  const CommonAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = CommonControlSize.md,
    this.tone = CommonAvatarTone.primary,
  });

  final String name;
  final String? imageUrl;
  final CommonControlSize size;
  final CommonAvatarTone tone;

  double _diameter(TS ts) => switch (size) {
    CommonControlSize.sm => ts.sizing.avatarSm,
    CommonControlSize.md => ts.sizing.avatarMd,
    CommonControlSize.lg => ts.sizing.avatarLg,
  };

  String get _initials {
    final normalized = name.trim();
    if (normalized.isEmpty) return '?';
    final parts = normalized.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final primary = tone == CommonAvatarTone.primary;
    return CircleAvatar(
      radius: _diameter(ts) / 2,
      backgroundColor: primary ? ts.colors.primary : ts.colors.secondary,
      foregroundImage: imageUrl == null ? null : NetworkImage(imageUrl!),
      onForegroundImageError: imageUrl == null ? null : (_, _) {},
      child: Text(
        _initials,
        style: ts.textStyle.label.copyWith(
          color: primary ? ts.colors.onPrimary : ts.colors.onSecondary,
        ),
      ),
    );
  }
}
