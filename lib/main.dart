import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

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
    db = await openDatabase(path, version: 1, onCreate: (d, v) async {
      await d.execute('CREATE TABLE clients(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, phone TEXT, note TEXT)');
      await d.execute('CREATE TABLE jobs(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, client TEXT, amount INTEGER NOT NULL DEFAULT 0, status TEXT NOT NULL DEFAULT "درحال انجام", created TEXT NOT NULL)');
      await d.execute('CREATE TABLE entries(id INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT NOT NULL, title TEXT NOT NULL, amount INTEGER NOT NULL, created TEXT NOT NULL)');
    });
  }
  Future<List<Map<String,Object?>>> rows(String table) => db.query(table, orderBy: 'id DESC');
  Future<int> add(String table, Map<String,Object?> data) => db.insert(table, data);
  Future<int> remove(String table, int id) => db.delete(table, where: 'id=?', whereArgs: [id]);
  Future<int> total(String kind) async {
    final r = await db.rawQuery('SELECT COALESCE(SUM(amount),0) AS total FROM entries WHERE kind=?', [kind]);
    return (r.first['total'] as int?) ?? 0;
  }
}

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
  @override
  Widget build(BuildContext context) {
    final pages = [
      Dashboard(key: ValueKey('d$refresh')),
      ClientsPage(key: ValueKey('c$refresh'), onChanged: reload),
      JobsPage(key: ValueKey('j$refresh'), onChanged: reload),
      LedgerPage(key: ValueKey('l$refresh'), onChanged: reload),
    ];
    return Directionality(textDirection: ui.TextDirection.rtl, child: Scaffold(
      appBar: AppBar(title: const Text('دفترکار من', style: TextStyle(fontWeight: FontWeight.w800)), actions: [
        IconButton(onPressed: () => showAboutDialog(context: context, applicationName: 'دفترکار من', applicationVersion: '0.1.0', children: const [Text('نسخه اولیه آفلاین؛ اطلاعات فقط روی همین دستگاه ذخیره می‌شود.')]), icon: const Icon(Icons.info_outline))
      ]),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'خانه'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'مشتری‌ها'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'سفارش‌ها'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'حساب‌وکتاب'),
        ],
      ),
    ));
  }
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
          trailing: Text('${money((j['amount'] as int?) ?? 0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
        const SizedBox(height: 10), DropdownButtonFormField<String>(value: status, decoration: const InputDecoration(labelText: 'وضعیت'), items: const ['درحال انجام','تمام‌شده','لغوشده'].map((e) => DropdownMenuItem(value:e,child:Text(e))).toList(), onChanged: (v) => setD(() => status = v ?? status)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('انصراف')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('ذخیره'))],
    )));
    if (ok == true && title.text.trim().isNotEmpty) {
      await AppDb.instance.add('jobs', {'title': title.text.trim(), 'client': client.text.trim(), 'amount': int.tryParse(amount.text.replaceAll(',', '')) ?? 0, 'status': status, 'created': today()});
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
            Text('${money((x['amount'] as int?) ?? 0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
    final n = int.tryParse(amount.text.replaceAll(',', ''));
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
