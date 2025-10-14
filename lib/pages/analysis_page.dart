// lib/pages/analysis_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/god_provider.dart';
import '../services/storage_service.dart';
import '../models/god.dart';

class AnalysisPage extends ConsumerStatefulWidget {
  const AnalysisPage({super.key});

  @override
  ConsumerState<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends ConsumerState<AnalysisPage> {
  Map<String, dynamic> dailyData = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await StorageService.loadDailyCounts();
    setState(() {
      dailyData = data;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final gods = ref.watch(godListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Analysis'), centerTitle: true),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📅 Daily Tap Summary',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // show gods
                    Wrap(
                      spacing: 8,
                      children:
                          gods
                              .map(
                                (god) => Chip(
                                  label: Text(god.name),
                                  avatar: const Icon(Icons.person, size: 16),
                                ),
                              )
                              .toList(),
                    ),
                    const SizedBox(height: 20),

                    // Debug container
                    const Text(
                      '🧩 DebugContainer (Daily Data)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                      child: Text(
                        const JsonEncoder.withIndent('  ').convert(dailyData),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Chart Section
                    if (dailyData.isNotEmpty)
                      ..._buildCharts(gods)
                    else
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            'No data yet — start tapping!',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 30),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reload Data'),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  // Create charts per date
  List<Widget> _buildCharts(List<God> gods) {
    final List<Widget> charts = [];

    // sort dates (latest first)
    final sortedDates = dailyData.keys.toList()..sort((a, b) => b.compareTo(a));

    for (var date in sortedDates) {
      final dayData = dailyData[date] as Map<String, dynamic>;

      // create bar chart groups
      final List<BarChartGroupData> barGroups = [];
      int index = 0;
      for (var god in gods) {
        final count = (dayData[god.id] ?? 0).toDouble();
        barGroups.add(
          BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: count,
                color: Colors.deepPurple,
                width: 16,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        );
        index++;
      }

      charts.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              '📊 $date',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            AspectRatio(
              aspectRatio: 1.7,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _findMaxY(dayData),
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                      ),
                    ),
                    rightTitles:  AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles:  AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= gods.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              gods[value.toInt()].name,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData:  FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return charts;
  }

  double _findMaxY(Map<String, dynamic> dayData) {
    if (dayData.isEmpty) return 10;
    final values = dayData.values.map((e) => (e as num).toDouble()).toList();
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    return maxVal + 5; // small padding on top
  }
}
