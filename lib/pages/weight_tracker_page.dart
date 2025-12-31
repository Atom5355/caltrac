import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';

enum TimeFilter { oneMonth, threeMonths, sixMonths, oneYear, all }

class WeightTrackerPage extends StatefulWidget {
  const WeightTrackerPage({super.key});

  @override
  State<WeightTrackerPage> createState() => _WeightTrackerPageState();
}

class _WeightTrackerPageState extends State<WeightTrackerPage> {
  List<Map<String, dynamic>> _weightLogs = [];
  bool _isLoading = true;
  TimeFilter _selectedFilter = TimeFilter.threeMonths;
  double? _latestWeight;
  double? _startWeight;
  double? _lowestWeight;
  double? _highestWeight;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  DateTime _getStartDateForFilter(TimeFilter filter) {
    final now = DateTime.now();
    switch (filter) {
      case TimeFilter.oneMonth:
        return now.subtract(const Duration(days: 30));
      case TimeFilter.threeMonths:
        return now.subtract(const Duration(days: 90));
      case TimeFilter.sixMonths:
        return now.subtract(const Duration(days: 180));
      case TimeFilter.oneYear:
        return now.subtract(const Duration(days: 365));
      case TimeFilter.all:
        return DateTime(2020); // Far back enough to get all data
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final startDate = _getStartDateForFilter(_selectedFilter);
      final logs = await SupabaseService.getWeightLogs(
        startDate: _selectedFilter == TimeFilter.all ? null : startDate,
      );

      double? latest;
      double? start;
      double? lowest;
      double? highest;

      if (logs.isNotEmpty) {
        latest = (logs.last['weight_lbs'] as num).toDouble();
        start = (logs.first['weight_lbs'] as num).toDouble();
        lowest = logs
            .map((l) => (l['weight_lbs'] as num).toDouble())
            .reduce((a, b) => a < b ? a : b);
        highest = logs
            .map((l) => (l['weight_lbs'] as num).toDouble())
            .reduce((a, b) => a > b ? a : b);
      }

      setState(() {
        _weightLogs = logs;
        _latestWeight = latest;
        _startWeight = start;
        _lowestWeight = lowest;
        _highestWeight = highest;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddWeightDialog() {
    final controller = TextEditingController();
    final today = DateTime.now();
    final isSunday = today.weekday == DateTime.sunday;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        title: const Text('Log Weight', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isSunday)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tip: Log your weight on Sundays for weekly tracking!',
                        style: TextStyle(color: Colors.orange.shade200, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Weight (lbs)',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                suffixText: 'lbs',
                suffixStyle: const TextStyle(color: Color(0xFF00E676)),
                filled: true,
                fillColor: const Color(0xFF0A0E21),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00E676)),
                ),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          ElevatedButton(
            onPressed: () async {
              final weight = double.tryParse(controller.text);
              if (weight != null && weight > 0) {
                Navigator.pop(context);
                try {
                  await SupabaseService.logWeight(weightLbs: weight);
                  _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Weight logged!'),
                        backgroundColor: const Color(0xFF00E676),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A0E21),
              Color(0xFF1A1A2E),
              Color(0xFF0A0E21),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        color: const Color(0xFF00E676),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              _buildCurrentWeight(),
                              const SizedBox(height: 20),
                              _buildTimeFilters(),
                              const SizedBox(height: 20),
                              _buildChart(),
                              const SizedBox(height: 20),
                              _buildStats(),
                              const SizedBox(height: 20),
                              _buildWeightHistory(),
                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddWeightDialog,
        backgroundColor: const Color(0xFF00E676),
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('Log Weight', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1D1E33),
                border: Border.all(color: const Color(0xFF00E676).withOpacity(0.3)),
              ),
              child: const Icon(Icons.arrow_back, color: Color(0xFF00E676), size: 20),
            ),
          ),
          const Expanded(
            child: Text(
              'Weight Tracker',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildCurrentWeight() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D1E33), Color(0xFF2D2D44)],
        ),
      ),
      child: Column(
        children: [
          Text(
            'Current Weight',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _latestWeight?.toStringAsFixed(1) ?? '--',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00E676),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8, left: 4),
                child: Text('lbs', style: TextStyle(color: Colors.white54, fontSize: 18)),
              ),
            ],
          ),
          if (_latestWeight != null && _startWeight != null) ...[
            const SizedBox(height: 12),
            _buildWeightChange(),
          ],
        ],
      ),
    );
  }

  Widget _buildWeightChange() {
    final change = _latestWeight! - _startWeight!;
    final isLoss = change < 0;
    final color = isLoss ? const Color(0xFF00E676) : Colors.red;
    final icon = isLoss ? Icons.trending_down : Icons.trending_up;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            '${isLoss ? '' : '+'}${change.toStringAsFixed(1)} lbs',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          Text(
            ' in ${_getFilterLabel(_selectedFilter).toLowerCase()}',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: TimeFilter.values.map((filter) {
          final isSelected = filter == _selectedFilter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedFilter = filter);
                _loadData();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isSelected ? const Color(0xFF00E676) : const Color(0xFF1D1E33),
                ),
                child: Text(
                  _getFilterLabel(filter),
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white.withOpacity(0.7),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getFilterLabel(TimeFilter filter) {
    switch (filter) {
      case TimeFilter.oneMonth:
        return '1 Month';
      case TimeFilter.threeMonths:
        return '3 Months';
      case TimeFilter.sixMonths:
        return '6 Months';
      case TimeFilter.oneYear:
        return '1 Year';
      case TimeFilter.all:
        return 'All Time';
    }
  }

  Widget _buildChart() {
    if (_weightLogs.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF1D1E33),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.show_chart, size: 48, color: Colors.white.withOpacity(0.2)),
              const SizedBox(height: 12),
              Text(
                'No weight data yet',
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
              const SizedBox(height: 4),
              Text(
                'Start logging your weight!',
                style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final spots = _weightLogs.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        (entry.value['weight_lbs'] as num).toDouble(),
      );
    }).toList();

    final minY = (_lowestWeight ?? 0) - 5;
    final maxY = (_highestWeight ?? 200) + 5;

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF1D1E33),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 10,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.white.withOpacity(0.1),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: 10,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: _weightLogs.length > 10 ? (_weightLogs.length / 5).ceil().toDouble() : 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= _weightLogs.length) return const Text('');
                  final date = DateTime.parse(_weightLogs[index]['logged_at']);
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('M/d').format(date),
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (_weightLogs.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: const Color(0xFF00E676),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: const Color(0xFF00E676),
                    strokeWidth: 2,
                    strokeColor: const Color(0xFF0A0E21),
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF00E676).withOpacity(0.3),
                    const Color(0xFF00E676).withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => const Color(0xFF2D2D44),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.spotIndex;
                  final log = _weightLogs[index];
                  final date = DateTime.parse(log['logged_at']);
                  return LineTooltipItem(
                    '${spot.y.toStringAsFixed(1)} lbs\n${DateFormat('MMM d, yyyy').format(date)}',
                    const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStats() {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Lowest', _lowestWeight, const Color(0xFF00E676))),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Highest', _highestWeight, Colors.orange)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Entries', _weightLogs.length.toDouble(), Colors.blue)),
      ],
    );
  }

  Widget _buildStatCard(String label, double? value, Color color) {
    final isCount = label == 'Entries';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF1D1E33),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            value != null
                ? (isCount ? value.toInt().toString() : '${value.toStringAsFixed(1)}')
                : '--',
            style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (!isCount)
            Text('lbs', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildWeightHistory() {
    if (_weightLogs.isEmpty) return const SizedBox.shrink();

    final reversedLogs = _weightLogs.reversed.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Entries',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...reversedLogs.map((log) {
          final date = DateTime.parse(log['logged_at']);
          final weight = (log['weight_lbs'] as num).toDouble();
          final isSunday = date.weekday == DateTime.sunday;

          return Dismissible(
            key: Key(log['id'].toString()),
            direction: DismissDirection.endToStart,
            background: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.red,
              ),
              alignment: Alignment.centerRight,
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (direction) async {
              return await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1D1E33),
                  title: const Text('Delete Entry', style: TextStyle(color: Colors.white)),
                  content: const Text(
                    'Are you sure you want to delete this weight entry?',
                    style: TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Delete', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
            onDismissed: (direction) async {
              await SupabaseService.deleteWeightLog(log['id'].toString());
              _loadData();
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF1D1E33),
                border: isSunday
                    ? Border.all(color: const Color(0xFF00E676).withOpacity(0.3))
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: const Color(0xFF00E676).withOpacity(0.15),
                    ),
                    child: const Icon(Icons.monitor_weight, color: Color(0xFF00E676), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE, MMM d, yyyy').format(date),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                        ),
                        if (isSunday)
                          Text(
                            'Weekly weigh-in',
                            style: TextStyle(color: const Color(0xFF00E676).withOpacity(0.7), fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${weight.toStringAsFixed(1)} lbs',
                    style: const TextStyle(
                      color: Color(0xFF00E676),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
