import 'dart:convert';

class InvoiceExtraField {
  final String id;
  final String label;
  final String value;
  final double fontSize;
  final String fontFamily;
  final bool isVisible;

  InvoiceExtraField({
    required this.id,
    required this.label,
    required this.value,
    this.fontSize = 10.0,
    this.fontFamily = 'Roboto',
    this.isVisible = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'value': value,
      'fontSize': fontSize,
      'fontFamily': fontFamily,
      'isVisible': isVisible,
    };
  }

  factory InvoiceExtraField.fromMap(Map<String, dynamic> map) {
    return InvoiceExtraField(
      id: map['id'] ?? '',
      label: map['label'] ?? '',
      value: map['value'] ?? '',
      fontSize: (map['fontSize'] ?? 10.0).toDouble(),
      fontFamily: map['fontFamily'] ?? 'Roboto',
      isVisible: map['isVisible'] ?? true,
    );
  }

  InvoiceExtraField copyWith({
    String? id,
    String? label,
    String? value,
    double? fontSize,
    String? fontFamily,
    bool? isVisible,
  }) {
    return InvoiceExtraField(
      id: id ?? this.id,
      label: label ?? this.label,
      value: value ?? this.value,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      isVisible: isVisible ?? this.isVisible,
    );
  }
}

class InvoiceSettings {
  // Business Info
  final String businessName;
  final String address;
  final String phone;
  final String email;
  final String website;
  final String taxId;

  // Social Media
  final String whatsapp;
  final String instagram;
  final String facebook;

  // Design
  final String? headerFontPath;
  final String? bodyFontPath;
  final String? tableFontPath;
  final String? footerFontPath;
  final double headerFontSize;
  final double bodyFontSize;
  final double tableFontSize;
  final double footerFontSize;
  final String primaryColor; // Hex string e.g., "#000000"
  final bool showLogo;
  final String? logoPath;
  final double logoSize;
  final String logoPosition; // 'top-left', 'top-right', 'center'

  // Unified Font Families
  final String headerFontFamily;
  final String bodyFontFamily;
  final String tableFontFamily;
  final String footerFontFamily;

  // Localization / Labels
  final String language; // 'en' or 'ur'
  final String? _headerLanguage; // Independent header language
  String get headerLanguage => _headerLanguage ?? 'en';
  final String? _footerLanguage; // Independent footer language
  String get footerLanguage => _footerLanguage ?? 'en';
  final String currencySymbol;
  final String invoiceLabel;
  final String dateLabel;
  final String customerLabel;
  final String footerText;

  // New Dynamic Fields
  final String bankName;
  final String accountNumber;
  final String accountTitle;
  final String termsAndConditions;
  final String signatureLabel;

  // Reorderable Extra Informatory Fields
  final List<InvoiceExtraField> extraFields;

  InvoiceSettings({
    this.businessName = 'MIAN TRADERS',
    this.address = 'Kotmomin road, Bhagtanawala, Sargodha',
    this.phone = '+92 345 4297128',
    this.email = 'bilalahmadgh@gmail.com',
    this.website = '',
    this.taxId = '',
    this.whatsapp = '',
    this.instagram = '',
    this.facebook = '',
    this.headerFontPath,
    this.bodyFontPath,
    this.tableFontPath,
    this.footerFontPath,
    this.headerFontSize = 24.0,
    this.bodyFontSize = 10.0,
    this.tableFontSize = 10.0,
    this.footerFontSize = 10.0,
    this.primaryColor = '#000000',
    this.showLogo = true,
    this.logoPath,
    this.logoSize = 60.0,
    this.logoPosition = 'top-right',
    this.headerFontFamily = 'Roboto',
    this.bodyFontFamily = 'Roboto',
    this.tableFontFamily = 'Roboto',
    this.footerFontFamily = 'Roboto',
    this.language = 'en',
    String? headerLanguage = 'en',
    this.currencySymbol = 'Rs',
    this.invoiceLabel = 'INVOICE',
    this.dateLabel = 'Date',
    this.customerLabel = 'Customer',
    this.footerText = 'Thank you for your business!',
    String? footerLanguage = 'en',
    this.bankName = '',
    this.accountNumber = '',
    this.accountTitle = '',
    this.termsAndConditions = '',
    this.signatureLabel = 'Authorized Signature',
    this.extraFields = const [],
  }) : _headerLanguage = headerLanguage,
       _footerLanguage = footerLanguage;

  Map<String, dynamic> toMap() {
    return {
      'businessName': businessName,
      'address': address,
      'phone': phone,
      'email': email,
      'website': website,
      'taxId': taxId,
      'whatsapp': whatsapp,
      'instagram': instagram,
      'facebook': facebook,
      'headerFontPath': headerFontPath,
      'bodyFontPath': bodyFontPath,
      'tableFontPath': tableFontPath,
      'footerFontPath': footerFontPath,
      'headerFontSize': headerFontSize,
      'bodyFontSize': bodyFontSize,
      'tableFontSize': tableFontSize,
      'footerFontSize': footerFontSize,
      'primaryColor': primaryColor,
      'showLogo': showLogo,
      'logoPath': logoPath,
      'logoSize': logoSize,
      'logoPosition': logoPosition,
      'headerFontFamily': headerFontFamily,
      'bodyFontFamily': bodyFontFamily,
      'tableFontFamily': tableFontFamily,
      'footerFontFamily': footerFontFamily,
      'language': language,
      'headerLanguage': _headerLanguage,
      'footerLanguage': _footerLanguage,
      'bankName': bankName,
      'currencySymbol': currencySymbol,
      'invoiceLabel': invoiceLabel,
      'dateLabel': dateLabel,
      'customerLabel': customerLabel,
      'footerText': footerText,
      'accountNumber': accountNumber,
      'accountTitle': accountTitle,
      'termsAndConditions': termsAndConditions,
      'signatureLabel': signatureLabel,
      'extraFields': extraFields.map((x) => x.toMap()).toList(),
    };
  }

  factory InvoiceSettings.fromMap(Map<String, dynamic> map) {
    return InvoiceSettings(
      businessName: (map['businessName'] as String?) ?? 'MIAN TRADERS',
      address: (map['address'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      website: (map['website'] as String?) ?? '',
      taxId: (map['taxId'] as String?) ?? '',
      whatsapp: (map['whatsapp'] as String?) ?? '',
      instagram: (map['instagram'] as String?) ?? '',
      facebook: (map['facebook'] as String?) ?? '',
      headerFontPath: map['headerFontPath'] as String?,
      bodyFontPath: map['bodyFontPath'] as String?,
      tableFontPath: map['tableFontPath'] as String?,
      footerFontPath: map['footerFontPath'] as String?,
      headerFontSize: (map['headerFontSize'] ?? 24.0).toDouble(),
      bodyFontSize: (map['bodyFontSize'] ?? 10.0).toDouble(),
      tableFontSize: (map['tableFontSize'] ?? 10.0).toDouble(),
      footerFontSize: (map['footerFontSize'] ?? 10.0).toDouble(),
      primaryColor: (map['primaryColor'] as String?) ?? '#000000',
      showLogo: map['showLogo'] ?? true,
      logoPath: map['logoPath'] as String?,
      logoSize: (map['logoSize'] ?? 60.0).toDouble(),
      logoPosition: (map['logoPosition'] as String?) ?? 'top-right',
      headerFontFamily: (map['headerFontFamily'] as String?) ?? 'Roboto',
      bodyFontFamily: (map['bodyFontFamily'] as String?) ?? 'Roboto',
      tableFontFamily: (map['tableFontFamily'] as String?) ?? 'Roboto',
      footerFontFamily: (map['footerFontFamily'] as String?) ?? 'Roboto',
      language: (map['language'] as String?) ?? 'en',
      headerLanguage: (map['headerLanguage'] as String?) ?? 'en',
      currencySymbol: (map['currencySymbol'] as String?) ?? 'Rs',
      invoiceLabel: (map['invoiceLabel'] as String?) ?? 'INVOICE',
      dateLabel: (map['dateLabel'] as String?) ?? 'Date',
      customerLabel: (map['customerLabel'] as String?) ?? 'Customer',
      footerText:
          (map['footerText'] as String?) ?? 'Thank you for your business!',
      footerLanguage: (map['footerLanguage'] as String?) ?? 'en',
      bankName: (map['bankName'] as String?) ?? '',
      accountNumber: (map['accountNumber'] as String?) ?? '',
      accountTitle: (map['accountTitle'] as String?) ?? '',
      termsAndConditions: (map['termsAndConditions'] as String?) ?? '',
      signatureLabel:
          (map['signatureLabel'] as String?) ?? 'Authorized Signature',
      extraFields: map['extraFields'] != null
          ? List<InvoiceExtraField>.from(
              map['extraFields']?.map((x) => InvoiceExtraField.fromMap(x)),
            )
          : [],
    );
  }

  String toJson() => json.encode(toMap());

  factory InvoiceSettings.fromJson(String source) =>
      InvoiceSettings.fromMap(json.decode(source));

  InvoiceSettings copyWith({
    String? businessName,
    String? address,
    String? phone,
    String? email,
    String? website,
    String? taxId,
    String? whatsapp,
    String? instagram,
    String? facebook,
    String? headerFontPath,
    String? bodyFontPath,
    String? tableFontPath,
    String? footerFontPath,
    double? headerFontSize,
    double? bodyFontSize,
    double? tableFontSize,
    double? footerFontSize,
    String? primaryColor,
    bool? showLogo,
    String? logoPath,
    double? logoSize,
    String? logoPosition,
    String? headerFontFamily,
    String? bodyFontFamily,
    String? tableFontFamily,
    String? footerFontFamily,
    String? language,
    String? headerLanguage,
    String? footerLanguage,
    String? currencySymbol,
    String? invoiceLabel,
    String? dateLabel,
    String? customerLabel,
    String? footerText,
    String? bankName,
    String? accountNumber,
    String? accountTitle,
    String? termsAndConditions,
    String? signatureLabel,
    List<InvoiceExtraField>? extraFields,
  }) {
    return InvoiceSettings(
      businessName: businessName ?? this.businessName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      taxId: taxId ?? this.taxId,
      whatsapp: whatsapp ?? this.whatsapp,
      instagram: instagram ?? this.instagram,
      facebook: facebook ?? this.facebook,
      headerFontPath: headerFontPath ?? this.headerFontPath,
      bodyFontPath: bodyFontPath ?? this.bodyFontPath,
      tableFontPath: tableFontPath ?? this.tableFontPath,
      footerFontPath: footerFontPath ?? this.footerFontPath,
      headerFontSize: headerFontSize ?? this.headerFontSize,
      bodyFontSize: bodyFontSize ?? this.bodyFontSize,
      tableFontSize: tableFontSize ?? this.tableFontSize,
      footerFontSize: footerFontSize ?? this.footerFontSize,
      primaryColor: primaryColor ?? this.primaryColor,
      showLogo: showLogo ?? this.showLogo,
      logoPath: logoPath ?? this.logoPath,
      logoSize: logoSize ?? this.logoSize,
      logoPosition: logoPosition ?? this.logoPosition,
      headerFontFamily: headerFontFamily ?? this.headerFontFamily,
      bodyFontFamily: bodyFontFamily ?? this.bodyFontFamily,
      tableFontFamily: tableFontFamily ?? this.tableFontFamily,
      footerFontFamily: footerFontFamily ?? this.footerFontFamily,
      language: language ?? this.language,
      headerLanguage: headerLanguage ?? _headerLanguage,
      footerLanguage: footerLanguage ?? _footerLanguage,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      invoiceLabel: invoiceLabel ?? this.invoiceLabel,
      dateLabel: dateLabel ?? this.dateLabel,
      customerLabel: customerLabel ?? this.customerLabel,
      footerText: footerText ?? this.footerText,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      accountTitle: accountTitle ?? this.accountTitle,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
      signatureLabel: signatureLabel ?? this.signatureLabel,
      extraFields: extraFields ?? this.extraFields,
    );
  }
}
