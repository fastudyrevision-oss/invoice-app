import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/invoice_settings.dart';
import '../../services/invoice_settings_service.dart';
import '../debug/font_debug_screen.dart';

class InvoiceCustomizationScreen extends StatefulWidget {
  const InvoiceCustomizationScreen({super.key});

  @override
  State<InvoiceCustomizationScreen> createState() =>
      _InvoiceCustomizationScreenState();
}

class _InvoiceCustomizationScreenState
    extends State<InvoiceCustomizationScreen> {
  final InvoiceSettingsService _settingsService = InvoiceSettingsService();
  late InvoiceSettings _settings;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _showThermalPreview = false;

  // Controllers for text fields
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _instagramController = TextEditingController();
  final _facebookController = TextEditingController();
  final _footerController = TextEditingController();
  final _invoiceLabelController = TextEditingController();
  final _currencyController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountTitleController = TextEditingController();
  final _termsController = TextEditingController();
  final _signatureLabelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Clear cache to force migration of old settings format
    _settingsService.clearCache();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsService.getSettings();
    setState(() {
      _settings = settings;
      _nameController.text = settings.businessName;
      _addressController.text = settings.address;
      _phoneController.text = settings.phone;
      _emailController.text = settings.email;
      _websiteController.text = settings.website;
      _taxIdController.text = settings.taxId;
      _whatsappController.text = settings.whatsapp;
      _instagramController.text = settings.instagram;
      _facebookController.text = settings.facebook;
      _footerController.text = settings.footerText;
      _invoiceLabelController.text = settings.invoiceLabel;
      _currencyController.text = settings.currencySymbol;
      _bankNameController.text = settings.bankName;
      _accountNumberController.text = settings.accountNumber;
      _accountTitleController.text = settings.accountTitle;
      _termsController.text = settings.termsAndConditions;
      _signatureLabelController.text = settings.signatureLabel;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    final updatedSettings = _settings.copyWith(
      businessName: _nameController.text,
      address: _addressController.text,
      phone: _phoneController.text,
      email: _emailController.text,
      website: _websiteController.text,
      taxId: _taxIdController.text,
      whatsapp: _whatsappController.text,
      instagram: _instagramController.text,
      facebook: _facebookController.text,
      footerText: _footerController.text,
      invoiceLabel: _invoiceLabelController.text,
      currencySymbol: _currencyController.text,
      bankName: _bankNameController.text,
      accountNumber: _accountNumberController.text,
      accountTitle: _accountTitleController.text,
      termsAndConditions: _termsController.text,
      signatureLabel: _signatureLabelController.text,
    );

    final success = await _settingsService.saveSettings(updatedSettings);
    setState(() {
      _settings = updatedSettings;
      _isSaving = false;
    });

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _pickFont(String type) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ttf'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      String? savedPath = await _settingsService.saveCustomFont(file);
      if (savedPath != null) {
        setState(() {
          switch (type) {
            case 'header':
              _settings = _settings.copyWith(headerFontPath: savedPath);
              break;
            case 'body':
              _settings = _settings.copyWith(bodyFontPath: savedPath);
              break;
            case 'table':
              _settings = _settings.copyWith(tableFontPath: savedPath);
              break;
            case 'footer':
              _settings = _settings.copyWith(footerFontPath: savedPath);
              break;
          }
        });
      }
    }
  }

  Future<void> _pickLogo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      String? savedPath = await _settingsService.saveCustomLogo(file);
      if (savedPath != null) {
        setState(() {
          _settings = _settings.copyWith(logoPath: savedPath);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Invoice Designer'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Basic Info', icon: Icon(Icons.business)),
              Tab(text: 'Fonts', icon: Icon(Icons.font_download)),
              Tab(text: 'Logo & Design', icon: Icon(Icons.palette)),
              Tab(text: 'Extra Fields', icon: Icon(Icons.add_box)),
              Tab(text: 'Contact & Labels', icon: Icon(Icons.contact_mail)),
            ],
          ),
          actions: [
            if (_isSaving)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _saveSettings,
              ),
          ],
        ),
        body: Column(
          children: [
            // Live Preview Section
            Expanded(
              flex: 1,
              child: Container(
                color: Colors.grey[200],
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('Standard (A4)'),
                          icon: Icon(Icons.description),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('Thermal (80mm)'),
                          icon: Icon(Icons.receipt),
                        ),
                      ],
                      selected: {_showThermalPreview},
                      onSelectionChanged: (Set<bool> sel) {
                        if (sel.isNotEmpty) {
                          setState(() => _showThermalPreview = sel.first);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Expanded(child: _buildLivePreview()),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            // Scrollable Form Sections
            Expanded(
              flex: 2,
              child: TabBarView(
                children: [
                  _buildBasicInfoTab(),
                  _buildFontsTab(),
                  _buildDesignTab(),
                  _buildExtraFieldsTab(),
                  _buildContactLabelsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLivePreview() {
    if (_showThermalPreview) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: _buildThermalPreview(),
        ),
      );
    }

    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(12),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Directionality(
          textDirection: _settings.language == 'ur'
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row (Logo + Business Name)
                Row(
                  mainAxisAlignment: _getLogoAlignment(),
                  children: [
                    if (_settings.showLogo &&
                        _settings.logoPath != null &&
                        (_settings.logoPosition == 'top-left' ||
                            _settings.logoPosition == 'center'))
                      _buildLogoPreview(),
                    Expanded(
                      child: Directionality(
                        textDirection: _settings.headerLanguage == 'ur'
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                        child: Column(
                          crossAxisAlignment: _getContentAlignment(),
                          children: [
                            Text(
                              _nameController.text.isEmpty
                                  ? 'BUSINESS NAME'
                                  : _nameController.text,
                              style: TextStyle(
                                fontSize: _settings.headerFontSize,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _addressController.text,
                              style: TextStyle(
                                fontSize: _settings.bodyFontSize,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_settings.showLogo &&
                        _settings.logoPath != null &&
                        _settings.logoPosition == 'top-right')
                      _buildLogoPreview(),
                  ],
                ),
                const SizedBox(height: 10),
                if (_settings.showLogo &&
                    _settings.logoPath != null &&
                    _settings.logoPosition == 'center')
                  const SizedBox.shrink(), // Center handled in row above usually or specialized layout

                const Divider(),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_invoiceLabelController.text}: #1234',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Date: 2026-02-04'),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  height: 40,
                  width: double.infinity,
                  color: Colors.grey[100],
                  child: const Center(
                    child: Text(
                      '--- ITEM LIST PREVIEW ---',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Total: ${_currencyController.text} 1,234.56',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const Divider(),
                Center(
                  child: Directionality(
                    textDirection: _settings.footerLanguage == 'ur'
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    child: Text(
                      _footerController.text,
                      style: TextStyle(
                        fontSize: _settings.footerFontSize,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Dynamic Extra Fields Preview
                ..._settings.extraFields
                    .where((f) => f.isVisible)
                    .map(
                      (field) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${field.label}:',
                              style: TextStyle(
                                fontSize: field.fontSize,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              field.value,
                              style: TextStyle(fontSize: field.fontSize),
                            ),
                          ],
                        ),
                      ),
                    ),
                if (_bankNameController.text.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Bank Details:',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  Text(
                    'Bank: ${_bankNameController.text}\nAcc: ${_accountNumberController.text}\nTitle: ${_accountTitleController.text}',
                    style: const TextStyle(fontSize: 8),
                  ),
                ],
                if (_termsController.text.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Terms & Conditions:',
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _termsController.text,
                    style: const TextStyle(fontSize: 8),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 100,
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.black),
                            ),
                          ),
                        ),
                        Text(
                          _signatureLabelController.text,
                          style: const TextStyle(fontSize: 8),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThermalPreview() {
    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(8),
        color: Colors.white,
        child: Directionality(
          textDirection: _settings.language == 'ur'
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (_settings.showLogo)
                  Container(
                    height: 40,
                    width: 40,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: _settings.logoPath != null
                        ? Image.file(
                            File(_settings.logoPath!),
                            fit: BoxFit.contain,
                          )
                        : const Icon(
                            Icons.business,
                            size: 20,
                            color: Colors.grey,
                          ),
                  ),
                Directionality(
                  textDirection: _settings.headerLanguage == 'ur'
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  child: Column(
                    children: [
                      Text(
                        _nameController.text.isEmpty
                            ? 'BUSINESS NAME'
                            : _nameController.text,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        'RECEIPT',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(thickness: 1),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ID: #1234', style: TextStyle(fontSize: 8)),
                      Text('Customer: Walk-in', style: TextStyle(fontSize: 8)),
                      Text('Date: 2026-02-05', style: TextStyle(fontSize: 8)),
                    ],
                  ),
                ),
                const Divider(thickness: 1),

                // Compact Items Table
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(1),
                    2: FlexColumnWidth(2),
                  },
                  children: [
                    for (int i = 0; i < 2; i++)
                      TableRow(
                        children: [
                          Text(
                            i == 0 ? 'Sample Item A' : 'Sample Item B',
                            style: TextStyle(fontSize: _settings.tableFontSize),
                          ),
                          Text(
                            '1',
                            style: TextStyle(fontSize: _settings.tableFontSize),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            '500',
                            style: TextStyle(fontSize: _settings.tableFontSize),
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ),
                  ],
                ),
                const Divider(thickness: 0.5),

                // Extra Fields
                ..._settings.extraFields
                    .where((f) => f.isVisible)
                    .map(
                      (field) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${field.label}:',
                              style: TextStyle(
                                fontSize: field.fontSize - 2,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              field.value,
                              style: TextStyle(fontSize: field.fontSize - 2),
                            ),
                          ],
                        ),
                      ),
                    ),

                const Divider(thickness: 0.5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('DISCOUNT', style: TextStyle(fontSize: 9)),
                    Text('Rs 100', style: TextStyle(fontSize: 9)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'Rs 900',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('PAID', style: TextStyle(fontSize: 9)),
                    Text('Rs 900', style: TextStyle(fontSize: 9)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'BALANCED DUE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: Colors.red,
                      ),
                    ),
                    Text(
                      'Rs 0',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Center(
                  child: Directionality(
                    textDirection: _settings.footerLanguage == 'ur'
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    child: Text(
                      _footerController.text,
                      style: TextStyle(
                        fontSize: _settings.footerFontSize,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoPreview() {
    return Container(
      width: _settings.logoSize,
      height: _settings.logoSize,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        image: _settings.logoPath != null
            ? DecorationImage(
                image: FileImage(File(_settings.logoPath!)),
                fit: BoxFit.contain,
              )
            : null,
      ),
    );
  }

  MainAxisAlignment _getLogoAlignment() {
    switch (_settings.logoPosition) {
      case 'top-left':
        return MainAxisAlignment.start;
      case 'top-right':
        return MainAxisAlignment.end;
      case 'center':
        return MainAxisAlignment.center;
      default:
        return MainAxisAlignment.spaceBetween;
    }
  }

  CrossAxisAlignment _getContentAlignment() {
    switch (_settings.logoPosition) {
      case 'top-left':
        return CrossAxisAlignment.end;
      case 'top-right':
        return CrossAxisAlignment.start;
      case 'center':
        return CrossAxisAlignment.center;
      default:
        return CrossAxisAlignment.start;
    }
  }

  Widget _buildBasicInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Business Information (Fixed: MIAN TRADERS)'),
        const SizedBox(height: 8),
        _buildTextField(
          _addressController,
          'Address',
          icon: Icons.location_on,
          maxLines: 2,
        ),
        _buildTextField(
          _taxIdController,
          'Tax ID (NTN/GST)',
          icon: Icons.numbers,
        ),
        _buildTextField(
          _footerController,
          'Footer Note',
          icon: Icons.note,
          maxLines: 2,
        ),
        const Divider(),
        _buildSectionHeader('Localization'),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Invoice Language'),
              DropdownButton<String>(
                value: _settings.language,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'ur', child: Text('Urdu')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _settings = _settings.copyWith(language: v);
                      // Auto-update labels for Urdu
                      if (v == 'ur') {
                        _invoiceLabelController.text = 'انوائس';
                        _currencyController.text = 'روپے';
                      } else {
                        _invoiceLabelController.text = 'INVOICE';
                        _currencyController.text = 'Rs';
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              const Text('Header Language (Independent)'),
              DropdownButton<String>(
                value: _settings.headerLanguage,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English (LTR)')),
                  DropdownMenuItem(value: 'ur', child: Text('Urdu (RTL)')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _settings = _settings.copyWith(headerLanguage: v);
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              const Text('Footer Language (Independent)'),
              DropdownButton<String>(
                value: _settings.footerLanguage,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English (LTR)')),
                  DropdownMenuItem(value: 'ur', child: Text('Urdu (RTL)')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _settings = _settings.copyWith(footerLanguage: v);
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesignTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListenable(
          title: 'Show Logo on Invoice',
          value: _settings.showLogo,
          onChanged: (v) =>
              setState(() => _settings = _settings.copyWith(showLogo: v)),
        ),
        if (_settings.showLogo) ...[
          ListTile(
            title: const Text('Invoice Logo'),
            subtitle: Text(
              _settings.logoPath != null ? 'Logo Selected' : 'No logo selected',
            ),
            trailing: ElevatedButton(
              onPressed: _pickLogo,
              child: const Text('Pick Image'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Logo Size'),
                Slider(
                  value: _settings.logoSize,
                  min: 30,
                  max: 150,
                  onChanged: (v) => setState(
                    () => _settings = _settings.copyWith(logoSize: v),
                  ),
                ),
                const Text('Logo Position'),
                DropdownButton<String>(
                  value: _settings.logoPosition,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: 'top-left',
                      child: Text('Top Left'),
                    ),
                    DropdownMenuItem(
                      value: 'top-right',
                      child: Text('Top Right'),
                    ),
                    DropdownMenuItem(value: 'center', child: Text('Center')),
                  ],
                  onChanged: (v) => setState(
                    () => _settings = _settings.copyWith(logoPosition: v),
                  ),
                ),
              ],
            ),
          ),
        ],
        const Divider(),
        ListTile(
          title: const Text('Header Font (.ttf)'),
          subtitle: Text(_settings.headerFontPath ?? 'Default Font'),
          trailing: ElevatedButton(
            onPressed: () => _pickFont('header'),
            child: const Text('Select File'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Header Font Size'),
              Slider(
                value: _settings.headerFontSize,
                min: 12,
                max: 48,
                onChanged: (v) => setState(
                  () => _settings = _settings.copyWith(headerFontSize: v),
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        ListTile(
          title: const Text('Body Font (.ttf)'),
          subtitle: Text(_settings.bodyFontPath ?? 'Default Font'),
          trailing: ElevatedButton(
            onPressed: () => _pickFont('body'),
            child: const Text('Select File'),
          ),
        ),
        const Divider(),
        ListTile(
          title: const Text('Table Font (.ttf)'),
          subtitle: Text(_settings.tableFontPath ?? 'Default Font'),
          trailing: ElevatedButton(
            onPressed: () => _pickFont('table'),
            child: const Text('Select File'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Table Font Size'),
              Slider(
                value: _settings.tableFontSize,
                min: 8,
                max: 18,
                onChanged: (v) => setState(
                  () => _settings = _settings.copyWith(tableFontSize: v),
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        ListTile(
          title: const Text('Footer Font (.ttf)'),
          subtitle: Text(_settings.footerFontPath ?? 'Default Font'),
          trailing: ElevatedButton(
            onPressed: () => _pickFont('footer'),
            child: const Text('Select File'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Footer Font Size'),
              Slider(
                value: _settings.footerFontSize,
                min: 8,
                max: 18,
                onChanged: (v) => setState(
                  () => _settings = _settings.copyWith(footerFontSize: v),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFontsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Section Fonts'),
        _buildFontSettings('Header Font', _settings.headerFontFamily, (v) {
          setState(() => _settings = _settings.copyWith(headerFontFamily: v));
        }),
        _buildFontSettings('Body Font', _settings.bodyFontFamily, (v) {
          setState(() => _settings = _settings.copyWith(bodyFontFamily: v));
        }),
        _buildFontSettings('Table Font', _settings.tableFontFamily, (v) {
          setState(() => _settings = _settings.copyWith(tableFontFamily: v));
        }),
        _buildFontSettings('Footer Font', _settings.footerFontFamily, (v) {
          setState(() => _settings = _settings.copyWith(footerFontFamily: v));
        }),
        const Divider(),
        _buildSectionHeader('Custom Font Files (.ttf)'),
        ListTile(
          title: const Text('Header Custom Font Path'),
          subtitle: Text(_settings.headerFontPath ?? 'Default'),
          trailing: ElevatedButton(
            onPressed: () => _pickFont('header'),
            child: const Text('Pick'),
          ),
        ),
        ListTile(
          title: const Text('Body Custom Font Path'),
          subtitle: Text(_settings.bodyFontPath ?? 'Default'),
          trailing: ElevatedButton(
            onPressed: () => _pickFont('body'),
            child: const Text('Pick'),
          ),
        ),
        ListTile(
          title: const Text('Table Custom Font Path'),
          subtitle: Text(_settings.tableFontPath ?? 'Default'),
          trailing: ElevatedButton(
            onPressed: () => _pickFont('table'),
            child: const Text('Pick'),
          ),
        ),
        ListTile(
          title: const Text('Footer Custom Font Path'),
          subtitle: Text(_settings.footerFontPath ?? 'Default'),
          trailing: ElevatedButton(
            onPressed: () => _pickFont('footer'),
            child: const Text('Pick'),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FontDebugScreen(),
                ),
              );
            },
            icon: const Icon(Icons.bug_report),
            label: const Text('Test Noon Ghunna (ں) in App'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade50,
              foregroundColor: Colors.orange.shade900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFontSettings(
    String label,
    String value,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label)),
          Expanded(
            flex: 3,
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'Roboto', child: Text('Roboto')),
                DropdownMenuItem(
                  value: 'NotoSansArabic',
                  child: Text('NotoSansArabic'),
                ),
                DropdownMenuItem(value: 'Lalezar', child: Text('Lalezar')),
                DropdownMenuItem(
                  value: 'JameelNoori',
                  child: Text('JameelNoori'),
                ),
                DropdownMenuItem(
                  value: 'Scheherazade',
                  child: Text('Scheherazade'),
                ),
                DropdownMenuItem(value: 'Inter', child: Text('Inter')),
                DropdownMenuItem(value: 'Poppins', child: Text('Poppins')),
                DropdownMenuItem(
                  value: 'Montserrat',
                  child: Text('Montserrat'),
                ),
              ],
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtraFieldsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            onPressed: _addExtraField,
            icon: const Icon(Icons.add),
            label: const Text('Add Extra Field'),
          ),
        ),
        Expanded(
          child: ReorderableListView(
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = _settings.extraFields.removeAt(oldIndex);
                _settings.extraFields.insert(newIndex, item);
              });
            },
            children: [
              for (int i = 0; i < _settings.extraFields.length; i++)
                _buildExtraFieldTile(_settings.extraFields[i], i),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExtraFieldTile(InvoiceExtraField field, int index) {
    return ListTile(
      key: ValueKey(field.id),
      title: Text(field.label),
      subtitle: Text(
        '${field.value} (${field.fontFamily}, ${field.fontSize.toStringAsFixed(0)})',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              field.isVisible ? Icons.visibility : Icons.visibility_off,
            ),
            onPressed: () {
              setState(() {
                _settings.extraFields[index] = field.copyWith(
                  isVisible: !field.isVisible,
                );
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _editExtraField(field, index),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              setState(() {
                _settings.extraFields.removeAt(index);
              });
            },
          ),
          const Icon(Icons.drag_handle),
        ],
      ),
    );
  }

  void _addExtraField() {
    _showExtraFieldDialog(null, null);
  }

  void _editExtraField(InvoiceExtraField field, int index) {
    _showExtraFieldDialog(field, index);
  }

  void _showExtraFieldDialog(InvoiceExtraField? field, int? index) {
    final labelCtrl = TextEditingController(text: field?.label ?? '');
    final valueCtrl = TextEditingController(text: field?.value ?? '');
    double size = field?.fontSize ?? 10.0;
    String family = field?.fontFamily ?? 'Roboto';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(field == null ? 'Add Extra Field' : 'Edit Extra Field'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(labelText: 'Label'),
                ),
                TextField(
                  controller: valueCtrl,
                  decoration: const InputDecoration(labelText: 'Default Value'),
                ),
                const SizedBox(height: 10),
                DropdownButton<String>(
                  value: family,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'Roboto', child: Text('Roboto')),
                    DropdownMenuItem(
                      value: 'NotoSansArabic',
                      child: Text('NotoSansArabic'),
                    ),
                    DropdownMenuItem(value: 'Lalezar', child: Text('Lalezar')),
                    DropdownMenuItem(
                      value: 'JameelNoori',
                      child: Text('JameelNoori'),
                    ),
                  ],
                  onChanged: (v) => setDialogState(() => family = v ?? family),
                ),
                Slider(
                  value: size,
                  min: 8,
                  max: 24,
                  onChanged: (v) => setDialogState(() => size = v),
                ),
                Text('Font Size: ${size.toStringAsFixed(0)}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newField = InvoiceExtraField(
                  id:
                      field?.id ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
                  label: labelCtrl.text,
                  value: valueCtrl.text,
                  fontSize: size,
                  fontFamily: family,
                );
                setState(() {
                  if (index == null) {
                    _settings.extraFields.add(newField);
                  } else {
                    _settings.extraFields[index] = newField;
                  }
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactLabelsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Labels'),
        _buildTextField(
          _invoiceLabelController,
          'Invoice Heading',
          icon: Icons.label,
        ),
        _buildTextField(
          _currencyController,
          'Currency Symbol',
          icon: Icons.money,
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Contact Details'),
        _buildTextField(_phoneController, 'Phone Number', icon: Icons.phone),
        _buildTextField(_emailController, 'Email Address', icon: Icons.email),
        _buildTextField(_websiteController, 'Website', icon: Icons.language),
        const SizedBox(height: 20),
        _buildSectionHeader('Social Media'),
        _buildTextField(_whatsappController, 'WhatsApp', icon: Icons.chat),
        _buildTextField(
          _instagramController,
          'Instagram',
          icon: Icons.camera_alt,
        ),
        _buildTextField(_facebookController, 'Facebook', icon: Icons.facebook),
        const Divider(),
        _buildSectionHeader('Bank Details'),
        _buildTextField(
          _bankNameController,
          'Bank Name',
          icon: Icons.account_balance,
        ),
        _buildTextField(
          _accountNumberController,
          'Account Number',
          icon: Icons.numbers,
        ),
        _buildTextField(
          _accountTitleController,
          'Account Title',
          icon: Icons.person,
        ),
        const Divider(),
        _buildSectionHeader('Additional Settings'),
        _buildTextField(
          _termsController,
          'Terms & Conditions',
          icon: Icons.gavel,
          maxLines: 3,
        ),
        _buildTextField(
          _signatureLabelController,
          'Signature Label',
          icon: Icons.draw,
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    IconData? icon,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon) : null,
          border: const OutlineInputBorder(),
        ),
        onChanged: (v) => setState(() {}),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }
}

class SwitchListenable extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SwitchListenable({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }
}
