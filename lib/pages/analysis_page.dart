import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/storage_service.dart';
import '../models/god.dart';
import 'full_analysis_page.dart';

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

  Map<String, int> _getFilteredCounts(String range) {
    final now = DateTime.now();
    final Map<String, int> totals = {};

    dailyData.forEach((dateString, godsMap) {
      final date = DateTime.tryParse(dateString.trim());
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

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _statsHeader(int total, double avg) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statBox("Total Count", total.toString()),
          Container(width: 1, height: 40, color: Colors.grey.shade300),
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
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      ],
    );
  }

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
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
      child: Container(
        height: 280,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.only(
          top: 20,
          left: 10,
          right: 10,
          bottom: 20,
        ),
        child: BarChart(
          BarChartData(
            maxY: maxY + 5,
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
                  reservedSize: 40, // prevents clipping
                  getTitlesWidget: (value, meta) {
                    int index = value.toInt();
                    if (index < 0 || index >= labels.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        labels[index],
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
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
                    width: 22,
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFC107), Colors.black],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
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
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FullAnalysisPage()),
              );
            },
            icon: const Icon(Icons.analytics_outlined, color: Colors.white),
            label: const Text(
              "Full Analysis",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 5,
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFD),
      appBar: AppBar(
        title: const Text(
          "Naam Jap Stats",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.4,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.amber.shade700,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
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
                  _buildTabContent('daily', "Today's Stats"),
                  _buildTabContent('monthly', "Last 30 Days"),
                  _buildTabContent('yearly', "This Year"),
                ],
              ),
    );
  }
}
