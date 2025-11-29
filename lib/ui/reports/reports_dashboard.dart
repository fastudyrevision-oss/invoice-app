import 'package:flutter/material.dart';
import 'supplier_report_frame.dart';
import 'product_report_frame.dart';
import 'expense_report_frame.dart';
import 'expiry_report_frame.dart';
import 'payment_report_frame.dart';
import '../stock/stock_report_frame.dart';
import '../../agent/flutter_sql_agent_ai.dart';

import '../../modules/profit_loss/presentation/profit_loss_screen.dart';
import '../../modules/profit_loss/data/repository/profit_loss_repo.dart';
import '../../modules/profit_loss/data/dao/profit_loss_dao.dart';
import '../../modules/profit_loss/data/dao/manual_entry_dao.dart';

class ReportsDashboard extends StatelessWidget {
  final SqlAgentService sqlAgent;
  const ReportsDashboard({super.key, required this.sqlAgent});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 8, // updated count
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Reports Dashboard"),
          bottom: const TabBar(
            isScrollable: true, // helps if there are many tabs
            tabs: [
              Tab(text: "Suppliers"),

              Tab(text: "Products"),
              Tab(text: "Expenses"),
              Tab(text: "Expiry"),
              Tab(text: "Payments"),
              Tab(text: "Stock Report"),
              Tab(text: "AI Reports"), // ← NEW TAB
              Tab(text: "Profit and Loss"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            SupplierReportFrame(),
            ProductReportFrame(),
            ExpenseReportFrame(),
            ExpiryReportFrame(),
            PaymentReportFrame(),
            StockReportFrame(),
            // ---- AI TAB ----
            ReportRunnerWidget(agent: sqlAgent), // ← THIS IS YOUR AI UI
            ProfitLossScreen(
              controller: ProfitLossUIController(
                ProfitLossRepository(ProfitLossDao(), ManualEntryDao()),
              ),
            ), //
          ],
        ),
      ),
    );
  }
}
