import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/logger_service.dart';

class LogsFrame extends StatefulWidget {
  const LogsFrame({super.key});

  @override
  State<LogsFrame> createState() => _LogsFrameState();
}

class _LogsFrameState extends State<LogsFrame> {
  final LoggerService _logger = LoggerService.instance;
  List<LogEntry> _logs = [];
  List<LogEntry> _filteredLogs = [];

  // Filters
  String _searchQuery = '';
  LogLevel? _selectedLevel;
  bool _autoScroll = true;
  bool _showPerformance = false;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLogs();

    // Auto-refresh logs every second if live view is on
    _startAutoRefresh();
  }

  void _startAutoRefresh() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted && _autoScroll) {
        _loadLogs();
      }
    }
  }

  void _loadLogs() {
    final allLogs = _logger.getAllLogs();

    setState(() {
      _logs = allLogs;
      _applyFilters();
    });

    if (_autoScroll && _scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _applyFilters() {
    _filteredLogs = _logs.where((log) {
      // Filter by Level
      if (_selectedLevel != null && log.level.index < _selectedLevel!.index) {
        return false;
      }

      // Filter by Search
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesMessage = log.message.toLowerCase().contains(query);
        final matchesTag = log.tag.toLowerCase().contains(query);
        final matchesError = log.formatWithTrace().toLowerCase().contains(
          query,
        );

        return matchesMessage || matchesTag || matchesError;
      }

      return true;
    }).toList();
  }

  void _exportLogs() async {
    final file = await _logger.exportLogs();
    if (mounted && file != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Logs exported to ${file.path}'),
          action: SnackBarAction(
            label: 'Copy Path',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: file.path));
            },
          ),
        ),
      );
    }
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Colors.grey;
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
      case LogLevel.critical:
        return Colors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Logs'),
        actions: [
          IconButton(
            icon: Icon(
              _autoScroll
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
            ),
            color: _autoScroll ? Colors.green : Colors.grey,
            tooltip: _autoScroll ? 'Pause Live View' : 'Resume Live View',
            onPressed: () {
              setState(() => _autoScroll = !_autoScroll);
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Export Logs',
            onPressed: _exportLogs,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear Logs',
            onPressed: () {
              _logger.clearLogs();
              _loadLogs();
            },
          ),
          IconButton(
            icon: Icon(_showPerformance ? Icons.timer : Icons.timer_outlined),
            tooltip: 'Performance metrics',
            onPressed: () =>
                setState(() => _showPerformance = !_showPerformance),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.all(8),
            color: isDark ? Colors.black12 : Colors.grey.shade100,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search logs...',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _applyFilters();
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                        _applyFilters();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<LogLevel?>(
                  initialValue: _selectedLevel,
                  icon: const Icon(Icons.filter_list),
                  tooltip: 'Filter by Level',
                  onSelected: (level) {
                    setState(() {
                      _selectedLevel = level;
                      _applyFilters();
                    });
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: null, child: Text('All Levels')),
                    const PopupMenuItem(
                      value: LogLevel.info,
                      child: Text('Info+'),
                    ),
                    const PopupMenuItem(
                      value: LogLevel.warning,
                      child: Text('Warning+'),
                    ),
                    const PopupMenuItem(
                      value: LogLevel.error,
                      child: Text('Error+'),
                    ),
                    const PopupMenuItem(
                      value: LogLevel.critical,
                      child: Text('Critical Only'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_showPerformance)
            Container(
              height: 100,
              padding: const EdgeInsets.all(8),
              color: Colors.blue.withOpacity(0.1),
              child: LogPerformanceView(
                metrics: _logger.getPerformanceMetrics(),
              ),
            ),

          // Log List
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              itemCount: _filteredLogs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final log = _filteredLogs[index];
                return InkWell(
                  onTap: () => _showLogDetails(log),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    color: log.level.index >= LogLevel.error.index
                        ? Colors.red.withOpacity(0.05)
                        : null,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Timestamp
                        Text(
                          '${log.timestamp.hour}:${log.timestamp.minute}:${log.timestamp.second}',
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Level Indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getLevelColor(log.level),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            log.level
                                .toString()
                                .split('.')
                                .last
                                .toUpperCase()
                                .substring(0, 1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Tag
                        SizedBox(
                          width: 80,
                          child: Text(
                            log.tag,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey.shade300
                                  : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Message
                        Expanded(
                          child: Text(
                            log.message,
                            style: TextStyle(
                              fontSize: 13,
                              fontFamily: Platform.isWindows
                                  ? 'Consolas'
                                  : 'Courier',
                              color: log.level.index >= LogLevel.error.index
                                  ? Colors.red
                                  : null,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showLogDetails(LogEntry log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              log.level.index >= LogLevel.error.index
                  ? Icons.error
                  : Icons.info,
              color: _getLevelColor(log.level),
            ),
            const SizedBox(width: 8),
            const Text('Log Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Timestamp: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: '${log.timestamp}\n\n'),

                    const TextSpan(
                      text: 'Level: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: '${log.level}\n\n'),

                    const TextSpan(
                      text: 'Tag: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: '${log.tag}\n\n'),

                    const TextSpan(
                      text: 'Message:\n',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: '${log.message}\n\n'),

                    if (log.context != null) ...[
                      const TextSpan(
                        text: 'Context:\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: '${log.context}\n\n'),
                    ],

                    if (log.stackTrace != null) ...[
                      const TextSpan(
                        text: 'Stack Trace:\n',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      TextSpan(
                        text: log.stackTrace,
                        style: const TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: log.formatWithTrace()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Log copied to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class LogPerformanceView extends StatelessWidget {
  final Map<String, Duration> metrics;

  const LogPerformanceView({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) {
      return const Center(child: Text('No performance metrics yet'));
    }

    return ListView.builder(
      itemCount: metrics.length,
      itemBuilder: (context, index) {
        final key = metrics.keys.elementAt(index);
        final duration = metrics[key]!;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(key, style: const TextStyle(fontSize: 12)),
            Text(
              '${duration.inMilliseconds}ms',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: duration.inMilliseconds > 500
                    ? Colors.red
                    : Colors.green,
              ),
            ),
          ],
        );
      },
    );
  }
}
