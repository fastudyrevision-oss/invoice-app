// flutter_gemini_sql_agent.dart
// Ready-to-drop-in service + UI + samples for embedding a Gemini-backed SQL agent
// Works with your DatabaseHelper (sqflite/sembast) pasted earlier.

/*
  Instructions:
  1) Add these to pubspec.yaml:
     dependencies:
       http: ^0.13.6
       fl_chart: ^0.60.0

  2) Place this file (or split into service/ui files) and import where needed.
  3) Set GEMINI_API_KEY and GEMINI_API_URL below.
  4) Ensure DatabaseHelper.instance.init() was called (app start).
*/

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../db/database_helper.dart'; // <-- your DatabaseHelper file from earlier
import 'package:fl_chart/fl_chart.dart';

// ----------------------------- CONFIG -----------------------------
// ignore: constant_identifier_names
const String GEMINI_API_KEY = 'AIzaSyBy3QugqiTbqzlS3yxKAvO5JfOHilAU7yY';
// ignore: constant_identifier_names
const String GEMINI_API_URL =
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$GEMINI_API_KEY';
// Replace GEMINI_API_URL with your provider's HTTP endpoint for Gemini (per your docs)

// ----------------------------- SQL SAFETY -----------------------------
bool isSafeSelectSql(String sql) {
  final cleaned = sql.trim().toLowerCase();
  // block obvious dangerous tokens and semicolons
  final forbidden = [
    'insert ',
    'update ',
    'delete ',
    'drop ',
    'alter ',
    'create ',
    'attach ',
    'pragma',
    ';',
  ];
  for (final f in forbidden) {
    if (cleaned.contains(f)) return false;
  }
  // allow only SELECT or WITH
  return cleaned.startsWith('select') || cleaned.startsWith('with');
}

// Minimal clean-up: strip surrounding backticks and trailing text
String normalizeSql(String raw) {
  var s = raw.trim();
  // remove ```sql fences or ```
  if (s.startsWith('```')) {
    s = s.replaceAll(RegExp(r"^```(?:sql)?"), '');
    s = s.replaceAll(RegExp(r"```\s*\$"), '');
  }
  // sometimes models append explanation; keep only up to two newlines after final SELECT block
  // simple heuristic: if there's an extra line after the last parenthesis, remove it
  return s.trim();
}

// ----------------------------- GEMINI SERVICE -----------------------------
class GeminiService {
  final String apiKey;
  final String apiUrl;

  GeminiService({required this.apiKey, required this.apiUrl});

  /// Sends the prompt to Gemini (HTTP). Adjust payload per your Gemini provider.
  Future<String> generateSql(String prompt, {int maxTokens = 512}) async {
    final uri = Uri.parse(apiUrl);
    final body = {
      // The exact shape depends on your Gemini HTTP API. This is a generic example.
      'prompt': prompt,
      'max_tokens': maxTokens,
      'temperature': 0.0,
      'stop': null,
    };

    final resp = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (resp.statusCode >= 400) {
      throw Exception('Gemini error ${resp.statusCode}: ${resp.body}');
    }

    final jsonResp = jsonDecode(resp.body);

    // Try common response shapes (adjust to match your provider):
    String? text;
    if (jsonResp['choices'] != null && jsonResp['choices'].isNotEmpty) {
      text =
          jsonResp['choices'][0]['text'] ??
          jsonResp['choices'][0]['message']?['content'];
    } else if (jsonResp['output'] != null) {
      // some providers return `output` or `candidates`
      if (jsonResp['output'] is String) {
        text = jsonResp['output'];
      } else if (jsonResp['output'] is List && jsonResp['output'].isNotEmpty) {
        text = jsonResp['output'][0]['content'];
      }
    } else if (jsonResp['generated_text'] != null) {
      text = jsonResp['generated_text'];
    }

    text ??= resp.body;

    final normalized = normalizeSql(text);
    return normalized;
  }
}

// ----------------------------- AGENT SERVICE -----------------------------
class SqlAgentService {
  final GeminiService gemini;
  final DatabaseHelper dbHelper;

  SqlAgentService({required this.gemini, required this.dbHelper});

  /// Build a compact schema snippet tailored to the user's question to keep prompts small.
  String buildSchemaSnippet() {
    return '''
-- Schema snippet (SQLite):
expenses(id, description, category, amount, date, created_at)
invoices(id, customer_id, customer_name, total, discount, tax, paid, pending, status, date)
invoice_items(id, invoice_id, product_id, qty, price, discount, tax)
customers(id, name, phone, email, pending_amount)
products(id, name, sku, cost_price, sell_price, quantity)
''';
  }

  String sqlGeneratorPrompt(String userQuestion) {
    return '''
You are a SQL generator for an SQLite database.\n
Rules:\n- Return ONLY one SQL SELECT statement (or WITH ... SELECT). No explanations.\n- Do NOT return INSERT/UPDATE/DELETE/CREATE/ALTER/DROP/ATTACH/PRAGMA statements.\n- Use SQLite date functions (strftime) for grouping by day/week/month/year.\n- Use ISO8601 formatted dates stored in TEXT columns.\n- Limit results to 1000 rows unless the user asks for more.\n
${buildSchemaSnippet()}\nUser question:\n$userQuestion\n''';
  }

  /// Generate SQL (via Gemini) and run it (if safe). Returns rows.
  Future<List<Map<String, dynamic>>> askAndRun(String userQuestion) async {
    // Build prompt & call Gemini
    final prompt = sqlGeneratorPrompt(userQuestion);
    final raw = await gemini.generateSql(prompt);
    final sql = normalizeSql(raw);

    if (!isSafeSelectSql(sql)) {
      throw Exception('Generated SQL failed safety checks. SQL: $sql');
    }

    // Run the SQL using the helper (handles web vs mobile automatically)
    final rows = await dbHelper.rawQuery(sql);
    return List<Map<String, dynamic>>.from(rows);
  }
}

// ----------------------------- UI WIDGET -----------------------------
class ReportRunnerWidget extends StatefulWidget {
  final SqlAgentService agent;
  const ReportRunnerWidget({required this.agent, super.key});

  @override
  State<ReportRunnerWidget> createState() => _ReportRunnerWidgetState();
}

class _ReportRunnerWidgetState extends State<ReportRunnerWidget> {
  String _selectedPeriod = 'monthly';
  List<Map<String, dynamic>> _rows = [];
  bool _loading = false;
  String _lastSql = '';
  String _error = '';

  final TextEditingController _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _runTemplate(String period) async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final sql = _aggregatorSql(period: period, table: 'expenses');
      _lastSql = sql;

      final rows = await widget.agent.dbHelper.rawQuery(sql);
      setState(() {
        _rows = List<Map<String, dynamic>>.from(rows);
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _runNaturalQuery() async {
    final userQuery = _queryController.text.trim();
    if (userQuery.isEmpty) return;
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final rows = await widget.agent.askAndRun(userQuery);
      setState(() {
        _rows = rows;
        _lastSql = '<generated by Gemini>';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: ['daily', 'weekly', 'monthly', 'yearly'].map((p) {
            final isSel = p == _selectedPeriod;
            return ChoiceChip(
              label: Text(p[0].toUpperCase() + p.substring(1)),
              selected: isSel,
              onSelected: (v) {
                if (!v) return;
                setState(() => _selectedPeriod = p);
                _runTemplate(p);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _queryController,
                decoration: InputDecoration(
                  labelText:
                      'Ask (e.g. "Top 5 customers by invoice total this year")',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _runNaturalQuery(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _runNaturalQuery, child: Text('Run')),
          ],
        ),

        const SizedBox(height: 12),
        if (_loading) LinearProgressIndicator(),
        if (_error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text('Error: $_error', style: TextStyle(color: Colors.red)),
          ),

        // SQL preview
        if (_lastSql.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'SQL: $_lastSql',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ),

        // Data table
        Expanded(
          child: _rows.isEmpty
              ? Center(child: Text('No rows'))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: _rows.first.keys
                        .map((k) => DataColumn(label: Text(k)))
                        .toList(),
                    rows: _rows.map((r) {
                      return DataRow(
                        cells: r.values
                            .map((v) => DataCell(Text(v?.toString() ?? '')))
                            .toList(),
                      );
                    }).toList(),
                  ),
                ),
        ),

        // Chart (if rows contain 'period' and 'total_amount' numeric)
        if (_rows.isNotEmpty &&
            _rows.first.containsKey('period') &&
            _rows.first.containsKey('total_amount'))
          SizedBox(
            height: 200,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: LineChart(_buildLineChart()),
            ),
          ),
      ],
    );
  }

  LineChartData _buildLineChart() {
    final points = <FlSpot>[];
    for (var i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      final y = (r['total_amount'] is num)
          ? (r['total_amount'] as num).toDouble()
          : double.tryParse(r['total_amount'].toString()) ?? 0.0;
      points.add(FlSpot(i.toDouble(), y));
    }

    return LineChartData(
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
      ),
      gridData: FlGridData(show: true),
      borderData: FlBorderData(show: true),
      lineBarsData: [
        LineChartBarData(
          spots: points,
          isCurved: true,
          dotData: FlDotData(show: false),
        ),
      ],
    );
  }

  // ----------------- Aggregator SQL Template (local fallback) -----------------
  String _aggregatorSql({required String period, required String table}) {
    String selectDate;
    String groupBy;
    switch (period) {
      case 'daily':
        selectDate = "strftime('%Y-%m-%d', date) as period";
        groupBy = "strftime('%Y-%m-%d', date)";
        break;
      case 'weekly':
        selectDate = "strftime('%Y-%W', date) as period";
        groupBy = "strftime('%Y-%W', date)";
        break;
      case 'monthly':
        selectDate = "strftime('%Y-%m', date) as period";
        groupBy = "strftime('%Y-%m', date)";
        break;
      case 'yearly':
        selectDate = "strftime('%Y', date) as period";
        groupBy = "strftime('%Y', date)";
        break;
      default:
        selectDate = "strftime('%Y-%m', date) as period";
        groupBy = "strftime('%Y-%m', date)";
    }

    return '''
      SELECT $selectDate, SUM(amount) AS total_amount, COUNT(*) AS count
      FROM $table
      WHERE date IS NOT NULL
      GROUP BY $groupBy
      ORDER BY $groupBy DESC
      LIMIT 1000
    ''';
  }
}

// ----------------------------- SAMPLE QUERIES + EXPECTED SQLS -----------------------------

/*
Sample queries and example SQL outputs (use for testing / quick-run):

1) "Invoices this year grouped by month"
Expected SQL:
SELECT strftime('%Y-%m', date) AS period, SUM(total) AS total_invoiced, COUNT(*) AS invoice_count
FROM invoices
WHERE date LIKE '2025-%'
GROUP BY strftime('%Y-%m', date)
ORDER BY period DESC
LIMIT 1000;

2) "Top 5 customers by invoice total this year"
Expected SQL:
SELECT c.id, c.name, SUM(i.total) AS total_invoiced, COUNT(i.id) AS invoice_count
FROM customers c
JOIN invoices i ON i.customer_id = c.id
WHERE i.date LIKE '2025-%'
GROUP BY c.id, c.name
ORDER BY total_invoiced DESC
LIMIT 5;

3) "Product stock warnings: products with quantity <= min_stock"
Expected SQL:
SELECT id, name, sku, quantity, min_stock
FROM products
WHERE quantity <= min_stock
ORDER BY quantity ASC;

4) "Expense breakdown by category last 12 months"
Expected SQL:
SELECT category, SUM(amount) AS total_amount, COUNT(*) AS count
FROM expenses
WHERE date >= date('now','-12 months')
GROUP BY category
ORDER BY total_amount DESC
LIMIT 1000;

Use these to verify agent correctness.
*/

// ----------------------------- USAGE EXAMPLE -----------------------------
// In your app's init (main):
// await DatabaseHelper.instance.init();
// final gemini = GeminiService(apiKey: GEMINI_API_KEY, apiUrl: GEMINI_API_URL);
// final agent = SqlAgentService(gemini: gemini, dbHelper: DatabaseHelper.instance);
// Then use ReportRunnerWidget(agent: agent) inside a Scaffold body.
