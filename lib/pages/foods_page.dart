import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/meal_database.dart';

class FoodsPage extends StatefulWidget {
  const FoodsPage({Key? key}) : super(key: key);

  @override
  State<FoodsPage> createState() => _FoodsPageState();
}

class _FoodsPageState extends State<FoodsPage> {
  final List<String> categories = ['Carbohydrate', 'Protein', 'Vegetable', 'Fat'];
  Map<String, List<Food>> foodsByCategory = {};
  bool isLoading = true;
  String _mode = 'own';

  @override
  void initState() {
    super.initState();
    _loadModeAndFetchFoods();
  }

  Future<void> _loadModeAndFetchFoods() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _mode = prefs.getString('meal_mode') ?? 'own';
    });
    _fetchFoods();
  }

  Future<void> _updateMode(String newMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('meal_mode', newMode);
    setState(() {
      _mode = newMode;
    });
    _fetchFoods();
  }

  Future<void> _fetchFoods() async {
    setState(() {
      isLoading = true;
    });
    final stopwatch = Stopwatch()..start();
    final Map<String, List<Food>> data = {};
    for (var cat in categories) {
      data[cat] = await MealDatabase.instance.getFoods(appFoods: _mode == 'app', category: cat);
    }
    stopwatch.stop();
    debugPrint('Fetched all foods in: \x1b[32m\x1b[1m\x1b[4m\x1b[93m\x1b[41m\x1b[5m\x1b[0m\x1b[1m${stopwatch.elapsedMilliseconds}ms\x1b[0m');
    if (stopwatch.elapsedMilliseconds > 500) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loading foods took ${stopwatch.elapsedMilliseconds}ms')),
      );
    }
    setState(() {
      foodsByCategory = data;
      isLoading = false;
    });
  }

  Future<void> _addFood(String category) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add food to $category'),
        content: TextField(controller: controller, autofocus: true, decoration: InputDecoration(hintText: 'Food name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await MealDatabase.instance.createFood(controller.text.trim(), category);
                Navigator.pop(ctx);
                _fetchFoods();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _editFood(Food food) async {
    final controller = TextEditingController(text: food.name);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit food'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                // await MealDatabase.instance.updateFood(food.copyWith(name: controller.text.trim()));
                Navigator.pop(ctx);
                _fetchFoods();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFood(Food food) async {
    // await MealDatabase.instance.deleteFood(food.id!);
    _fetchFoods();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(value: 'own', label: Text('Own Data')),
                ButtonSegment<String>(value: 'app', label: Text('App Data')),
              ],
              selected: <String>{_mode},
              onSelectionChanged: (Set<String> newSelection) {
                _updateMode(newSelection.first);
              },
            ),
          ),
          Expanded(
            child: ListView(
              children: categories.map((cat) {
                return ExpansionTile(
                  title: Text(cat),
                  children: [
                    ...?foodsByCategory[cat]?.map((food) => ListTile(
                          title: Text(food.name),
                          trailing: _mode == 'own' ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editFood(food),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deleteFood(food),
                              ),
                            ],
                          ) : null,
                        )) ?? [const ListTile(title: Text('No foods'))],
                    if (_mode == 'own')
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add Food'),
                          onPressed: () => _addFood(cat),
                        ),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
