import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/storage_service.dart';
import '../models/god.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({Key? key}) : super(key: key);

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic> dailyData = {};
  Map<String, String> godNames = {};
  bool isLoading = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    final gods = await StorageService.loadGods();
    final data = await StorageService.loadDailyCounts();
    setState(() {
      godNames = {for (var g in gods) g.id: g.name};
      dailyData = data;
      isLoading = false;
    });
  }

  /// --- FILTER DATA BY RANGE ---
  Map<String, int> _getFilteredCounts(String range) {
    final now = DateTime.now();
    final Map<String, int> totals = {};

    dailyData.forEach((dateString, godsMap) {
      final cleanDateString = dateString.trim(); // normalize
      final date = DateTime.tryParse(cleanDateString);
      if (date == null) return;
      bool include = false;

      if (range == 'daily') {
        include =
            DateFormat('yyyy-MM-dd').format(date) ==
            DateFormat('yyyy-MM-dd').format(now);
      } else if (range == 'monthly') {
        include = date.isAfter(now.subtract(const Duration(days: 30)));
      } else if (range == 'yearly') {
        include = date.isAfter(now.subtract(const Duration(days: 365)));
      }

      if (include && godsMap is Map) {
        (godsMap as Map).forEach((godId, count) {
          final int value =
              (count is int) ? count : int.tryParse(count.toString()) ?? 0;
          totals[godId] = (totals[godId] ?? 0) + value;
        });
      }
    });

    totals.removeWhere((_, c) => c == 0);
    return totals;
  }

  /// --- SECTION TITLE ---
  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }

  /// --- STATS HEADER ---
  Widget _statsHeader(int total, double avg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _statBox("Total Count", total.toString()),
          const SizedBox(width: 40),
          _statBox("Avg/Entry", avg.toStringAsFixed(0)),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      ],
    );
  }

  /// --- BAR CHART ---
  Widget _barChart(Map<String, int> totals) {
    if (totals.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Text('No data available', style: TextStyle(color: Colors.grey)),
      );
    }

    final counts = totals.values.toList();
    final labels = totals.keys.map((k) => godNames[k] ?? k).toList();
    final maxY = counts.reduce(math.max).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: SizedBox(
        height: 240,
        child: BarChart(
          BarChartData(
            maxY: maxY + 5, // smooth top spacing
            gridData: FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    int index = value.toInt();
                    if (index < 0 || index >= labels.length) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(
                        labels[index],
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: List.generate(counts.length, (i) {
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: counts[i].toDouble(),
                    width: 16,
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.9),
                        Colors.grey.shade600,
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }


  Widget _buildTabContent(String range, String title) {
    final totals = _getFilteredCounts(range);
    final totalCount = totals.values.fold<int>(0, (a, b) => a + b);
    final avg = totals.isNotEmpty ? totalCount / totals.length : 0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _sectionTitle(title),
          _statsHeader(totalCount, avg.toDouble()),
          _barChart(totals),

        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Naam Jap Stats",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.black,
          tabs: const [
            Tab(text: "Daily"),
            Tab(text: "Monthly"),
            Tab(text: "Yearly"),
          ],
        ),
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                controller: _tabController,
                children: [
                  _buildTabContent('daily', "This Week"),
                  _buildTabContent('monthly', "Last 30 Days"),
                  _buildTabContent('yearly', "This Year"),
                ],
              ),
    );
  }
}
