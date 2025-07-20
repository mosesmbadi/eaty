import 'package:flutter/material.dart';

import 'package:flutter/material.dart';
import '../db/meal_database.dart';
import '../db/meal_database.dart';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<String> categories = ['Carbs', 'Proteins', 'Vitamins'];

  Future<void> _generateMeal() async {
    final random = Random();
    List<String> selectedFoods = [];
    for (var cat in categories) {
      final foods = await MealDatabase.instance.getMealsByCategory(cat);
      if (foods.isNotEmpty) {
        final food = foods[random.nextInt(foods.length)];
        selectedFoods.add(food.name);
      }
    }
    if (selectedFoods.length < 3) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Not enough foods'),
          content: const Text('Please add at least one food in each category (Carbs, Proteins, Vitamins).'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      return;
    }
    final mealName = selectedFoods.join(', ');
    // Save generated meal
    await MealDatabase.instance.insertMeal(Meal(name: mealName, category: 'Generated', date: DateTime.now().toIso8601String()));
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generated Meal'),
        content: Text(mealName),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  String _period = 'Day';
  DateTime _selectedDate = DateTime.now();
  Map<String, int> _categoryCounts = {'Carbs': 0, 'Proteins': 0, 'Vitamins': 0};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchCategoryCounts();
  }

  Future<void> _fetchCategoryCounts() async {
    setState(() => _loading = true);
    DateTime start, end;
    if (_period == 'Day') {
      start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      end = start.add(const Duration(days: 1));
    } else if (_period == 'Month') {
      start = DateTime(_selectedDate.year, _selectedDate.month);
      end = DateTime(_selectedDate.year, _selectedDate.month + 1);
    } else {
      start = DateTime(_selectedDate.year);
      end = DateTime(_selectedDate.year + 1);
    }
    Map<String, int> counts = {'Carbs': 0, 'Proteins': 0, 'Vitamins': 0};
    for (final cat in categories) {
      final meals = await MealDatabase.instance.getMealsByCategory(cat);
      final filtered = meals.where((m) {
        final date = DateTime.tryParse(m.date);
        return date != null && date.isAfter(start.subtract(const Duration(milliseconds: 1))) && date.isBefore(end);
      }).toList();
      counts[cat] = filtered.length;
    }
    setState(() {
      _categoryCounts = counts;
      _loading = false;
    });
  }

  Widget _buildAnalysis() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              DropdownButton<String>(
                value: _period,
                items: ['Day', 'Month', 'Year']
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (val) async {
                  if (val != null) {
                    setState(() => _period = val);
                    await _fetchCategoryCounts();
                  }
                },
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                icon: const Icon(Icons.date_range),
                label: Text(_period == 'Day'
                    ? '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}'
                    : _period == 'Month'
                        ? '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}'
                        : '${_selectedDate.year}'),
                onPressed: () async {
                  DateTime? picked;
                  if (_period == 'Day') {
                    picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                  } else if (_period == 'Month') {
                    picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      selectableDayPredicate: (d) => d.day == 1,
                    );
                  } else {
                    picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                  }
                  if (picked != null) {
                    setState(() {
  if (picked != null) _selectedDate = picked;
});
await _fetchCategoryCounts();
                  }
                },
              ),
            ],
          ),
        ),
        _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: SizedBox(
                  height: 180,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _categoryCounts.values.isNotEmpty
                          ? (_categoryCounts.values.reduce((a, b) => a > b ? a : b).toDouble() + 1)
                          : 5,
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= categories.length) return const SizedBox.shrink();
                              return Text(categories[idx], style: const TextStyle(fontSize: 12));
                            },
                          ),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(categories.length, (i) {
                        final cat = categories[i];
                        final color = cat == 'Carbs'
                            ? Colors.orange
                            : cat == 'Proteins'
                                ? Colors.blue
                                : Colors.green;
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: _categoryCounts[cat]?.toDouble() ?? 0,
                              color: color,
                              borderRadius: BorderRadius.circular(8),
                              width: 32,
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAnalysis(),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: Text(
                  'Welcome to Eaty!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _generateMeal,
        icon: const Icon(Icons.restaurant_menu),
        label: const Text('Generate Meal'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

