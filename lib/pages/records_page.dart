

import '../db/meal_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({Key? key}) : super(key: key);

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  final List<String> categories = ['Carbs', 'Proteins', 'Vitamins'];
  Map<String, List<Meal>> mealsByCategory = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMeals();
  }

  Future<void> _fetchMeals() async {
  final stopwatch = Stopwatch()..start();
  final prefs = await SharedPreferences.getInstance();
  final String mode = prefs.getString('meal_mode') ?? 'own';
  final Map<String, List<Meal>> data = {};

  if (mode == 'app') {
    // Generate "meals" dynamically from app foods grouped by category
    final List<Food> appFoods = await MealDatabase.instance.getFoods(appFoods: true);
    for (var cat in categories) {
      final foodsInCat = appFoods.where((f) => f.category == cat).toList();
      // For demo: treat each food as a "meal" (since no app meals table exists)
      data[cat] = foodsInCat.map((f) => Meal(id: null, name: f.name, category: f.category, date: "")).toList();
    }
  } else {
    for (var cat in categories) {
      data[cat] = await MealDatabase.instance.getMealsByCategory(cat);
    }
  }
  stopwatch.stop();
  debugPrint('Fetched all meals in: [32m[1m[4m[93m[41m[5m[0m[1m${stopwatch.elapsedMilliseconds}ms[0m');
  if (stopwatch.elapsedMilliseconds > 500) {
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Loading meals took ${stopwatch.elapsedMilliseconds}ms')),
    );
  }
  setState(() {
    mealsByCategory = data;
    isLoading = false;
  });
}


  Future<void> _addMeal(String category) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add meal to $category'),
        content: TextField(controller: controller, autofocus: true, decoration: InputDecoration(hintText: 'Meal name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await MealDatabase.instance.insertMeal(Meal(name: controller.text.trim(), category: category));
                Navigator.pop(ctx);
                _fetchMeals();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _editMeal(Meal meal) async {
    final controller = TextEditingController(text: meal.name);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit meal'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await MealDatabase.instance.updateMeal(meal.copyWith(name: controller.text.trim()));
                Navigator.pop(ctx);
                _fetchMeals();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMeal(Meal meal) async {
    await MealDatabase.instance.deleteMeal(meal.id!);
    _fetchMeals();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      body: ListView(
        children: categories.map((cat) {
          return ExpansionTile(
            title: Text(cat),
            children: [
              ...?mealsByCategory[cat]?.map((meal) => ListTile(
                    title: Text(meal.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editMeal(meal),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteMeal(meal),
                        ),
                      ],
                    ),
                  )) ?? [const ListTile(title: Text('No meals'))],
              Padding(
                padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Meal'),
                  onPressed: () => _addMeal(cat),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
