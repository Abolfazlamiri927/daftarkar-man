import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'costing.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDb.instance.init();
  runApp(const DaftarkarApp());
}

class DaftarkarApp extends StatelessWidget {
  const DaftarkarApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'دفترکار من',
    locale: const Locale('fa'),
    supportedLocales: const [Locale('fa')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF147D70)),
      scaffoldBackgroundColor: const Color(0xFFF5F7F7),
      appBarTheme: const AppBarTheme(centerTitle: false, backgroundColor: Color(0xFFF5F7F7)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
      cardTheme: CardThemeData(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
    ),
    home: const HomePage(),
  );
}

class AppDb {
  AppDb._();
  static final instance = AppDb._();
  late Database db;
  Future<void> init() async {
    final path = p.join(await getDatabasesPath(), 'daftarkar.db');
    db = await openDatabase(path, version: 3, onCreate: (d, v) async {
      await d.execute('CREATE TABLE clients(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, phone TEXT, note TEXT)');
      await d.execute('CREATE TABLE jobs(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, client TEXT, amount INTEGER NOT NULL DEFAULT 0, status TEXT NOT NULL DEFAULT "درحال انجام", created TEXT NOT NULL)');
      await d.execute('CREATE TABLE entries(id INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT NOT NULL, title TEXT NOT NULL, amount INTEGER NOT NULL, created TEXT NOT NULL)');
      await _createCostTables(d);
      await _createPriceHistoryTable(d);
    }, onUpgrade: (d, oldVersion, newVersion) async {
      if (oldVersion < 2) await _createCostTables(d);
      if (oldVersion < 3) await _createPriceHistoryTable(d);
    });
  }
  Future<void> _createCostTables(DatabaseExecutor d) async {
    await d.execute('CREATE TABLE materials(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, unit TEXT NOT NULL, pack_qty REAL NOT NULL, pack_price INTEGER NOT NULL, updated_at TEXT NOT NULL)');
    await d.execute('CREATE TABLE products(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, batch_qty REAL NOT NULL, selling_price INTEGER NOT NULL, packaging_cost INTEGER NOT NULL DEFAULT 0, labor_cost INTEGER NOT NULL DEFAULT 0, overhead_cost INTEGER NOT NULL DEFAULT 0, waste_rate REAL NOT NULL DEFAULT 0, commission_rate REAL NOT NULL DEFAULT 0, target_margin_rate REAL NOT NULL DEFAULT 0.25, created TEXT NOT NULL)');
    await d.execute('CREATE TABLE recipe(id INTEGER PRIMARY KEY AUTOINCREMENT, product_id INTEGER NOT NULL, material_id INTEGER NOT NULL, quantity REAL NOT NULL, FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE, FOREIGN KEY(material_id) REFERENCES materials(id))');
  }
  Future<void> _createPriceHistoryTable(DatabaseExecutor d) async {
    await d.execute('CREATE TABLE material_price_history(id INTEGER PRIMARY KEY AUTOINCREMENT, material_id INTEGER NOT NULL, pack_qty REAL NOT NULL, pack_price INTEGER NOT NULL, changed_at TEXT NOT NULL)');
  }
  Future<List<Map<String,Object?>>> rows(String table) => db.query(table, orderBy: 'id DESC');
  Future<int> add(String table, Map<String,Object?> data) => db.insert(table, data);
  Future<int> remove(String table, int id) => db.delete(table, where: 'id=?', whereArgs: [id]);
  Future<Map<String, dynamic>> makeBackup() async => {
    'app': 'daftarkar-man',
    'backupVersion': 2,
    'createdAt': DateTime.now().toIso8601String(),
    'clients': await db.query('clients', orderBy: 'id ASC'),
    'jobs': await db.query('jobs', orderBy: 'id ASC'),
    'entries': await db.query('entries', orderBy: 'id ASC'),
    'materials': await db.query('materials', orderBy: 'id ASC'),
    'products': await db.query('products', orderBy: 'id ASC'),
    'recipe': await db.query('recipe', orderBy: 'id ASC'),
    'materialPriceHistory': await db.query('material_price_history', orderBy: 'id ASC'),
  };

  Future<void> restoreBackup(Map<String, dynamic> data) async {
    if (data['app'] != 'daftarkar-man' || ![1, 2].contains(data['backupVersion'])) {
      throw const FormatException('نسخه یا ساختار فایل پشتیبان معتبر نیست.');
    }
    final clients = data['clients'];
    final jobs = data['jobs'];
    final entries = data['entries'];
    final materials = data['materials'] ?? [];
    final products = data['products'] ?? [];
    final recipe = data['recipe'] ?? [];
    final priceHistory = data['materialPriceHistory'] ?? [];
    if (clients is! List || jobs is! List || entries is! List || materials is! List || products is! List || recipe is! List || priceHistory is! List) {
      throw const FormatException('اطلاعات فایل پشتیبان ناقص است.');
    }
    Map<String, Object?> row(dynamic value, List<String> required) {
      if (value is! Map) throw const FormatException('ساختار یکی از ردیف‌ها معتبر نیست.');
      final result = Map<String, Object?>.from(value);
      for (final key in required) {
        if (result[key] == null) throw FormatException('فیلد $key در فایل پشتیبان وجود ندارد.');
      }
      return result;
    }
    final safeClients = clients.map((v) => row(v, ['name'])).toList();
    final safeJobs = jobs.map((v) => row(v, ['title', 'amount', 'status', 'created'])).toList();
    final safeEntries = entries.map((v) => row(v, ['kind', 'title', 'amount', 'created'])).toList();
    final safeMaterials = materials.map((v) => row(v, ['name', 'unit', 'pack_qty', 'pack_price', 'updated_at'])).toList();
    final safeProducts = products.map((v) => row(v, ['name', 'batch_qty', 'selling_price', 'created'])).toList();
    final safeRecipe = recipe.map((v) => row(v, ['product_id', 'material_id', 'quantity'])).toList();
    final safePriceHistory = priceHistory.map((v) => row(v, ['material_id', 'pack_qty', 'pack_price', 'changed_at'])).toList();
    if (safeEntries.any((e) => !['income', 'expense'].contains(e['kind']))) {
      throw const FormatException('نوع یکی از تراکنش‌ها نامعتبر است.');
    }
    await db.transaction((txn) async {
      await txn.delete('material_price_history');
      await txn.delete('recipe');
      await txn.delete('products');
      await txn.delete('materials');
      await txn.delete('entries');
      await txn.delete('jobs');
      await txn.delete('clients');
      for (final item in safeClients) { await txn.insert('clients', item); }
      for (final item in safeJobs) { await txn.insert('jobs', item); }
      for (final item in safeEntries) { await txn.insert('entries', item); }
      for (final item in safeMaterials) { await txn.insert('materials', item); }
      for (final item in safeProducts) { await txn.insert('products', item); }
      for (final item in safeRecipe) { await txn.insert('recipe', item); }
      for (final item in safePriceHistory) { await txn.insert('material_price_history', item); }
    });
  }

  Future<int> total(String kind) async {
    final r = await db.rawQuery('SELECT COALESCE(SUM(amount),0) AS total FROM entries WHERE kind=?', [kind]);
    return (r.first['total'] as int?) ?? 0;
  }
}

String normalizeDigits(String value) {
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  const ar = '٠١٢٣٤٥٦٧٨٩';
  var result = value;
  for (var i = 0; i < 10; i++) {
    result = result.replaceAll(fa[i], '$i').replaceAll(ar[i], '$i');
  }
  return result.replaceAll(',', '').replaceAll('٬', '').replaceAll('،', '').trim();
}
int? parseAmount(String value) => int.tryParse(normalizeDigits(value));
String money(num n) => NumberFormat.decimalPattern('fa').format(n);
String today() => DateFormat('yyyy/MM/dd').format(DateTime.now());

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  int tab = 0;
  int refresh = 0;
  void reload() => setState(() => refresh++);

  void notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> exportBackup() async {
    try {
      final data = await AppDb.instance.makeBackup();
      final bytes = Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(data)));
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final file = XFile.fromData(bytes, mimeType: 'application/json', name: 'daftarkar_backup_$stamp.json');
      await Share.shareXFiles([file], text: 'نسخه پشتیبان دفترکار من');
      notice('فایل پشتیبان آماده اشتراک‌گذاری است.');
    } catch (e) {
      notice('ساخت پشتیبان ناموفق بود: $e');
    }
  }

  Future<void> importBackup() async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom, allowedExtensions: ['json'], withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final bytes = picked.files.single.bytes;
      if (bytes == null) { notice('خواندن فایل انتخاب‌شده ممکن نشد.'); return; }
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) throw const FormatException('فایل JSON معتبر نیست.');
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('بازیابی اطلاعات'),
          content: const Text('با بازیابی، اطلاعات فعلی برنامه با اطلاعات فایل پشتیبان جایگزین می‌شود. قبل از ادامه از اطلاعات فعلی هم پشتیبان بگیر. ادامه می‌دهی؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('جایگزینی اطلاعات')),
          ],
        ),
      );
      if (confirmed != true) return;
      await AppDb.instance.restoreBackup(decoded);
      reload();
      notice('اطلاعات با موفقیت بازیابی شد.');
    } catch (e) {
      notice('بازیابی انجام نشد: $e');
    }
  }
  @override
  Widget build(BuildContext context) {
    final pages = [
      Dashboard(key: ValueKey('d$refresh')),
      CostingPage(key: ValueKey('p$refresh'), onChanged: reload),
      ClientsPage(key: ValueKey('c$refresh'), onChanged: reload),
      JobsPage(key: ValueKey('j$refresh'), onChanged: reload),
      LedgerPage(key: ValueKey('l$refresh'), onChanged: reload),
    ];
    return Directionality(textDirection: ui.TextDirection.rtl, child: Scaffold(
      appBar: AppBar(title: const Text('دفترکار من', style: TextStyle(fontWeight: FontWeight.w800)), actions: [
        PopupMenuButton<String>(
          tooltip: 'ابزارها',
          onSelected: (value) {
            if (value == 'backup') { exportBackup(); }
            if (value == 'restore') { importBackup(); }
            if (value == 'about') { showAboutDialog(
              context: context, applicationName: 'دفترکار من', applicationVersion: '0.2.0',
              children: const [Text('مدیریت آفلاین مشتری‌ها، سفارش‌ها و گردش مالی. اطلاعات روی همین دستگاه ذخیره می‌شود. از بخش ابزارها مرتب نسخه پشتیبان تهیه کن.')],
            ); }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'backup', child: ListTile(leading: Icon(Icons.backup_outlined), title: Text('تهیه نسخه پشتیبان'), contentPadding: EdgeInsets.zero)),
            PopupMenuItem(value: 'restore', child: ListTile(leading: Icon(Icons.restore), title: Text('بازیابی نسخه پشتیبان'), contentPadding: EdgeInsets.zero)),
            PopupMenuItem(value: 'about', child: ListTile(leading: Icon(Icons.info_outline), title: Text('درباره برنامه'), contentPadding: EdgeInsets.zero)),
          ],
        ),
      ]),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'خانه'),
          NavigationDestination(icon: Icon(Icons.price_change_outlined), selectedIcon: Icon(Icons.price_change), label: 'قیمت‌گذاری'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'مشتری‌ها'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'سفارش‌ها'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'حساب‌وکتاب'),
        ],
      ),
    ));
  }
}


double? parseDecimal(String value) {
  final normalized = normalizeDigits(value).replaceAll('٫', '.').replaceAll(',', '.');
  return double.tryParse(normalized);
}

class CostingPage extends StatefulWidget {
  final VoidCallback onChanged;
  const CostingPage({super.key, required this.onChanged});
  @override State<CostingPage> createState() => _CostingPageState();
}

class _CostingPageState extends State<CostingPage> {
  int section = 0;

  void refreshData() {
    if (mounted) setState(() {});
    widget.onChanged();
  }

  Future<void> addMaterial() async {
    final name = TextEditingController();
    final unit = TextEditingController(text: 'گرم');
    final packQty = TextEditingController();
    final packPrice = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('ماده اولیه جدید'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'نام ماده اولیه')),
        const SizedBox(height: 8),
        TextField(controller: unit, decoration: const InputDecoration(labelText: 'واحد اندازه‌گیری')),
        const SizedBox(height: 8),
        TextField(controller: packQty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مقدار بسته خریداری‌شده')),
        const SizedBox(height: 8),
        TextField(controller: packPrice, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'قیمت کل بسته (تومان)')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('انصراف')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('ذخیره')),
      ],
    ));
    final q = parseDecimal(packQty.text);
    final price = parseAmount(packPrice.text);
    if (ok == true && name.text.trim().isNotEmpty && unit.text.trim().isNotEmpty &&
        q != null && q > 0 && price != null && price > 0) {
      final materialId = await AppDb.instance.add('materials', {
        'name': name.text.trim(), 'unit': unit.text.trim(),
        'pack_qty': q, 'pack_price': price, 'updated_at': today(),
      });
      await AppDb.instance.add('material_price_history', {
        'material_id': materialId, 'pack_qty': q, 'pack_price': price, 'changed_at': today(),
      });
      refreshData();
    }
    name.dispose(); unit.dispose(); packQty.dispose(); packPrice.dispose();
  }

  Future<void> editMaterial(Map<String, Object?> item) async {
    final q = TextEditingController(text: item['pack_qty'].toString());
    final price = TextEditingController(text: item['pack_price'].toString());
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Text('قیمت جدید: ' + item['name'].toString()),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: q, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مقدار بسته')),
        const SizedBox(height: 8),
        TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'قیمت بسته (تومان)')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('انصراف')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('ثبت')),
      ],
    ));
    final quantity = parseDecimal(q.text);
    final amount = parseAmount(price.text);
    if (ok == true && quantity != null && quantity > 0 && amount != null && amount > 0) {
      await AppDb.instance.db.transaction((txn) async {
        await txn.update('materials', {
          'pack_qty': quantity, 'pack_price': amount, 'updated_at': today(),
        }, where: 'id=?', whereArgs: [item['id']]);
        await txn.insert('material_price_history', {
          'material_id': item['id'], 'pack_qty': quantity, 'pack_price': amount, 'changed_at': today(),
        });
      });
      refreshData();
    }
    q.dispose(); price.dispose();
  }

  Future<void> showPriceHistory(Map<String, Object?> material) async {
    final history = await AppDb.instance.db.query(
      'material_price_history',
      where: 'material_id=?',
      whereArgs: [material['id']],
      orderBy: 'id DESC',
    );
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.65,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تاریخچه قیمت: ${material['name']}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('قیمت هر ${material['unit']} در خریدهای ثبت‌شده',
                    style: TextStyle(color: Colors.grey.shade600)),
                const Divider(height: 24),
                Expanded(
                  child: history.isEmpty
                      ? const _Empty(text: 'هنوز سابقه‌ای برای این ماده ثبت نشده است.')
                      : ListView.builder(
                          itemCount: history.length,
                          itemBuilder: (context, index) {
                            final item = history[index];
                            final unitPrice = (item['pack_price'] as num) /
                                (item['pack_qty'] as num);
                            double? change;
                            if (index + 1 < history.length) {
                              final previous = history[index + 1];
                              final previousUnitPrice =
                                  (previous['pack_price'] as num) /
                                  (previous['pack_qty'] as num);
                              if (previousUnitPrice > 0) {
                                change = (unitPrice - previousUnitPrice) /
                                    previousUnitPrice * 100;
                              }
                            }
                            return Card(
                              child: ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.history),
                                ),
                                title: Text('${money(unitPrice)} تومان برای هر ${material['unit']}'),
                                subtitle: Text(
                                  '${item['changed_at']} • بسته ${item['pack_qty']} ${material['unit']} به قیمت ${money(item['pack_price'] as num)} تومان',
                                ),
                                trailing: change == null
                                    ? null
                                    : Text(
                                        '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}٪',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: change > 0 ? Colors.deepOrange : Colors.green,
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> addProduct() async {
    final materials = await AppDb.instance.rows('materials');
    if (materials.isEmpty) {
      if (mounted) {
        setState(() => section = 1);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ابتدا مواد اولیه را ثبت کن.')));
      }
      return;
    }
    final name = TextEditingController();
    final batch = TextEditingController(text: '1');
    final selling = TextEditingController();
    final packaging = TextEditingController(text: '0');
    final labor = TextEditingController(text: '0');
    final overhead = TextEditingController(text: '0');
    final waste = TextEditingController(text: '0');
    final commission = TextEditingController(text: '0');
    final target = TextEditingController(text: '25');
    final lines = <Map<String, dynamic>>[
      {'materialId': materials.first['id'] as int, 'quantity': TextEditingController(text: '1')}
    ];
    final ok = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
      title: const Text('محصول و فرمول ساخت'),
      content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'نام محصول')),
        const SizedBox(height: 8),
        TextField(controller: batch, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'تعداد محصول در هر نوبت تولید')),
        const SizedBox(height: 12),
        const Align(alignment: Alignment.centerRight, child: Text('مواد مصرفی در هر نوبت', style: TextStyle(fontWeight: FontWeight.bold))),
        ...lines.asMap().entries.map((entry) {
          final line = entry.value;
          return Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [
            Expanded(flex: 3, child: DropdownButtonFormField<int>(
              value: line['materialId'] as int,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'ماده'),
              items: materials.map((m) => DropdownMenuItem<int>(
                value: m['id'] as int,
                child: Text(m['name'].toString() + ' (' + m['unit'].toString() + ')', overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (v) => setD(() => line['materialId'] = v),
            )),
            const SizedBox(width: 6),
            Expanded(flex: 2, child: TextField(
              controller: line['quantity'] as TextEditingController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'مقدار'),
            )),
            IconButton(
              onPressed: lines.length == 1 ? null : () => setD(() => lines.remove(line)),
              icon: const Icon(Icons.remove_circle_outline),
            ),
          ]));
        }),
        Align(alignment: Alignment.centerRight, child: TextButton.icon(
          onPressed: () => setD(() => lines.add({
            'materialId': materials.first['id'] as int,
            'quantity': TextEditingController(text: '1'),
          })),
          icon: const Icon(Icons.add), label: const Text('افزودن ماده'),
        )),
        const Divider(),
        TextField(controller: packaging, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'بسته‌بندی کل نوبت (تومان)')),
        const SizedBox(height: 8),
        TextField(controller: labor, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'دستمزد کل نوبت (تومان)')),
        const SizedBox(height: 8),
        TextField(controller: overhead, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سربار کل نوبت (تومان)')),
        const SizedBox(height: 8),
        TextField(controller: waste, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ضایعات مواد به درصد')),
        const SizedBox(height: 8),
        TextField(controller: commission, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'کارمزد فروش به درصد')),
        const SizedBox(height: 8),
        TextField(controller: target, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'حاشیه سود هدف به درصد')),
        const SizedBox(height: 8),
        TextField(controller: selling, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'قیمت فروش فعلی هر واحد (تومان)')),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('انصراف')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('ذخیره محصول')),
      ],
    )));
    final batchQty = parseDecimal(batch.text);
    final percent = (String value) => (parseDecimal(value) ?? 0) / 100;
    final validLines = lines.every((line) {
      final q = parseDecimal((line['quantity'] as TextEditingController).text);
      return line['materialId'] != null && q != null && q > 0;
    });
    if (ok == true && name.text.trim().isNotEmpty && batchQty != null && batchQty > 0 && validLines) {
      final productId = await AppDb.instance.add('products', {
        'name': name.text.trim(),
        'batch_qty': batchQty,
        'selling_price': parseAmount(selling.text) ?? 0,
        'packaging_cost': parseAmount(packaging.text) ?? 0,
        'labor_cost': parseAmount(labor.text) ?? 0,
        'overhead_cost': parseAmount(overhead.text) ?? 0,
        'waste_rate': percent(waste.text),
        'commission_rate': percent(commission.text),
        'target_margin_rate': percent(target.text),
        'created': today(),
      });
      for (final line in lines) {
        await AppDb.instance.add('recipe', {
          'product_id': productId,
          'material_id': line['materialId'],
          'quantity': parseDecimal((line['quantity'] as TextEditingController).text) ?? 0,
        });
      }
      refreshData();
    }
    for (final line in lines) {
      (line['quantity'] as TextEditingController).dispose();
    }
    name.dispose(); batch.dispose(); selling.dispose(); packaging.dispose();
    labor.dispose(); overhead.dispose(); waste.dispose(); commission.dispose(); target.dispose();
  }

  Future<Map<String, dynamic>> calculateProduct(Map<String, Object?> product) async {
    final recipeRows = await AppDb.instance.db.rawQuery(
      'SELECT recipe.quantity, materials.name, materials.unit, materials.pack_qty, materials.pack_price '
      'FROM recipe JOIN materials ON materials.id=recipe.material_id WHERE recipe.product_id=?',
      [product['id']],
    );
    final materialLines = recipeRows.map((r) => CostLine(
      name: r['name'].toString(),
      quantity: (r['quantity'] as num).toDouble(),
      unitCost: (r['pack_price'] as num).toDouble() / (r['pack_qty'] as num).toDouble(),
    )).toList();
    final result = calculateCost(CostInput(
      batchQuantity: (product['batch_qty'] as num).toDouble(),
      materials: materialLines,
      packagingCost: (product['packaging_cost'] as num).toDouble(),
      laborCost: (product['labor_cost'] as num).toDouble(),
      overheadCost: (product['overhead_cost'] as num).toDouble(),
      wasteRate: (product['waste_rate'] as num).toDouble(),
      commissionRate: (product['commission_rate'] as num).toDouble(),
      sellingPrice: (product['selling_price'] as num).toDouble() > 0
          ? (product['selling_price'] as num).toDouble() : null,
      targetMarginRate: (product['target_margin_rate'] as num).toDouble(),
    ));
    return {'breakdown': result, 'materials': materialLines};
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    floatingActionButton: FloatingActionButton.extended(
      onPressed: section == 0 ? addProduct : addMaterial,
      icon: const Icon(Icons.add),
      label: Text(section == 0 ? 'محصول جدید' : 'ماده اولیه جدید'),
    ),
    body: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 4), child: SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 0, label: Text('محصولات و سود'), icon: Icon(Icons.inventory_2_outlined)),
          ButtonSegment(value: 1, label: Text('مواد اولیه'), icon: Icon(Icons.grass_outlined)),
        ],
        selected: {section},
        onSelectionChanged: (values) => setState(() => section = values.first),
      )),
      Expanded(child: section == 1
        ? FutureBuilder<List<Map<String, Object?>>>(future: AppDb.instance.rows('materials'), builder: (c, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            if (snap.data!.isEmpty) return const _Empty(text: 'مواد اولیه را با مقدار بسته و قیمت خرید ثبت کن. قیمت هر واحد خودکار محاسبه می‌شود.');
            return ListView(padding: const EdgeInsets.all(12), children: snap.data!.map((m) {
              final unitCost = (m['pack_price'] as num) / (m['pack_qty'] as num);
              return Card(child: ListTile(
                onTap: () => editMaterial(m),
                leading: const CircleAvatar(child: Icon(Icons.grass_outlined)),
                title: Text(m['name'].toString()),
                subtitle: Text(
                  'بسته: ' + money(m['pack_price'] as num) + ' تومان برای ' +
                  m['pack_qty'].toString() + ' ' + m['unit'].toString() +
                  '\nقیمت هر ' + m['unit'].toString() + ': ' + money(unitCost) + ' تومان',
                ),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'تاریخچه قیمت',
                      icon: const Icon(Icons.history),
                      onPressed: () => showPriceHistory(m),
                    ),
                    const Icon(Icons.edit_outlined),
                  ],
                ),
              ));
            }).toList());
          })
        : FutureBuilder<List<Map<String, Object?>>>(future: AppDb.instance.rows('products'), builder: (c, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            if (snap.data!.isEmpty) return const _Empty(text: 'اول مواد اولیه را ثبت کن، بعد محصول و فرمول ساختش را بساز. تغییر قیمت مواد اولیه، سود محصولات را دوباره محاسبه می‌کند.');
            return ListView(padding: const EdgeInsets.all(12), children: snap.data!.map((product) => FutureBuilder<Map<String, dynamic>>(
              future: calculateProduct(product),
              builder: (c, costSnap) {
                if (!costSnap.hasData) return const Card(child: ListTile(title: Text('در حال محاسبه...')));
                final cost = costSnap.data!['breakdown'] as CostBreakdown;
                final margin = cost.marginRate;
                final targetMargin = (product['target_margin_rate'] as num).toDouble();
                final belowTarget = margin != null && margin < targetMargin;
                return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(product['name'].toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _line('بهای تمام‌شده هر واحد', cost.unitCost),
                  _line('قیمت فروش پیشنهادی با سود هدف', cost.targetPrice),
                  if (cost.sellingPrice != null) _line('سود هر واحد با قیمت فعلی', cost.unitProfit ?? 0),
                  if (margin != null) _line('حاشیه سود فعلی', margin * 100, suffix: '%'),
                  if (belowTarget) const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Row(children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.deepOrange, size: 18),
                      SizedBox(width: 5),
                      Expanded(child: Text('حاشیه سود از هدف تعیین‌شده کمتر است.', style: TextStyle(color: Colors.deepOrange))),
                    ]),
                  ),
                  const SizedBox(height: 6),
                  Text('با تغییر قیمت مواد اولیه، این محاسبات به‌روز می‌شوند.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ])));
              },
            )).toList());
          })),
    ]),
  );

  Widget _line(String label, num value, {String suffix = ' تومان'}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Expanded(child: Text(label, style: const TextStyle(color: Colors.black54))),
      Text(money(value) + suffix, style: const TextStyle(fontWeight: FontWeight.w700)),
    ]),
  );
}

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});
  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    future: Future.wait([AppDb.instance.total('income'), AppDb.instance.total('expense'), AppDb.instance.rows('jobs'), AppDb.instance.rows('clients')]),
    builder: (context, snap) {
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final income = snap.data![0] as int;
      final expense = snap.data![1] as int;
      final jobs = snap.data![2] as List<Map<String,Object?>>;
      final clients = snap.data![3] as List<Map<String,Object?>>;
      return ListView(padding: const EdgeInsets.all(16), children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF116B61), Color(0xFF239B86)]), borderRadius: BorderRadius.circular(22)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('مانده حساب ثبت‌شده', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Text('${money(income-expense)} تومان', style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('دریافتی: ${money(income)}  •  هزینه: ${money(expense)}', style: const TextStyle(color: Colors.white)),
        ])),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _stat('مشتری‌ها', '${clients.length}', Icons.people_alt_outlined)),
          const SizedBox(width: 10),
          Expanded(child: _stat('سفارش‌ها', '${jobs.length}', Icons.assignment_outlined)),
        ]),
        const SizedBox(height: 18),
        const Text('آخرین سفارش‌ها', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (jobs.isEmpty) const _Empty(text: 'هنوز سفارشی ثبت نکردی. از بخش سفارش‌ها شروع کن.'),
        ...jobs.take(5).map((j) => Card(child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.work_outline)),
          title: Text('${j['title']}'),
          subtitle: Text('${j['client'] ?? 'بدون نام مشتری'} • ${j['status']}'),
          trailing: Text(money((j['amount'] as int?) ?? 0), style: const TextStyle(fontWeight: FontWeight.bold)),
        ))),
      ]);
    },
  );
  Widget _stat(String title, String value, IconData icon) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
    Icon(icon, color: const Color(0xFF147D70), size: 28), const SizedBox(width: 12),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.black54)), Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))])
  ])));
}

class ClientsPage extends StatefulWidget {
  final VoidCallback onChanged;
  const ClientsPage({super.key, required this.onChanged});
  @override State<ClientsPage> createState() => _ClientsPageState();
}
class _ClientsPageState extends State<ClientsPage> {
  Future<void> addClient() async {
    final name = TextEditingController(), phone = TextEditingController(), note = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('ثبت مشتری جدید'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'نام مشتری *')),
        const SizedBox(height: 10), TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'شماره تماس')),
        const SizedBox(height: 10), TextField(controller: note, decoration: const InputDecoration(labelText: 'یادداشت')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('انصراف')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('ذخیره'))],
    ));
    if (ok == true && name.text.trim().isNotEmpty) {
      await AppDb.instance.add('clients', {'name': name.text.trim(), 'phone': phone.text.trim(), 'note': note.text.trim()});
      widget.onChanged();
    }
  }
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    floatingActionButton: FloatingActionButton.extended(onPressed: addClient, icon: const Icon(Icons.add), label: const Text('مشتری جدید')),
    body: FutureBuilder(future: AppDb.instance.rows('clients'), builder: (c,s) {
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      final list = s.data!;
      if (list.isEmpty) return const _Empty(text: 'فهرست مشتری‌ها خالی است. مشتری‌هایت را اینجا ثبت کن.');
      return ListView.builder(padding: const EdgeInsets.all(12), itemCount: list.length, itemBuilder: (c,i) {
        final x = list[i];
        return Card(child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
          title: Text('${x['name']}'),
          subtitle: Text('${x['phone'] ?? ''}${(x['note'] as String? ?? '').isEmpty ? '' : '\n${x['note']}'}'),
          isThreeLine: (x['note'] as String? ?? '').isNotEmpty,
          trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async { await AppDb.instance.remove('clients', x['id'] as int); widget.onChanged(); }),
        ));
      });
    }),
  );
}

class JobsPage extends StatefulWidget {
  final VoidCallback onChanged;
  const JobsPage({super.key, required this.onChanged});
  @override State<JobsPage> createState() => _JobsPageState();
}
class _JobsPageState extends State<JobsPage> {
  Future<void> addJob() async {
    final title = TextEditingController(), client = TextEditingController(), amount = TextEditingController();
    String status = 'درحال انجام';
    final ok = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
      title: const Text('ثبت سفارش'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان سفارش *')),
        const SizedBox(height: 10), TextField(controller: client, decoration: const InputDecoration(labelText: 'نام مشتری')),
        const SizedBox(height: 10), TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مبلغ توافقی (تومان)')),
        const SizedBox(height: 10), DropdownButtonFormField<String>(initialValue: status, decoration: const InputDecoration(labelText: 'وضعیت'), items: const ['درحال انجام','تمام‌شده','لغوشده'].map((e) => DropdownMenuItem(value:e,child:Text(e))).toList(), onChanged: (v) => setD(() => status = v ?? status)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('انصراف')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('ذخیره'))],
    )));
    if (ok == true && title.text.trim().isNotEmpty) {
      await AppDb.instance.add('jobs', {'title': title.text.trim(), 'client': client.text.trim(), 'amount': parseAmount(amount.text) ?? 0, 'status': status, 'created': today()});
      widget.onChanged();
    }
  }
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    floatingActionButton: FloatingActionButton.extended(onPressed: addJob, icon: const Icon(Icons.add), label: const Text('سفارش جدید')),
    body: FutureBuilder(future: AppDb.instance.rows('jobs'), builder: (c,s) {
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      final list = s.data!;
      if (list.isEmpty) return const _Empty(text: 'هنوز سفارشی ثبت نشده است.');
      return ListView.builder(padding: const EdgeInsets.all(12), itemCount: list.length, itemBuilder: (c,i) {
        final x = list[i];
        return Card(child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.assignment_outlined)),
          title: Text('${x['title']}'),
          subtitle: Text('${x['client'] ?? ''} • ${x['status']}'),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(money((x['amount'] as int?) ?? 0), style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.delete_outline, size: 19), onPressed: () async { await AppDb.instance.remove('jobs', x['id'] as int); widget.onChanged(); })
          ]),
        ));
      });
    }),
  );
}

class LedgerPage extends StatefulWidget {
  final VoidCallback onChanged;
  const LedgerPage({super.key, required this.onChanged});
  @override State<LedgerPage> createState() => _LedgerPageState();
}
class _LedgerPageState extends State<LedgerPage> {
  Future<void> addEntry(String kind) async {
    final title = TextEditingController(), amount = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Text(kind == 'income' ? 'ثبت دریافتی' : 'ثبت هزینه'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'شرح')),
        const SizedBox(height: 10), TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مبلغ (تومان)')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('انصراف')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('ذخیره'))],
    ));
    final n = parseAmount(amount.text);
    if (ok == true && n != null && n > 0) {
      await AppDb.instance.add('entries', {'kind': kind, 'title': title.text.trim().isEmpty ? (kind == 'income' ? 'دریافتی' : 'هزینه') : title.text.trim(), 'amount': n, 'created': today()});
      widget.onChanged();
    }
  }
  @override Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    future: Future.wait([AppDb.instance.rows('entries'), AppDb.instance.total('income'), AppDb.instance.total('expense')]),
    builder: (c,s) {
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      final entries = s.data![0] as List<Map<String,Object?>>;
      final income = s.data![1] as int, expense = s.data![2] as int;
      return ListView(padding: const EdgeInsets.all(14), children: [
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: () => addEntry('income'), icon: const Icon(Icons.add), label: const Text('دریافتی'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: () => addEntry('expense'), icon: const Icon(Icons.remove), label: const Text('هزینه'))),
        ]),
        const SizedBox(height: 14),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          _line('مجموع دریافتی', income, Colors.green),
          const Divider(height: 22),
          _line('مجموع هزینه', expense, Colors.red),
          const Divider(height: 22),
          _line('مانده', income-expense, const Color(0xFF147D70), bold: true),
        ]))),
        const SizedBox(height: 14),
        const Text('گردش مالی', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        if (entries.isEmpty) const _Empty(text: 'هنوز دریافتی یا هزینه‌ای ثبت نکردی.'),
        ...entries.map((e) => Card(child: ListTile(
          leading: Icon(e['kind'] == 'income' ? Icons.south_west : Icons.north_east, color: e['kind'] == 'income' ? Colors.green : Colors.red),
          title: Text('${e['title']}'),
          subtitle: Text('${e['created']}'),
          trailing: Text('${e['kind'] == 'income' ? '+' : '-'}${money((e['amount'] as int?) ?? 0)}', style: TextStyle(fontWeight: FontWeight.bold, color: e['kind'] == 'income' ? Colors.green : Colors.red)),
        ))),
      ]);
    },
  );
  Widget _line(String label, int amount, Color color, {bool bold = false}) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
    Text('${money(amount)} تومان', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: bold ? 18 : 15)),
  ]);
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty({required this.text});
  @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
    const SizedBox(height: 12), Text(text, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, height: 1.8)),
  ])));
}
