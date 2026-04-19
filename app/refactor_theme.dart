import 'dart:io';

final filesToRefactor = [
  r"c:\Data Athar\PROJECT\POS\app\lib\features\accounting\presentation\widgets\expense_dialog.dart"
];

final colorMap = {
  "_kPrimaryContainer": "context.theme.colorScheme.primaryContainer",
  "_kOnPrimaryContainer": "context.theme.colorScheme.onPrimaryContainer",
  "_kOnPrimary": "context.theme.colorScheme.onPrimary",
  "_kPrimary": "context.theme.colorScheme.primary",
  "_kSecondaryContainer": "context.theme.colorScheme.secondaryContainer",
  "_kOnSecondaryContainer": "context.theme.colorScheme.onSecondaryContainer",
  "_kOnSecondary": "context.theme.colorScheme.onSecondary",
  "_kSecondary": "context.theme.colorScheme.secondary",
  "_kTertiaryFixedDim": "context.theme.tertiaryFixedDim",
  "_kOnTertiaryFixed": "context.theme.onTertiaryFixed",
  "_kTertiary": "context.theme.colorScheme.tertiary",
  "_kErrorContainer": "context.theme.colorScheme.errorContainer",
  "_kError": "context.theme.colorScheme.error",
  "_kBackground": "context.theme.scaffoldBackgroundColor",
  "_kSurfaceHighest": "context.theme.surfaceHighest",
  "_kSurfaceLow": "context.theme.surfaceLow",
  "_kSurfaceDim": "context.theme.surfaceDim",
  "_kOnSurfaceVariant": "context.theme.colorScheme.onSurfaceVariant",
  "_kOnSurface": "context.theme.colorScheme.onSurface",
  "_kSurface": "context.theme.colorScheme.surface",
  "_kCardWhite": "context.theme.cardWhite",
  "_kOutlineVariant": "context.theme.outlineVariantCustom"
};

void main() async {
  for (final path in filesToRefactor) {
    final file = File(path);
    if (!await file.exists()) continue;

    var content = await file.readAsString();

    if (!content.contains("package:apos/core/theme/app_theme.dart")) {
      content = "import 'package:apos/core/theme/app_theme.dart';\n$content";
    }

    content = content.replaceAll(RegExp(r'const\s+_k[A-Za-z0-9_]+\s*=\s*Color\([^)]+\);\s*\n'), "");
    content = content.replaceAll(RegExp(r'\bstatic\s+const\s+_k[A-Za-z0-9_]+\s*=\s*Color\([^)]+\);\s*\n'), "");
    content = content.replaceAll(RegExp(r'\bconst\s+'), "");

    colorMap.forEach((old, newColor) {
      content = content.replaceAll(RegExp('\\b$old\\b'), newColor);
    });

    await file.writeAsString(content);
    print("Processed $path");
  }
}
