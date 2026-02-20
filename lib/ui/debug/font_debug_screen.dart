import 'package:flutter/material.dart';
import '../../services/invoice_settings_service.dart';

class FontDebugScreen extends StatefulWidget {
  const FontDebugScreen({super.key});

  @override
  State<FontDebugScreen> createState() => _FontDebugScreenState();
}

class _FontDebugScreenState extends State<FontDebugScreen> {
  String testText = 'میاں ٹریڈرز (Mian Traders)';
  String noonGhunna = 'ں';
  String combination = 'میاں';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Font & Noon Ghunna Debug')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This screen tests how Noon Ghunna (ں) renders in the Flutter UI using different fonts.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Divider(),

            _buildTestSection('System Default', const TextStyle(fontSize: 24)),
            _buildTestSection(
              'Noto Sans Arabic (Safe Font)',
              const TextStyle(fontFamily: 'UrduFont', fontSize: 24),
            ),
            _buildTestSection(
              'Jameel Noori Nastaliq',
              const TextStyle(fontFamily: 'JameelNoori', fontSize: 32),
            ),
            _buildTestSection(
              'Lalezar',
              const TextStyle(fontFamily: 'Lalezar', fontSize: 24),
            ),

            const SizedBox(height: 20),
            const Text(
              'Custom Settings Font:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            FutureBuilder(
              future: InvoiceSettingsService().getSettings(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final settings = snapshot.data!;
                return _buildTestSection(
                  'Current Business Font: ${settings.bodyFontFamily}',
                  TextStyle(fontFamily: settings.bodyFontFamily, fontSize: 24),
                );
              },
            ),

            const Divider(),
            const Text(
              'Manual Character Test:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Raw Noon Ghunna: $noonGhunna',
              style: const TextStyle(fontSize: 40),
            ),
            Text(
              'Word "Mian": $combination',
              style: const TextStyle(fontSize: 40),
            ),

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestSection(String title, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue.shade100),
              borderRadius: BorderRadius.circular(8),
              color: Colors.blue.shade50.withOpacity(0.3),
            ),
            child: Text(testText, style: style, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
