import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class Meal {
  final int? id;
  final String name;
  final String category;
  final String date; // ISO8601 string

  Meal({this.id, required this.name, required this.category, required this.date});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'date': date,
    };
  }

  factory Meal.fromMap(Map<String, dynamic> map) {
    return Meal(
      id: map['id'],
      name: map['name'],
      category: map['category'],
      date: map['date'],
    );
  }
}

class Food {
  final int? id;
  final String name;
  final String category;
  final int isAppFood; // 0 for user food, 1 for app food

  Food({this.id, required this.name, required this.category, this.isAppFood = 0});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'isAppFood': isAppFood,
    };
  }

  factory Food.fromMap(Map<String, dynamic> map) {
    return Food(
      id: map['id'],
      name: map['name'],
      category: map['category'],
      isAppFood: map['isAppFood'],
    );
  }
}

class MealDatabase {
  static final MealDatabase instance = MealDatabase._init();
  static Database? _database;

  MealDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('meals.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE meals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE foods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        isAppFood INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE meals ADD COLUMN date TEXT NOT NULL DEFAULT ''");
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE foods (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          category TEXT NOT NULL,
          isAppFood INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }
  }

  Future<Meal> insertMeal(Meal meal) async {
    final db = await instance.database;
    final id = await db.insert('meals', meal.toMap());
    return meal.copyWith(id: id);
  }

  Future<Food> createFood(String name, String category, {int isAppFood = 0}) async {
    final db = await instance.database;
    final food = Food(name: name, category: category, isAppFood: isAppFood);
    final id = await db.insert('foods', food.toMap());
    return food.copyWith(id: id);
  }

  Future<List<Food>> getFoods({bool appFoods = false, String? category}) async {
    final db = await instance.database;
    final maps = await db.query(
      'foods',
      where: 'isAppFood = ? AND category = ?',
      whereArgs: [appFoods ? 1 : 0, category],
    );
    return maps.map((f) => Food.fromMap(f)).toList();
  }

  Future<List<Meal>> getMealsByCategory(String category) async {
    final db = await instance.database;
    final maps = await db.query('meals', where: 'category = ?', whereArgs: [category]);
    return maps.map((m) => Meal.fromMap(m)).toList();
  }

  Future<int> updateMeal(Meal meal) async {
    final db = await instance.database;
    return db.update('meals', meal.toMap(), where: 'id = ?', whereArgs: [meal.id]);
  }

  Future<int> deleteMeal(int id) async {
    final db = await instance.database;
    return db.delete('meals', where: 'id = ?', whereArgs: [id]);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}

extension MealCopyWith on Meal {
  Meal copyWith({int? id, String? name, String? category, String? date}) {
    return Meal(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      date: date ?? this.date,
    );
  }
}

extension FoodCopyWith on Food {
  Food copyWith({int? id, String? name, String? category, int? isAppFood}) {
    return Food(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      isAppFood: isAppFood ?? this.isAppFood,
    );
  }
}
