import os
import re

FILES_TO_REFACTOR = [
    r"c:\Data Athar\PROJECT\POS\app\lib\features\pos\presentation\pages\pos_page.dart",
    r"c:\Data Athar\PROJECT\POS\app\lib\features\inventory\presentation\pages\inventory_page.dart",
    r"c:\Data Athar\PROJECT\POS\app\lib\features\dashboard\presentation\pages\dashboard_page.dart",
    r"c:\Data Athar\PROJECT\POS\app\lib\features\accounting\presentation\pages\accounting_page.dart",
    r"c:\Data Athar\PROJECT\POS\app\lib\features\settings\presentation\pages\settings_page.dart",
    r"c:\Data Athar\PROJECT\POS\app\lib\features\settings\presentation\pages\outlet_management_page.dart"
]

COLOR_MAP = {
    "_kPrimary": "context.theme.colorScheme.primary",
    "_kPrimaryContainer": "context.theme.colorScheme.primaryContainer",
    "_kOnPrimary": "context.theme.colorScheme.onPrimary",
    "_kSecondary": "context.theme.colorScheme.secondary",
    "_kSecondaryContainer": "context.theme.colorScheme.secondaryContainer",
    "_kOnSecondaryContainer": "context.theme.colorScheme.onSecondaryContainer",
    "_kTertiary": "context.theme.colorScheme.tertiary",
    "_kTertiaryFixedDim": "context.theme.tertiaryFixedDim",
    "_kOnTertiaryFixed": "context.theme.onTertiaryFixed",
    "_kError": "context.theme.colorScheme.error",
    "_kErrorContainer": "context.theme.colorScheme.errorContainer",
    "_kBackground": "context.theme.scaffoldBackgroundColor",
    "_kSurface": "context.theme.colorScheme.surface",
    "_kOnSurface": "context.theme.colorScheme.onSurface",
    "_kOnSurfaceVariant": "context.theme.colorScheme.onSurfaceVariant",
    "_kSurfaceHighest": "context.theme.surfaceHighest",
    "_kSurfaceLow": "context.theme.surfaceLow",
    "_kSurfaceDim": "context.theme.surfaceDim",
    "_kCardWhite": "context.theme.cardWhite",
    "_kOutlineVariant": "context.theme.outlineVariantCustom"
}

def refactor_file(file_path):
    if not os.path.exists(file_path):
        print(f"File not found: {file_path}")
        return

    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Determine relative depth and import app_theme
    # All these files are under lib/features/... Wait, pos_page is deeply nested?
    # Actually, we can just use an absolute package import
    import_statement = "import 'package:apos/core/theme/app_theme.dart';\n"
    if "import 'package:apos/core/theme/app_theme.dart';" not in content:
        # replace the first import
        content = re.sub(r"(import .*?\n)", r"\1" + import_statement, content, count=1)

    # Remove the const _k definitions
    content = re.sub(r'const\s+_k[A-Za-z0-9_]+\s*=\s*Color\([^)]+\);\s*\n', '', content)

    # Strip ALL instances of "const " as a standalone keyword in widget trees!
    # "const " inside strings might be affected, but unlikely.
    # We omit replacing 'const ' if it's "const [" or "const {"
    content = re.sub(r'\bconst\s+', '', content)
    
    # Wait, stripping all const will remove 'const String', 'const int' - those are fine to lose temporarily.
    # dart fix --apply will add const back to widgets! Wait, dart fix only adds const to constructor invocations.
    # It might NOT add 'const' to local variables like `const padding = EdgeInsets.all(8);`
    # That just becomes a normal variable/final, which compiles fine!

    # Finally map the color keys
    for old, new_ in COLOR_MAP.items():
        # Match _kPrimary exactly as a whole word
        content = re.sub(r'\b' + old + r'\b', new_, content)

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

for path in FILES_TO_REFACTOR:
    refactor_file(path)
print("Done parsing.")
