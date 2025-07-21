import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

import '../db/meal_database.dart';

class MealsPage extends StatefulWidget {
  const MealsPage({Key? key}) : super(key: key);

  @override
  State<MealsPage> createState() => _MealsPageState();
}

class _MealsPageState extends State<MealsPage> {
  late Future<List<Meal>> _mealsFuture;
  String _mode = 'own';

  @override
  void initState() {
    super.initState();
    _loadModeAndGenerateMeals();
  }

  Future<void> _loadModeAndGenerateMeals() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _mode = prefs.getString('meal_mode') ?? 'own';
    });
    _mealsFuture = _generateMeals();
  }

  Future<List<Meal>> _generateMeals() async {
    final db = MealDatabase.instance;
    final foods = await db.getFoods(appFoods: _mode == 'app');
    if (foods.isEmpty) {
      return [];
    }

    final random = Random();
    final List<Meal> meals = [];
    for (int i = 0; i < 10; i++) {
      final food1 = foods[random.nextInt(foods.length)];
      final food2 = foods[random.nextInt(foods.length)];
      final meal = Meal(
        name: '${food1.name} & ${food2.name}',
        category: 'Generated',
        date: DateTime.now().toIso8601String(),
      );
      meals.add(meal);
    }
    return meals;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Meal>>(
      future: _mealsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: \${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No generated meals'));
        } else {
          final meals = snapshot.data!;
          return ListView.builder(
            itemCount: meals.length,
            itemBuilder: (context, index) {
              final meal = meals[index];
              return ListTile(
                title: Text(meal.name),
                subtitle: Text('Generated Meal'),
              );
            },
          );
        }
      },
    );
  }
}

