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

class _AnalysisPageState extends State<AnalysisPage> {
  Map<String, dynamic> dailyData = {};
  Map<String, String> godNames = {};
  String selectedRange = 'today';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
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

  Map<String, int> _getFilteredCounts() {
    final now = DateTime.now();
    final Map<String, int> totals = {};

    dailyData.forEach((dateString, godsMap) {
      final date = DateTime.tryParse(dateString);
      if (date == null) return;

      bool include = false;
      if (selectedRange == 'today') {
        include = DateFormat('yyyy-MM-dd').format(date) ==
            DateFormat('yyyy-MM-dd').format(now);
      } else if (selectedRange == '7days') {
        include = date.isAfter(now.subtract(const Duration(days: 7)));
      } else if (selectedRange == '3months') {
        include = date.isAfter(DateTime(now.year, now.month - 3, now.day));
      } else if (selectedRange == 'all') {
        include = true;
      }

      if (include && godsMap is Map) {
        (godsMap as Map).forEach((godId, count) {
          final int value =
              (count is int) ? count : int.tryParse(count.toString()) ?? 0;
          totals[godId] = (totals[godId] ?? 0) + value;
        });
      }
    });

    totals.removeWhere((_, count) => count == 0);
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    final totals = _getFilteredCounts();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis'),
        centerTitle: true,
        backgroundColor: Colors.purple.shade50,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Range buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _rangeButton('Today', 'today'),
                      _rangeButton('7 Days', '7days'),
                      _rangeButton('3 Months', '3months'),
                      _rangeButton('All', 'all'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Expanded(
                    child: totals.isEmpty
                        ? const Center(
                            child: Text(
                              'No data available for this period.',
                              style: TextStyle(fontSize: 14),
                            ),
                          )
                        : Column(
                            children: [
                              Expanded(
                                child: BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.spaceAround,
                                    borderData: FlBorderData(show: false),
                                    gridData:  FlGridData(show: true),
                                    titlesData: FlTitlesData(
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 40,
                                          getTitlesWidget: (value, meta) {
                                            final exp = math.exp(value) - 1;
                                            return Text(
                                              exp.toInt().toString(),
                                              style: const TextStyle(fontSize: 10),
                                            );
                                          },
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            final index = value.toInt();
                                            if (index < 0 ||
                                                index >= totals.keys.length) {
                                              return const SizedBox.shrink();
                                            }
                                            final godId =
                                                totals.keys.elementAt(index);
                                            final godName =
                                                godNames[godId] ?? godId;
                                            return SideTitleWidget(
                                              axisSide: meta.axisSide,
                                              child: Text(
                                                godName,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      rightTitles:  AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false),
                                      ),
                                      topTitles:  AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false),
                                      ),
                                    ),
                                    barGroups:
                                        List.generate(totals.length, (index) {
                                      final count =
                                          totals.values.elementAt(index);
                                      final normalized =
                                          (count > 0) ? math.log(count + 1) : 0;
                                      return BarChartGroupData(
                                        x: index,
                                        barRods: [
                                          BarChartRodData(
                                            toY: normalized.toDouble(),
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.purple.shade400,
                                                Colors.purple.shade800
                                              ],
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                            ),
                                            width: 20,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                        ],
                                      );
                                    }),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Bar height shown in log scale for better comparison',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _rangeButton(String label, String value) {
    final isSelected = selectedRange == value;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          selectedRange = value;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isSelected ? Colors.purple.shade400 : Colors.purple.shade100,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}
