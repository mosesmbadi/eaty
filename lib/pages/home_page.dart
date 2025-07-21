import 'package:flutter/material.dart';

import 'package:flutter/material.dart';
import '../db/meal_database.dart';
import '../db/meal_database.dart';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<String> categories = ['Carbs', 'Proteins', 'Vitamins'];

  Future<void> _generateMeal() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('meal_mode') ?? 'own';
    List<String> selectedFoods = [];
    if (mode == 'online') {
      selectedFoods = await _fetchFoodsFromApi();
    } else {
      final random = Random();
      if (mode == 'app') {
        final dbPath = (await MealDatabase.instance.database).path;
        debugPrint('DB PATH (query): ' + dbPath);
        final appFoods = await MealDatabase.instance.getFoods(appFoods: true);
        debugPrint('ALL APP FOODS:');
        for (var f in appFoods) {
          debugPrint('Food: \'${f.name}\', Category: "${f.category}"');
        }
        final Map<String, String> appCategoryMap = {
          'Carbs': 'Carbohydrate',
          'Proteins': 'Protein',
          'Vitamins': 'Vegetable',
        };
        for (var cat in categories) {
          final foodsInCat = appFoods.where((f) => f.category == appCategoryMap[cat]).toList();
          debugPrint('AppData: $cat → ${appCategoryMap[cat]}, found ${foodsInCat.length} foods: ${foodsInCat.map((f) => f.name).toList()}');
          if (foodsInCat.isNotEmpty) {
            final food = foodsInCat[random.nextInt(foodsInCat.length)];
            selectedFoods.add(food.name);
          }
        }
      } else {
        // Map UI categories to DB categories for user foods
        final Map<String, String> ownCategoryMap = {
          'Carbs': 'Carbohydrate',
          'Proteins': 'Protein',
          'Vitamins': 'Vegetable',
        };
        for (var cat in categories) {
          final dbCat = ownCategoryMap[cat] ?? cat;
          final foods = await MealDatabase.instance.getFoods(appFoods: false, category: dbCat);
          debugPrint('OwnData: UI category "$cat" → DB category "$dbCat", found ${foods.length} foods: ${foods.map((f) => f.name).toList()}');
          if (foods.isNotEmpty) {
            final food = foods[random.nextInt(foods.length)];
            selectedFoods.add(food.name);
          }
        }
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
        content: Text(
          mode == 'online'
              ? '[1m$mealName\n\n(generated from https://www.themealdb.com/api/json/v1/1/randomselection.php)'
              : mealName,
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  Future<List<String>> _fetchFoodsFromApi() async {
    // Example using Edamam Food Database API (replace with your credentials)
    // https://developer.edamam.com/edamam-docs-food-database-api
    // NOTE: Replace 'demo' with your real app_id and app_key
    const appId = 'demo';
    const appKey = 'demo';

    final queries = {
      'Carbs': 'rice',
      'Proteins': 'chicken',
      'Vitamins': 'spinach',
    };

    List<String> foods = [];
    for (final entry in queries.entries) {
      final response = await http.get(Uri.parse(
        'https://api.edamam.com/api/food-database/v2/parser?app_id=$appId&app_key=$appKey&ingr=${Uri.encodeComponent(entry.value)}'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['parsed'] != null && data['parsed'].isNotEmpty) {
          final foodName = data['parsed'][0]['food']['label'];
          foods.add(foodName);
        } else if (data['hints'] != null && data['hints'].isNotEmpty) {
          final foodName = data['hints'][0]['food']['label'];
          foods.add(foodName);
        } else {
          foods.add(entry.value);
        }
      } else {
        foods.add(entry.value);
      }
    }
    return foods;
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
    // Get all foods for category lookup
    Map<String, String> foodToCategory = {};
    for (final cat in categories) {
      final foods = await MealDatabase.instance.getMealsByCategory(cat);
      for (final food in foods) {
        foodToCategory[food.name.trim()] = food.category;
      }
    }
    // Count categories in generated meals
    Map<String, int> counts = {for (var cat in categories) cat: 0};
    final generatedMeals = await MealDatabase.instance.getMealsByCategory('Generated');
    for (final meal in generatedMeals) {
      final date = DateTime.tryParse(meal.date);
      if (date == null || date.isBefore(start) || date.isAfter(end.subtract(const Duration(milliseconds: 1)))) continue;
      final foods = meal.name.split(',');
      for (final food in foods) {
        final foodName = food.trim();
        final cat = foodToCategory[foodName];
        if (cat != null && counts.containsKey(cat)) {
          counts[cat] = counts[cat]! + 1;
        }
      }
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: categories.map((cat) {
                    final color = cat == 'Carbs'
                        ? Colors.orange
                        : cat == 'Proteins'
                            ? Colors.blue
                            : Colors.green;
                    final int value = _categoryCounts[cat] ?? 0;
                    final int maxValue = _categoryCounts.values.isNotEmpty
                        ? _categoryCounts.values.reduce((a, b) => a > b ? a : b)
                        : 1;
                    final double barFraction = maxValue > 0 ? value / maxValue : 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: Text(cat, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          Expanded(
                            child: Stack(
                              children: [
                                Container(
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: barFraction,
                                  child: Container(
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(value.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }).toList(),
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

