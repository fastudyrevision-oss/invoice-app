import 'package:flutter/material.dart';

class HelpFrame extends StatefulWidget {
  const HelpFrame({super.key});

  @override
  State<HelpFrame> createState() => _HelpFrameState();
}

class _HelpFrameState extends State<HelpFrame> {
  final TextEditingController _searchController = TextEditingController();
  List<HelpTopic> _topics = [];
  List<HelpTopic> _filteredTopics = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _topics = _buildTopics();
    _filteredTopics = _topics;
  }

  void _filterTopics(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredTopics = _topics;
      } else {
        _filteredTopics = _topics.where((topic) {
          final matchesTitle = topic.title.toLowerCase().contains(
            query.toLowerCase(),
          );
          final matchesContent = topic.children.any(
            (child) =>
                child.title.toLowerCase().contains(query.toLowerCase()) ||
                child.content.toLowerCase().contains(query.toLowerCase()),
          );
          return matchesTitle || matchesContent;
        }).toList();
      }
    });
  }

  List<HelpTopic> _buildTopics() {
    return [
      HelpTopic(
        title: "Critical Cautions & Data Safety",
        icon: Icons.warning_amber_rounded,
        children: [
          HelpItem(
            title: "Data Entry Requirements",
            content:
                "• **Suppliers**: Name is mandatory. Phone numbers should be unique to avoid confusion.\n• **Products**: 'Stock' field is the *initial* stock. Do not edit this to add new stock; use 'Purchases' instead to ensure proper accounting.",
          ),
          HelpItem(
            title: "Deleting Records",
            content:
                "• **Soft Delete**: Deleting a supplier or product only hides it ('Soft Delete'). You can restore them from the trash/hidden view.\n• **Permanent Data Loss**: Clearing App Data or uninstalling without a backup will result in permanent loss.",
          ),
          HelpItem(
            title: "Backups are Vital",
            content:
                "ALWAYS create a backup (BackUp/Restore tab) before updating the app or making bulk changes. Download the backup file to a safe location (e.g., Google Drive) immediately.",
          ),
        ],
      ),
      HelpTopic(
        title: "Workflow Guide",
        icon: Icons.schema,
        children: [
          HelpItem(
            title: "Correct Stock Flow",
            content:
                "1. **Buy Stock**: Go to 'Purchases', select Supplier, add items. This *Automatically Increments* product stock.\n2. **Sell Stock**: Create 'Order'. This *Automatically Decrements* stock.\n\n⚠️ **Avoid**: Manually editing product stock in the Product Edit screen unless doing a correction/audit.",
          ),
          HelpItem(
            title: "Supplier Payments",
            content:
                "When you pay a supplier, ensure you record it in **Suppliers > Detail > Add Payment**. Do not just 'Keep a note'. Recording it updates the 'Pending' balance and affects your Financial Reports.",
          ),
          HelpItem(
            title: "Printer Troubleshooting",
            content:
                "If printing fails:\n1. Check if Printer is ON.\n2. Verify IP Address in Settings (for Network printers).\n3. If USB, ensure OTG/Cable is connected.\n4. Use the 'Test Print' button in Settings to verify connectivity.",
          ),
        ],
      ),
      HelpTopic(
        title: "Getting Started",
        icon: Icons.rocket_launch,
        children: [
          HelpItem(
            title: "Dashboard Overview",
            content:
                "The dashboard (Reports tab) gives you a quick summary of your business performance, including Today's Sales, Weekly Revenue, and Low Stock alerts.",
          ),
          HelpItem(
            title: "Navigation",
            content:
                "Use the tabs at the bottom (Mobile) or top (Desktop) to navigate between sections like Customers, Products, and Orders. Use the 'More' menu or Drawer for Settings and Backups.",
          ),
        ],
      ),
      HelpTopic(
        title: "Inventory Management",
        icon: Icons.inventory_2,
        children: [
          HelpItem(
            title: "Adding Products",
            content:
                "Go to the **Products** tab and click the '+' button. Fill in the name, price, cost (optional), and stock level. You can also assign categories here.",
          ),
          HelpItem(
            title: "Stock Tracking",
            content:
                "Stock levels decrease automatically when you make a sale. You can manually adjust stock in the Product Edit screen or via the **Stock Report**.",
          ),
          HelpItem(
            title: "Categories",
            content:
                "Organize products into categories (e.g., Electronics, Food) in the **Categories** tab. This helps in filtering reports.",
          ),
          HelpItem(
            title: "Expiring Products",
            content:
                "For perishable goods, use the **Expiring** tab. Products added via the Purchase screen with an expiry date will appear here when they are close to expiring.",
          ),
        ],
      ),
      HelpTopic(
        title: "Sales & Invoicing",
        icon: Icons.shopping_cart,
        children: [
          HelpItem(
            title: "Creating an Order",
            content:
                "Go to **Orders** > '+' Button. Select a customer, add products to the cart, and click 'Save'. You can print the receipt immediately.",
          ),
          HelpItem(
            title: "Printing Receipts",
            content:
                "We support both **Thermal Printers** (USB/Network) and standard A4 **PDF** Invoice printing. Configure your printer in **Settings** > **Printer Settings**.",
          ),
          HelpItem(
            title: "Customer Payments",
            content:
                "Manage customer credit in the **Customer Payments** tab. You can record partial payments and view a statement of their account.",
          ),
        ],
      ),
      HelpTopic(
        title: "Purchases & Suppliers",
        icon: Icons.local_shipping,
        children: [
          HelpItem(
            title: "Recording Purchases",
            content:
                "When buying stock, go to **Purchases**. Select the Supplier and add items. This automatically increases your product stock levels.",
          ),
          HelpItem(
            title: "Managing Suppliers",
            content:
                "Add suppliers in the **Suppliers** tab. You can track how much you owe them and record payments sent.",
          ),
        ],
      ),
      HelpTopic(
        title: "Reports & Exports",
        icon: Icons.analytics,
        children: [
          HelpItem(
            title: "Exporting Data",
            content:
                "Almost every list (Products, Customers, etc.) has an **Export** button (Share/Print/Save) in the top right. Use this to save PDFs or CSVs.",
          ),
          HelpItem(
            title: "Financial Reports",
            content:
                "Check the **Reports** tab for detailed breakdowns of Profit/Loss, Expenses, and Sales History.",
          ),
        ],
      ),
      HelpTopic(
        title: "System & Troubleshooting",
        icon: Icons.settings_suggest,
        children: [
          HelpItem(
            title: "Backup & Restore",
            content:
                "Go to **BackUp/Restore**. Create regular backups to keep your data safe. Restore from a backup file if you move to a new device.",
          ),
          HelpItem(
            title: "System Logs",
            content:
                "If something goes wrong, click the **Bug** icon 🐞 in the top-right to view System Logs. You can share these logs with support.",
          ),
          HelpItem(
            title: "Printer Setup",
            content:
                "If printing fails, check **Printer Settings**. Ensure your printer IP is correct (for network) or USB cable is connected. Use the 'Test Connection' button.",
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("User Guide")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search help topics...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterTopics('');
                        },
                      )
                    : null,
              ),
              onChanged: _filterTopics,
            ),
          ),
          Expanded(
            child: _filteredTopics.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.help_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No topics found",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: _filteredTopics.length,
                    itemBuilder: (context, index) {
                      final topic = _filteredTopics[index];
                      // If searching, auto-expand relevant tiles (simplified: just show them)
                      // Ideally we'd expand them, but explicit ExpansionTile handling can be tricky with state.
                      // For now, we just rendering them.

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.1),
                            child: Icon(
                              topic.icon,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          title: Text(
                            topic.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          initiallyExpanded: _searchQuery.isNotEmpty,
                          children: topic.children.map((item) {
                            if (_searchQuery.isNotEmpty &&
                                !item.title.toLowerCase().contains(
                                  _searchQuery.toLowerCase(),
                                ) &&
                                !item.content.toLowerCase().contains(
                                  _searchQuery.toLowerCase(),
                                ) &&
                                !topic.title.toLowerCase().contains(
                                  _searchQuery.toLowerCase(),
                                )) {
                              // If parent matches but child doesn't, we show all children?
                              // Or if child matches, show it.

                              if (!topic.title.toLowerCase().contains(
                                _searchQuery.toLowerCase(),
                              )) {
                                return const SizedBox.shrink(); // Skip non-matching children if parent doesn't match
                              }
                            }

                            return ListTile(
                              title: Text(
                                item.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(item.content),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 8,
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class HelpTopic {
  final String title;
  final IconData icon;
  final List<HelpItem> children;

  HelpTopic({required this.title, required this.icon, required this.children});
}

class HelpItem {
  final String title;
  final String content;

  HelpItem({required this.title, required this.content});
}
