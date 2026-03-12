import 'package:flutter/material.dart';
import 'ui/customer_frame.dart';
import 'ui/product_frame.dart';
import 'ui/expense_frame.dart';
import 'ui/supplier/supplier_frame.dart';
import 'ui/purchase_frame.dart';
import 'ui/expiring_products_frame.dart';
import 'ui/reports/reports_dashboard.dart';
import 'ui/order/order_list_screen.dart';
import 'ui/order/order_form_screen.dart';
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
import '../repositories/order_repository.dart';
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
  ProductRepository? _productRepo = ProductRepository();
  SupplierRepository? _supplierRepo;
  SupplierPaymentRepository? _supplierPaymentRepo;
  OrderRepository? _orderRepo = OrderRepository();

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
        tab: Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getIconForTab("Create Order"), size: 18),
              const SizedBox(width: 8),
              const Text("Create Order"),
            ],
          ),
        ),
        view: _orderRepo == null
            ? const Center(child: CircularProgressIndicator())
            : OrderFormScreen(repo: _orderRepo!, isTab: true),
        perm: 'orders',
      ),
      _TabDef(
        tab: Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getIconForTab("Reports"), size: 18),
              const SizedBox(width: 8),
              const Text("Reports"),
            ],
          ),
        ),
        view: ReportsDashboard(sqlAgent: _sqlAgent),
        perm: 'reports_view',
      ),
      _TabDef(
        tab: Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getIconForTab("Customers"), size: 18),
              const SizedBox(width: 8),
              const Text("Customers"),
            ],
          ),
        ),
        view: const CustomerFrame(),
        perm: 'customers_view',
      ),
      _TabDef(
        tab: Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getIconForTab("Products"), size: 18),
              const SizedBox(width: 8),
              const Text("Products"),
            ],
          ),
        ),
        view: const ProductFrame(),
        perm: 'products_view',
      ),
      _TabDef(
        tab: Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getIconForTab("Expenses"), size: 18),
              const SizedBox(width: 8),
              const Text("Expenses"),
            ],
          ),
        ),
        view: const ExpenseFrame(),
        perm: 'expenses_view',
      ),
      _TabDef(
        tab: Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getIconForTab("Suppliers"), size: 18),
              const SizedBox(width: 8),
              const Text("Suppliers"),
            ],
          ),
        ),
        view: _supplierRepo == null || _supplierPaymentRepo == null
            ? const Center(child: CircularProgressIndicator())
            : SupplierFrame(
                repo: _supplierRepo!,
                repo2: _supplierPaymentRepo!,
                purchaseRepo: _purchaseRepo!,
                productRepo: _productRepo!, // 👈 Added
              ),
        perm: 'suppliers_view',
      ),
      _TabDef(
        tab: Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getIconForTab("Purchases"), size: 18),
              const SizedBox(width: 8),
              const Text("Purchases"),
            ],
          ),
        ),
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
        tab: Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getIconForTab("Orders"), size: 18),
              const SizedBox(width: 8),
              const Text("Orders"),
            ],
          ),
        ),
        view: _orderRepo == null
            ? const Center(child: CircularProgressIndicator())
            : OrderListScreen(repo: _orderRepo!),
        perm: 'orders',
      ),
      _TabDef(
        tab: Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getIconForTab("Categories"), size: 18),
              const SizedBox(width: 8),
              const Text("Categories"),
            ],
          ),
        ),
        view: const CategoryListFrame(),
        perm: 'categories_view',
      ),
      _TabDef(
        tab: Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getIconForTab("Customer Payments"), size: 18),
              const SizedBox(width: 8),
              const Text("Customer Payments"),
            ],
          ),
        ),
        view: const CustomerPaymentScreen(),
        perm: 'payments_view',
      ),
      _TabDef(
        tab: Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getIconForTab("BackUp/Restore"), size: 18),
              const SizedBox(width: 8),
              const Text("BackUp/Restore"),
            ],
          ),
        ),
        view: BackupRestoreScreen(
          onRestoreSuccess: () async {
            await _initRepos();
          },
        ),
        perm: 'backup',
      ),
      _TabDef(
        tab: Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getIconForTab("Users"), size: 18),
              const SizedBox(width: 8),
              const Text("Users"),
            ],
          ),
        ),
        view: const UserManagementScreen(),
        perm: 'all', // Only admins/devs
      ),
      _TabDef(
        tab: Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getIconForTab("Audit Logs"), size: 18),
              const SizedBox(width: 8),
              const Text("Audit Logs"),
            ],
          ),
        ),
        view: const AuditLogScreen(),
        perm: 'audit_logs',
      ),
      _TabDef(
        tab: Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getIconForTab("Expiring Products"), size: 18),
              const SizedBox(width: 8),
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
        tab: Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getIconForTab("Stock Disposal"), size: 18),
              const SizedBox(width: 8),
              const Text("Stock Disposal"),
            ],
          ),
        ),
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
      _orderRepo ??= OrderRepository();

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

  IconData _getIconForTab(String label) {
    switch (label.toLowerCase()) {
      case 'create order':
        return Icons.add_shopping_cart;
      case 'reports':
        return Icons.bar_chart;
      case 'customers':
        return Icons.people_outline;
      case 'products':
        return Icons.inventory_2_outlined;
      case 'suppliers':
        return Icons.local_shipping_outlined;
      case 'purchases':
        return Icons.shopping_bag_outlined;
      case 'orders':
        return Icons.assignment_outlined;
      case 'categories':
        return Icons.category_outlined;
      case 'customer payments':
        return Icons.payments_outlined;
      case 'backup/restore':
        return Icons.backup_outlined;
      case 'users':
        return Icons.manage_accounts_outlined;
      case 'audit logs':
        return Icons.history_outlined;
      case 'expiring products':
        return Icons.notification_important_outlined;
      case 'stock disposal':
        return Icons.delete_sweep_outlined;
      default:
        return Icons.tab;
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
                    mouseCursor: SystemMouseCursors.click,
                    overlayColor: WidgetStateProperty.resolveWith<Color?>((
                      Set<WidgetState> states,
                    ) {
                      if (states.contains(WidgetState.hovered)) {
                        return const Color.fromARGB(
                          255,
                          12,
                          109,
                          109,
                        ).withValues(alpha: 0.4);
                      }
                      if (states.contains(WidgetState.pressed)) {
                        return const Color.fromARGB(
                          255,
                          10,
                          57,
                          156,
                        ).withValues(alpha: 0.5);
                      }
                      return null;
                    }),
                    indicatorSize: TabBarIndicatorSize.label,
                    indicatorWeight: 3,
                    indicatorColor: const Color.fromARGB(255, 135, 209, 133),
                    splashBorderRadius: BorderRadius.circular(50),
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.normal,
                    ),
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
                          backgroundColor: Color.fromARGB(255, 45, 202, 71),
                          child: Icon(
                            Icons.person,
                            size: 32,
                            color: Color.fromARGB(255, 84, 153, 209),
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

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              child: ListTile(
                                leading: Icon(
                                  _getIconForTab(label),
                                  color: _tabController.index == index
                                      ? Colors.blue.shade700
                                      : Colors.grey.shade600,
                                ),
                                title: Text(
                                  label,
                                  style: TextStyle(
                                    fontWeight: _tabController.index == index
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: _tabController.index == index
                                        ? Colors.blue.shade800
                                        : Colors.black87,
                                  ),
                                ),
                                selected: _tabController.index == index,
                                selectedTileColor: Colors.blue.withValues(
                                  alpha: 0.1,
                                ),
                                hoverColor: Colors.blue.withValues(alpha: 0.05),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                onTap: () {
                                  _tabController.animateTo(index);
                                  Navigator.pop(context);
                                },
                              ),
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
          body: PageStorage(
            bucket: PageStorageBucket(),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              reverseDuration: const Duration(milliseconds: 500),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (Widget child, Animation<double> animation) {
                final slideTransition = Tween<Offset>(
                  begin: const Offset(0.05, 0.0),
                  end: Offset.zero,
                ).animate(animation);

                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: slideTransition,
                    child: child,
                  ),
                );
              },
              child: _tabViews.isNotEmpty
                  ? KeyedSubtree(
                      key: ValueKey<int>(_tabController.index),
                      child: _tabViews[_tabController.index],
                    )
                  : const Center(child: Text("No content allowed")),
            ),
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
