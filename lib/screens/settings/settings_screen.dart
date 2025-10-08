import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:property_manager_frontend/providers/theme_provider.dart';
import 'package:property_manager_frontend/theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colors = [
      AppTheme.primaryBlue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.redAccent,
    ];
    final fonts = ["Poppins", "Inter", "Roboto"];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const Text("Theme Mode", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            DropdownButton<ThemeMode>(
              value: themeProvider.themeMode,
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text("System Default")),
                DropdownMenuItem(value: ThemeMode.light, child: Text("Light Mode")),
                DropdownMenuItem(value: ThemeMode.dark, child: Text("Dark Mode")),
              ],
              onChanged: (value) => themeProvider.updateTheme(value!),
            ),
            const Divider(height: 30),
            const Text("Accent Color", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              children: colors.map((color) {
                return GestureDetector(
                  onTap: () => themeProvider.updateAccentColor(color),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: themeProvider.accentColor == color
                            ? Colors.black
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const Divider(height: 30),
            const Text("Font Style", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: themeProvider.fontFamily,
              items: fonts.map((font) {
                return DropdownMenuItem(value: font, child: Text(font));
              }).toList(),
              onChanged: (value) => themeProvider.updateFont(value!),
            ),
          ],
        ),
      ),
    );
  }
}
