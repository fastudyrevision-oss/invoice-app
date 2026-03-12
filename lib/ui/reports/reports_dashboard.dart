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
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.payments_outlined, size: 18),
                  SizedBox(width: 8),
                  Text("Payments"),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.inventory_2_outlined, size: 18),
                  SizedBox(width: 8),
                  Text("Stock Report"),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.auto_awesome, size: 18),
                  SizedBox(width: 8),
                  Text("AI Reports"),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.account_balance_wallet_outlined, size: 18),
                  SizedBox(width: 8),
                  Text("Profit and Loss"),
                ],
              ),
            ),
          ],
        ),
      ),
      body: AnimatedSwitcher(
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
            child: SlideTransition(position: slideTransition, child: child),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: _buildTabContent(_currentIndex),
        ),
      ),
    );
  }
}
