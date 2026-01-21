import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/printer_settings_service.dart';
import '../../services/thermal_printer/thermal_printing_service.dart';

/// 🖨️ Detailed Printer Settings Screen
/// 
/// Features:
/// - Display current printer configuration
/// - Edit all printer settings
/// - Test printer connection
/// - Save/clear settings
/// - Real-time validation
class PrinterSettingsScreen extends StatefulWidget {
  final ThermalPrintingService? thermalPrinting;
  
  const PrinterSettingsScreen({
    super.key,
    this.thermalPrinting,
  });

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final PrinterSettingsService _settingsService = PrinterSettingsService();
  
  late TextEditingController _addressController;
  late TextEditingController _portController;
  late TextEditingController _timeoutController;
  late TextEditingController _nameController;
  
  int _selectedDensity = 1;
  int _selectedPaperWidth = 80;
  bool _autoPrintTest = false;
  bool _enableLogging = true;
  bool _isLoading = true;
  bool _isTesting = false;
  
  String? _connectionStatus;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController();
    _portController = TextEditingController();
    _timeoutController = TextEditingController();
    _nameController = TextEditingController();
    
    _loadSettings();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _portController.dispose();
    _timeoutController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// Load current settings into form
  Future<void> _loadSettings() async {
    await _settingsService.initialize();
    
    final settings = await _settingsService.getAllSettings();
    
    setState(() {
      _addressController.text = settings['address'] ?? '';
      _portController.text = (settings['port'] ?? 9100).toString();
      _timeoutController.text = (settings['timeout'] ?? 5).toString();
      _nameController.text = settings['name'] ?? '';
      _selectedDensity = settings['density'] ?? 1;
      _selectedPaperWidth = settings['paperWidth'] ?? 80;
      _autoPrintTest = settings['autoPrintTest'] ?? false;
      _enableLogging = settings['enableLogging'] ?? true;
      _isLoading = false;
    });
  }

  /// Save all settings
  Future<void> _saveSettings() async {
    if (!_validateInputs()) {
      _showErrorSnackBar('Please fix the errors below');
      return;
    }

    try {
      final success = await _settingsService.saveAllSettings({
        'address': _addressController.text,
        'port': int.parse(_portController.text),
        'timeout': int.parse(_timeoutController.text),
        'name': _nameController.text,
        'density': _selectedDensity,
        'paperWidth': _selectedPaperWidth,
        'autoPrintTest': _autoPrintTest,
        'enableLogging': _enableLogging,
      });

      if (success) {
        _showSuccessSnackBar('✅ Printer settings saved successfully');
      } else {
        _showErrorSnackBar('Failed to save settings');
      }
    } catch (e) {
      _showErrorSnackBar('Error saving settings: $e');
    }
  }

  /// Test printer connection
  Future<void> _testConnection() async {
    if (!_validateInputs()) {
      _showErrorSnackBar('Please fix the errors before testing');
      return;
    }

    setState(() => _isTesting = true);
    
    try {
      final address = _addressController.text;
      final port = int.parse(_portController.text);

      final success = await widget.thermalPrinting?.connectPrinter(
        address,
        port: port,
        context: context,
      ) ?? false;

      setState(() {
        _connectionStatus = success 
          ? '✅ Connected successfully to $address:$port'
          : '❌ Failed to connect. Please check the IP address and port.';
      });

      if (success) {
        _showSuccessSnackBar('✅ Test successful! Printer is ready.');
      }
    } catch (e) {
      setState(() {
        _connectionStatus = '❌ Connection error: $e';
      });
      _showErrorSnackBar('Connection failed: $e');
    } finally {
      setState(() => _isTesting = false);
    }
  }

  /// Print test page
  Future<void> _printTest() async {
    if (!_validateInputs()) {
      _showErrorSnackBar('Printer not configured properly');
      return;
    }

    try {
      final success = await widget.thermalPrinting?.printTestPage(
        context: context,
      ) ?? false;

      if (success) {
        _showSuccessSnackBar('✅ Test page sent to printer');
      } else {
        _showErrorSnackBar('Failed to send test page');
      }
    } catch (e) {
      _showErrorSnackBar('Error printing test page: $e');
    }
  }

  /// Clear all settings
  Future<void> _clearAllSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Settings?'),
        content: const Text(
          'Are you sure you want to clear all printer settings? '
          'You will need to configure the printer again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      final success = await _settingsService.clearAllSettings();
      if (success) {
        await _loadSettings();
        _showSuccessSnackBar('✅ All settings cleared');
      }
    }
  }

  /// Validate all inputs
  bool _validateInputs() {
    if (_addressController.text.isEmpty) return false;
    if (_portController.text.isEmpty) return false;
    
    try {
      final port = int.parse(_portController.text);
      if (port < 1 || port > 65535) return false;
    } catch (e) {
      return false;
    }

    try {
      final timeout = int.parse(_timeoutController.text);
      if (timeout < 1 || timeout > 60) return false;
    } catch (e) {
      return false;
    }

    return true;
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Printer Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('🖨️ Printer Settings'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ═══════════════════════════════════════════════════════════
          // Current Status Card
          // ═══════════════════════════════════════════════════════════
          _buildStatusCard(),
          const SizedBox(height: 24),

          // ═══════════════════════════════════════════════════════════
          // Connection Settings Section
          // ═══════════════════════════════════════════════════════════
          _buildSectionHeader('📍 Connection Settings'),
          _buildAddressField(),
          const SizedBox(height: 12),
          _buildPortField(),
          const SizedBox(height: 12),
          _buildTimeoutField(),
          const SizedBox(height: 16),

          // ═══════════════════════════════════════════════════════════
          // Printer Configuration Section
          // ═══════════════════════════════════════════════════════════
          _buildSectionHeader('⚙️ Printer Configuration'),
          _buildNameField(),
          const SizedBox(height: 12),
          _buildDensitySelector(),
          const SizedBox(height: 12),
          _buildPaperWidthSelector(),
          const SizedBox(height: 16),

          // ═══════════════════════════════════════════════════════════
          // Options Section
          // ═══════════════════════════════════════════════════════════
          _buildSectionHeader('🔧 Options'),
          _buildToggleOption(
            'Auto Print Test',
            _autoPrintTest,
            (value) => setState(() => _autoPrintTest = value),
            'Automatically print test page after connection',
          ),
          const SizedBox(height: 8),
          _buildToggleOption(
            'Enable Logging',
            _enableLogging,
            (value) => setState(() => _enableLogging = value),
            'Log printer operations to console',
          ),
          const SizedBox(height: 24),

          // ═══════════════════════════════════════════════════════════
          // Action Buttons
          // ═══════════════════════════════════════════════════════════
          _buildActionButtons(),
          const SizedBox(height: 16),

          // ═══════════════════════════════════════════════════════════
          // Connection Status
          // ═══════════════════════════════════════════════════════════
          if (_connectionStatus != null) ...[
            Card(
              color: _connectionStatus!.startsWith('✅')
                  ? Colors.green[50]
                  : Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      _connectionStatus!.startsWith('✅')
                          ? Icons.check_circle
                          : Icons.error,
                      color: _connectionStatus!.startsWith('✅')
                          ? Colors.green
                          : Colors.red,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _connectionStatus!,
                        style: TextStyle(
                          color: _connectionStatus!.startsWith('✅')
                              ? Colors.green[800]
                              : Colors.red[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ═══════════════════════════════════════════════════════════
          // Quick Reference
          // ═══════════════════════════════════════════════════════════
          _buildQuickReference(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Current Configuration',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatusRow('Printer Name:', _nameController.text.isNotEmpty
                ? _nameController.text
                : 'Not configured'),
            _buildStatusRow('Address:', _addressController.text.isNotEmpty
                ? _addressController.text
                : 'Not configured'),
            _buildStatusRow('Port:', _portController.text.isNotEmpty
                ? _portController.text
                : 'Not configured'),
            _buildStatusRow('Print Density:', PrinterSettingsService.densityLevels[_selectedDensity] ?? 'Unknown'),
            _buildStatusRow('Paper Width:', '${_selectedPaperWidth}mm'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildAddressField() {
    return TextFormField(
      controller: _addressController,
      decoration: InputDecoration(
        labelText: 'Printer IP Address or Hostname',
        hintText: '192.168.1.100',
        prefixIcon: const Icon(Icons.language),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        errorText: _addressController.text.isEmpty ? 'Required' : null,
      ),
      onChanged: (value) => setState(() {}),
    );
  }

  Widget _buildPortField() {
    return TextFormField(
      controller: _portController,
      decoration: InputDecoration(
        labelText: 'Printer Port',
        hintText: '9100',
        prefixIcon: const Icon(Icons.pin),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        helperText: 'Usually 9100 for network printers',
        errorText: _portController.text.isEmpty
            ? 'Required'
            : (int.tryParse(_portController.text) ?? -1) < 1 ||
                    (int.tryParse(_portController.text) ?? -1) > 65535
                ? 'Must be between 1 and 65535'
                : null,
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (value) => setState(() {}),
    );
  }

  Widget _buildTimeoutField() {
    return TextFormField(
      controller: _timeoutController,
      decoration: InputDecoration(
        labelText: 'Connection Timeout (seconds)',
        hintText: '5',
        prefixIcon: const Icon(Icons.timer),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        helperText: 'How long to wait for printer response (1-60 seconds)',
        errorText: _timeoutController.text.isEmpty
            ? 'Required'
            : (int.tryParse(_timeoutController.text) ?? -1) < 1 ||
                    (int.tryParse(_timeoutController.text) ?? -1) > 60
                ? 'Must be between 1 and 60'
                : null,
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (value) => setState(() {}),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: 'Printer Name (Optional)',
        hintText: 'e.g., Main Floor Printer',
        prefixIcon: const Icon(Icons.label),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        helperText: 'A friendly name to identify this printer',
      ),
      onChanged: (value) => setState(() {}),
    );
  }

  Widget _buildDensitySelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Print Density',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: PrinterSettingsService.densityLevels.entries.map((e) {
                return ChoiceChip(
                  label: Text(e.value),
                  selected: _selectedDensity == e.key,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedDensity = e.key);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            const Text(
              'Light = faster, Normal = balanced, Dark = better quality',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaperWidthSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paper Width',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: PrinterSettingsService.paperWidths.map((width) {
                return ChoiceChip(
                  label: Text('${width}mm'),
                  selected: _selectedPaperWidth == width,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedPaperWidth = width);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            const Text(
              'Common sizes: 58mm (small), 80mm (standard), 100mm (wide)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleOption(
    String label,
    bool value,
    Function(bool) onChanged,
    String description,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Switch(
                  value: value,
                  onChanged: onChanged,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      spacing: 10,
      children: [
        // Save and Test Row
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save),
                label: const Text('Save Settings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isTesting ? null : _testConnection,
                icon: _isTesting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.wifi),
                label: const Text('Test Connection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),

        // Print Test Row
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _printTest,
                icon: const Icon(Icons.print),
                label: const Text('Print Test Page'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _clearAllSettings,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Clear Settings'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickReference() {
    return Card(
      color: Colors.amber[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.help, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Quick Reference',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildReferenceItem(
              '📍 How to find printer IP:',
              'Check your printer\'s display screen or network settings.',
            ),
            _buildReferenceItem(
              '🔌 Default Port:',
              'Most thermal printers use port 9100.',
            ),
            _buildReferenceItem(
              '🖨️ Supported Printers:',
              'Works with ESC/POS compatible thermal printers (80mm width).',
            ),
            _buildReferenceItem(
              '⏱️ Timeout:',
              'If printer is slow, increase timeout value.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferenceItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Text(
            description,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
