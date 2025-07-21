import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'db/meal_database.dart';
import 'pages/home_page.dart';
import 'pages/foods_page.dart';
import 'pages/meals_page.dart';
import 'pages/profile_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eaty',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF87CEEB), // Sky blue
          primary: const Color(0xFF87CEEB),
          secondary: Colors.brown,
          background: Colors.white,
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onBackground: Colors.black,
          onSurface: Colors.black,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF87CEEB),
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF87CEEB),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 2,
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF87CEEB),
          selectedItemColor: Colors.brown,
          unselectedItemColor: Colors.white,
          elevation: 12,
          type: BottomNavigationBarType.fixed,
          selectedIconTheme: IconThemeData(size: 28),
          unselectedIconTheme: IconThemeData(size: 24),
          showUnselectedLabels: true,
        ),
      ),
      home: const MyHomePage(title: 'Eaty'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isFirstLaunch = prefs.getBool('firstLaunch') ?? true;

    if (isFirstLaunch) {
      _showFirstLaunchDialog();
      await prefs.setBool('firstLaunch', false);
    }
  }

  Future<void> _showFirstLaunchDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Load Sample Foods?'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Would you like to load a list of sample foods to get started?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Yes'),
              onPressed: () {
                _loadSampleFoods();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadSampleFoods() async {
  try {
    final rawData = await rootBundle.loadString('assets/data/foods.csv');
    debugPrint('RAW CSV DATA:\n' + rawData);
    final listData = CsvToListConverter(eol: '\n').convert(rawData);
if (listData.length == 1 && listData[0].toString().length > 100) {
  debugPrint('WARNING: CSV parsing failed, check line endings in foods.csv!');
}
    debugPrint('PARSED CSV DATA:');
    for (var i = 0; i < listData.length; i++) {
      debugPrint('Row $i: ${listData[i]}');
    }
    debugPrint('Parsed CSV rows: \u001b[32m${listData.length}\u001b[0m');
    final db = MealDatabase.instance;
    final realDb = await db.database;
    debugPrint('DB PATH (insert): ' + realDb.path);
    int success = 0, fail = 0;
    for (var i = 1; i < listData.length; i++) {
      var row = listData[i];
      try {
        await db.createFood(row[0].toString(), row[1].toString(), isAppFood: 1);
        success++;
      } catch (e) {
        debugPrint('Failed to insert row $i: $row, error: $e');
        fail++;
      }
    }
    // Print schema
    final schema = await realDb.rawQuery('PRAGMA table_info(foods)');
    debugPrint('FOODS TABLE SCHEMA:');
    for (var col in schema) {
      debugPrint(col.toString());
    }
    // Print all rows
    final allRows = await realDb.rawQuery('SELECT * FROM foods');
    debugPrint('ALL ROWS IN FOODS TABLE:');
    for (var row in allRows) {
      debugPrint(row.toString());
    }
    debugPrint('Inserted $success foods, $fail failures.');
    // Print all app foods
    final appFoods = await db.getFoods(appFoods: true);
    debugPrint('Foods in DB with isAppFood==1:');
    for (final f in appFoods) {
      debugPrint('  ${f.name} (${f.category})');
    }
  } catch (e) {
    debugPrint('Error loading sample foods: $e');
  }
}


  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  static final List<Widget> _pages = <Widget>[
    HomePage(),
    FoodsPage(),
    MealsPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        selectedItemColor: Theme.of(context).colorScheme.primary,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Foods',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'Meals',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
