import 'package:flutter/material.dart';
import 'payment_report_frame.dart';
import '../stock/stock_report_frame.dart';
import '../../agent/flutter_sql_agent_ai.dart';

import '../../modules/profit_loss/presentation/profit_loss_screen.dart';
import '../../modules/profit_loss/data/repository/profit_loss_repo.dart';
import '../../modules/profit_loss/data/dao/profit_loss_dao.dart';
import '../../modules/profit_loss/data/dao/manual_entry_dao.dart';

class ReportsDashboard extends StatefulWidget {
  final SqlAgentService sqlAgent;
  const ReportsDashboard({super.key, required this.sqlAgent});

  @override
  State<ReportsDashboard> createState() => _ReportsDashboardState();
}

class _ReportsDashboardState extends State<ReportsDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildTabContent(int index) {
    // Only build the currently selected tab
    if (index != _currentIndex) {
      return const SizedBox.shrink();
    }

    switch (index) {
      case 0:
        return const PaymentReportFrame();
      case 1:
        return const StockReportFrame();
      case 2:
        return ReportRunnerWidget(agent: widget.sqlAgent);
      case 3:
        return ProfitLossScreen(
          controller: ProfitLossUIController(
            ProfitLossRepository(ProfitLossDao(), ManualEntryDao()),
          ),
        );
      default:
        return const Center(child: Text('Unknown tab'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reports Dashboard"),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: "Payments"),
            Tab(text: "Stock Report"),
            Tab(text: "AI Reports"),
            Tab(text: "Profit and Loss"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(4, (index) => _buildTabContent(index)),
      ),
    );
  }
}
