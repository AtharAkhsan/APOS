import 'dart:io';

final filesToRefactor = [
  r"c:\Data Athar\PROJECT\POS\app\lib\features\settings\presentation\pages\settings_page.dart",
  r"c:\Data Athar\PROJECT\POS\app\lib\features\settings\presentation\pages\outlet_management_page.dart",
  r"c:\Data Athar\PROJECT\POS\app\lib\features\pos\presentation\pages\pos_page.dart",
  r"c:\Data Athar\PROJECT\POS\app\lib\features\inventory\presentation\pages\inventory_page.dart",
  r"c:\Data Athar\PROJECT\POS\app\lib\features\dashboard\presentation\pages\dashboard_page.dart",
  r"c:\Data Athar\PROJECT\POS\app\lib\features\accounting\presentation\pages\accounting_page.dart",
  r"c:\Data Athar\PROJECT\POS\app\lib\features\accounting\presentation\widgets\expense_dialog.dart"
];

void main() async {
  for (final path in filesToRefactor) {
    final file = File(path);
    if (!await file.exists()) continue;

    var content = await file.readAsString();

    // Replace gradient: LinearGradient(colors: [...]) inside BoxDecoration with color: context.theme.colorScheme.primary
    // But wait, the exact string is usually:
    // gradient: LinearGradient(
    //   colors: [context.theme.colorScheme.primary, context.theme.colorScheme.primaryContainer],
    // )

    final RegExp regex = RegExp(
      r'gradient:\s*(const\s*)?LinearGradient\(\s*colors:\s*\[([^\]]+)\][^)]*\),',
      multiLine: true,
    );
    
    // We don't want to replace FlChart gradients, which might include withOpacity calls
    var changed = false;
    content = content.replaceAllMapped(regex, (match) {
      final code = match.group(0)!;
      final colors = match.group(2)!;
      if (colors.contains('withOpacity') || colors.contains('transparent')) {
         return code; // Keep chart gradients
      }
      changed = true;
      return 'color: context.theme.colorScheme.primary,';
    });

    if (changed) {
      // Also need to remove the transparent background overrides from the buttons inside
      content = content.replaceAll(r'backgroundColor: Colors.transparent,', '');
      content = content.replaceAll(r'shadowColor: Colors.transparent,', '');
      
      await file.writeAsString(content);
      print("Stripped gradients from $path");
    }
  }
}
