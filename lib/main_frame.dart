import 'package:flutter/material.dart';
import 'ui/customer_frame.dart';
import 'ui/product_frame.dart';
import 'ui/expense_frame.dart';
import 'ui/supplier/supplier_frame.dart';
import 'ui/purchase_frame.dart';
import 'ui/expiring_products_frame.dart';
import 'ui/reports/reports_dashboard.dart';
import 'ui/order/order_list_screen.dart';
import 'ui/category/category_list_frame.dart';
import 'ui/backup/backup_frame.dart';
import 'modules/audit_log/presentation/audit_log_screen.dart';
import 'ui/customer_payment/customer_payment_screen.dart';
import 'ui/settings/user_management_screen.dart';
import 'ui/settings/printer_settings_screen.dart';
import 'ui/settings/logs_frame.dart';
import 'ui/settings/invoice_customization_screen.dart';
import 'ui/help/help_frame.dart';
import 'ui/expired/expired_stock_screen.dart';

import '../repositories/purchase_repo.dart';
import '../repositories/supplier_repo.dart';
import '../repositories/product_repository.dart';
import '../repositories/supplier_payment_repo.dart';
import '../db/database_helper.dart';
import '../dao/supplier_dao.dart';
import '../dao/supplier_report_dao.dart';
import '../dao/supplier_payment_dao.dart';
import '../dao/supplier_company_dao.dart';
import '../agent/flutter_sql_agent_ai.dart';
import 'package:sqflite/sqflite.dart';
import '../utils/responsive_utils.dart';

import '../services/auth_service.dart';
import '../services/logger_service.dart';
import '../services/update_service.dart';
import 'package:url_launcher/url_launcher.dart';

class MainFrame extends StatefulWidget {
  const MainFrame({super.key});

  @override
  State<MainFrame> createState() => _MainFrameState();
}

class _MainFrameState extends State<MainFrame> with TickerProviderStateMixin {
  late TabController _tabController;

  // We keep parallel lists for Tab widgets and their content body
  // to ensuring indices always match.
  List<Tab> _tabs = [];
  List<Widget> _tabViews = [];

  PurchaseRepository? _purchaseRepo;
  ProductRepository? _productRepo;
  SupplierRepository? _supplierRepo;
  SupplierPaymentRepository? _supplierPaymentRepo;

  Database? _db;
  int _expiringCount = 0;
  late SqlAgentService _sqlAgent;
  late GeminiService _gemini;

  void _initAI() {
    _gemini = GeminiService(apiKey: GEMINI_API_KEY, apiUrl: GEMINI_API_URL);

    _sqlAgent = SqlAgentService(
      gemini: _gemini,
      dbHelper: DatabaseHelper.instance,
    );
    logger.info('MainFrame', 'AI Services Initialized');
  }

  void _updateTabs() {
    final auth = AuthService.instance;
    final allTabs = [
      _TabDef(
        tab: const Tab(text: "Reports"),
        view: ReportsDashboard(sqlAgent: _sqlAgent),
        perm: 'reports_view',
      ),
      _TabDef(
        tab: const Tab(text: "Customers"),
        view: const CustomerFrame(),
        perm: 'customers_view',
      ),
      _TabDef(
        tab: const Tab(text: "Products"),
        view: const ProductFrame(),
        perm: 'products_view',
      ),
      _TabDef(
        tab: const Tab(text: "Expenses"),
        view: const ExpenseFrame(),
        perm: 'expenses_view',
      ),
      _TabDef(
        tab: const Tab(text: "Suppliers"),
        view: _supplierRepo == null || _supplierPaymentRepo == null
            ? const Center(child: CircularProgressIndicator())
            : SupplierFrame(
                repo: _supplierRepo!,
                repo2: _supplierPaymentRepo!,
                purchaseRepo: _purchaseRepo!,
              ),
        perm: 'suppliers_view',
      ),
      _TabDef(
        tab: const Tab(text: "Purchases"),
        view:
            _purchaseRepo == null ||
                _productRepo == null ||
                _supplierRepo == null
            ? const Center(child: CircularProgressIndicator())
            : PurchaseFrame(
                repo: _purchaseRepo!,
                productRepo: _productRepo!,
                supplierRepo: _supplierRepo!,
                paymentRepo: _supplierPaymentRepo!,
              ),
        perm: 'purchases_view',
      ),
      _TabDef(
        tab: const Tab(text: "Orders"),
        view: const OrderListScreen(),
        perm: 'orders',
      ),
      _TabDef(
        tab: const Tab(text: "Categories"),
        view: const CategoryListFrame(),
        perm: 'categories_view',
      ),
      _TabDef(
        tab: const Tab(text: "Customer Payments"),
        view: const CustomerPaymentScreen(),
        perm: 'payments_view',
      ),
      _TabDef(
        tab: const Tab(text: "BackUp/Restore"),
        view: BackupRestoreScreen(
          onRestoreSuccess: () async {
            await _initRepos();
          },
        ),
        perm: 'backup',
      ),
      _TabDef(
        tab: const Tab(text: "Users"),
        view: const UserManagementScreen(),
        perm: 'all', // Only admins/devs
      ),
      _TabDef(
        tab: const Tab(text: "Audit Logs"),
        view: const AuditLogScreen(),
        perm: 'audit_logs',
      ),
      _TabDef(
        tab: Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Expiring"),
              if (_expiringCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$_expiringCount',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
        view: _purchaseRepo == null || _db == null
            ? const Center(child: CircularProgressIndicator())
            : ExpiringProductsFrame(
                db: _db!,
                onDataChanged: () => _refreshExpiringCount(),
              ),
        perm: 'expiring_view',
      ),
      _TabDef(
        tab: const Tab(text: "Stock Disposal"),
        view: const ExpiredStockScreen(),
        perm: 'expiring_view', // Reuse expiring view permission for now
      ),
    ];

    final newTabs = <Tab>[];
    final newTabViews = <Widget>[];

    for (final def in allTabs) {
      bool allowed = false;
      if (def.perm == null) {
        allowed = true;
      } else {
        allowed = auth.canAccess(def.perm!);
      }

      if (allowed) {
        newTabs.add(def.tab);
        newTabViews.add(def.view);
      }
    }

    _tabs = newTabs;
    _tabViews = newTabViews;
  }

  void _ensureController() {
    // If controller length doesn't match tabs, recreate it.
    // Also handle initial creation if needed (though initState does that).
    // We check safety logic here.

    // safe check: if _tabController is initialized (late variable can throw on access if not init)
    // We assume it IS initialized in initState.

    if (_tabController.length != _tabs.length) {
      _tabController.dispose();
      _tabController = TabController(
        length: _tabs.isNotEmpty ? _tabs.length : 1,
        vsync: this,
      );
      _tabController.addListener(_handleTabSelection);

      // If no tabs, maybe disable index?
      if (_tabs.isEmpty) {
        _tabController.index = 0; // dummy
      }
    }
  }

  Future<void> _initRepos() async {
    _db = await DatabaseHelper.instance.db;

    if (!mounted) return;

    setState(() {
      _purchaseRepo = PurchaseRepository(_db!);
      _productRepo = ProductRepository();
      _supplierRepo = SupplierRepository(
        SupplierDao(),
        SupplierPaymentDao(),
        SupplierReportDao(),
        SupplierCompanyDao(),
      );
      _supplierPaymentRepo = SupplierPaymentRepository(
        SupplierPaymentDao(),
        SupplierDao(),
        _purchaseRepo!,
      );

      _updateTabs();
      _ensureController();
    });
    logger.info('MainFrame', 'Repositories Initialized');

    await _refreshExpiringCount();
  }

  Future<void> _refreshExpiringCount({int days = 30}) async {
    if (_purchaseRepo == null) return;
    final expiring = await _purchaseRepo!.getExpiringBatches(days);
    if (!mounted) return;
    setState(() {
      _expiringCount = expiring.length;
      _updateTabs();
      _ensureController();
    });
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging ||
        _tabController.animation == null ||
        _tabController.animation!.isCompleted) {
      if (mounted) setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _initAI();

    // Initial build of tabs
    _updateTabs();

    // Initialize controller immediately
    // If _tabs is empty, we must provide length >= 0. TabController length 0 throws?
    // TabController assertion: length >= 0.
    // However, if length is 0, TabBar might throw if rendered?
    // Let's use 1 if empty to avoid crashes, and handle UI separately.
    int initialLength = _tabs.isNotEmpty ? _tabs.length : 1;

    _tabController = TabController(length: initialLength, vsync: this);
    _tabController.addListener(_handleTabSelection);

    _initRepos();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  void _logout() {
    AuthService.instance.logout();
  }

  void _openPrinterSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const PrinterSettingsScreen()),
    );
  }

  void _openInvoiceDesigner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const InvoiceCustomizationScreen(),
      ),
    );
  }

  void _openLogs() {
    logger.info('MainFrame', 'Opening Logs Frame');
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const LogsFrame()));
  }

  void _openHelp() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const HelpFrame()));
  }

  Future<void> _checkForUpdate() async {
    final updateService = UpdateService();
    // Show loading? Or just background. Let's show a loading dialog or snackbar.
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Checking for updates...')));

    final updateInfo = await updateService.checkForUpdate();
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (updateInfo != null) {
      // Show update dialog
      final shouldUpdate = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Update Available: ${updateInfo.latestVersion}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('A new version is available.'),
                const SizedBox(height: 8),
                const Text(
                  'Release Notes:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(updateInfo.notes),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Download & Install'),
            ),
          ],
        ),
      );

      if (shouldUpdate == true) {
        if (await canLaunchUrl(Uri.parse(updateInfo.downloadUrl))) {
          await launchUrl(
            Uri.parse(updateInfo.downloadUrl),
            mode: LaunchMode.externalApplication,
          );
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not open download URL')),
            );
          }
        }
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('App is up to date!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Safety check for empty tabs
    if (_tabs.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Access Denied"),
          actions: [
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: "Printer Settings",
              onPressed: _openPrinterSettings,
            ),
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: "Help & Guide",
              onPressed: _openHelp,
            ),
            IconButton(
              icon: const Icon(Icons.bug_report),
              tooltip: "System Logs",
              onPressed: _openLogs,
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: "Logout",
              onPressed: _logout,
            ),
          ],
        ),
        body: const Center(
          child: Text("You do not have permission to view any content."),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = ResponsiveUtils.isMobile(context);

        final safeIndex = _tabController.index < _tabs.length
            ? _tabController.index
            : 0;
        final title = safeIndex < _tabs.length
            ? (_tabs[safeIndex].text ?? "Mian Traders")
            : "Mian Traders";

        return Scaffold(
          appBar: AppBar(
            title: Text(isMobile ? title : "Mian Traders"),
            actions: [
              IconButton(
                icon: const Icon(Icons.print),
                tooltip: "Printer Settings",
                onPressed: _openPrinterSettings,
              ),
              IconButton(
                icon: const Icon(Icons.design_services),
                tooltip: "Invoice Designer",
                onPressed: _openInvoiceDesigner,
              ),
              IconButton(
                icon: const Icon(Icons.help_outline),
                tooltip: "Help & Guide",
                onPressed: _openHelp,
              ),
              IconButton(
                icon: const Icon(Icons.bug_report),
                tooltip: "System Logs",
                onPressed: _openLogs,
              ),
              IconButton(
                icon: const Icon(Icons.system_update),
                tooltip: "Check for Updates",
                onPressed: _checkForUpdate,
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: "Logout",
                onPressed: _logout,
              ),
            ],
            bottom: isMobile
                ? null
                : TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabs: _tabs,
                  ),
          ),
          drawer: isMobile
              ? Drawer(
                  child: Column(
                    children: [
                      UserAccountsDrawerHeader(
                        accountName: Text(
                          AuthService.instance.currentUser?.username ?? "User",
                        ),
                        accountEmail: Text(
                          AuthService.instance.currentUser?.role
                                  .toUpperCase() ??
                              "",
                        ),
                        currentAccountPicture: const CircleAvatar(
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.person,
                            size: 32,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _tabs.length,
                          itemBuilder: (context, index) {
                            final tab = _tabs[index];
                            String label = tab.text ?? "";
                            if (label.isEmpty && tab.child is Row) {
                              label = "Expiring Products";
                            }

                            return ListTile(
                              title: Text(label),
                              selected: _tabController.index == index,
                              selectedColor: Theme.of(context).primaryColor,
                              onTap: () {
                                _tabController.animateTo(index);
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.red),
                        title: const Text(
                          "Logout",
                          style: TextStyle(color: Colors.red),
                        ),
                        onTap: _logout,
                      ),
                    ],
                  ),
                )
              : null,
          body: TabBarView(
            controller: _tabController,
            physics: isMobile ? const NeverScrollableScrollPhysics() : null,
            children: _tabViews,
          ),
        );
      },
    );
  }
}

class _TabDef {
  final Tab tab;
  final Widget view;
  final String? perm;

  _TabDef({required this.tab, required this.view, this.perm});
}
