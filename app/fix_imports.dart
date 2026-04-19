import 'dart:io';

final filesToRefactor = [
  r"c:\Data Athar\PROJECT\POS\app\lib\features\pos\presentation\pages\pos_page.dart",
  r"c:\Data Athar\PROJECT\POS\app\lib\features\inventory\presentation\pages\inventory_page.dart",
  r"c:\Data Athar\PROJECT\POS\app\lib\features\dashboard\presentation\pages\dashboard_page.dart",
  r"c:\Data Athar\PROJECT\POS\app\lib\features\accounting\presentation\pages\accounting_page.dart",
  r"c:\Data Athar\PROJECT\POS\app\lib\features\settings\presentation\pages\outlet_management_page.dart"
];

void main() async {
  for (final path in filesToRefactor) {
    final file = File(path);
    if (!await file.exists()) continue;

    var content = await file.readAsString();
    if (content.startsWith(r"$1import")) {
      content = content.replaceFirst(r"$1import", "import 'package:flutter/material.dart';\nimport");
      await file.writeAsString(content);
      print("Fixed $path");
    } else if (!content.contains("import 'package:flutter/material.dart';")) {
      content = "import 'package:flutter/material.dart';\n$content";
      await file.writeAsString(content);
      print("Added to $path");
    }
  }
}
