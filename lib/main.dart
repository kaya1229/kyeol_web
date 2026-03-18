import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DisciplineApp());
}

class DisciplineApp extends StatelessWidget {
  const DisciplineApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFAF9F6),
      ),
      home: const NavigationScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- [DATA MODELS] ---
class TodoItem {
  String task; bool isDone;
  TodoItem(this.task, {this.isDone = false});
  Map<String, dynamic> toJson() => {'task': task, 'isDone': isDone};
  factory TodoItem.fromJson(Map<String, dynamic> json) => 
      TodoItem(json['task'] ?? '', isDone: json['isDone'] ?? false);
}

class DayRecord {
  bool morning; bool evening; List<TodoItem> todos;
  DayRecord({this.morning = false, this.evening = false, List<TodoItem>? todos}) 
      : todos = todos ?? [];
  Map<String, dynamic> toJson() => {'morning': morning, 'evening': evening, 'todos': todos.map((e) => e.toJson()).toList()};
  factory DayRecord.fromJson(Map<String, dynamic> json) => DayRecord(
    morning: json['morning'] ?? false, evening: json['evening'] ?? false, 
    todos: (json['todos'] as List?)?.map((e) => TodoItem.fromJson(e)).toList() ?? []
  );
}

// --- [MAIN NAVIGATION] ---
class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});
  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  int _selectedIndex = 0;
  Offset _buttonPos = const Offset(280, 550); 
  int _maxMissAllowance = 10;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  Map<String, DayRecord> _records = {};
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _maxMissAllowance = prefs.getInt('maxMiss') ?? 10;
        _startDate = DateTime.parse(prefs.getString('startDate') ?? DateTime.now().toIso8601String());
        _endDate = DateTime.parse(prefs.getString('endDate') ?? DateTime.now().add(const Duration(days: 30)).toIso8601String());
        String? saved = prefs.getString('records');
        if (saved != null) {
          Map<String, dynamic> decoded = jsonDecode(saved);
          _records = decoded.map((k, v) => MapEntry(k, DayRecord.fromJson(v)));
        }
        _isLoading = false;
      });
    }
  }

  void _updateState() { if (mounted) setState(() {}); _saveData(); }
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('maxMiss', _maxMissAllowance);
    await prefs.setString('startDate', _startDate.toIso8601String());
    await prefs.setString('endDate', _endDate.toIso8601String());
    await prefs.setString('records', jsonEncode(_records.map((k, v) => MapEntry(k, v.toJson()))));
  }

  int get remainingMisses {
    int missCount = 0;
    DateTime now = DateTime.now();
    for (int i = 0; i <= now.difference(_startDate).inDays; i++) {
      DateTime day = _startDate.add(Duration(days: i));
      String key = DateFormat('yyyy-MM-dd').format(day);
      DayRecord? r = _records[key];
      if (r == null || !r.morning || !r.evening) missCount++;
    }
    int res = _maxMissAllowance - missCount;
    return res < 0 ? 0 : res;
  }

  void _showSettings() async {
    int tempMiss = _maxMissAllowance;
    DateTime tempStart = _startDate;
    DateTime tempEnd = _endDate;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          title: const Text('SETTINGS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 2)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'MAX MISSES'),
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: tempMiss.toString()),
                onChanged: (v) => tempMiss = int.tryParse(v) ?? tempMiss,
              ),
              ListTile(
                title: const Text('START DATE'),
                subtitle: Text(DateFormat('yyyy.MM.dd').format(tempStart)),
                onTap: () async {
                  DateTime? picked = await showDatePicker(context: context, initialDate: tempStart, firstDate: DateTime(2024), lastDate: DateTime(2030));
                  if (picked != null) setDialogState(() => tempStart = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE')),
            ElevatedButton(
              onPressed: () {
                setState(() { _maxMissAllowance = tempMiss; _startDate = tempStart; _endDate = tempEnd; });
                _updateState(); Navigator.pop(context);
              }, 
              child: const Text('SAVE')
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _selectedIndex, children: [
            TodayTab(getRecord: (d) => _records.putIfAbsent(DateFormat('yyyy-MM-dd').format(d), () => DayRecord()), onUpdate: _updateState),
            CalendarTab(records: _records, remaining: remainingMisses, onSettings: _showSettings),
          ]),
          Positioned(
            left: _buttonPos.dx, top: _buttonPos.dy,
            child: GestureDetector(
              onPanUpdate: (details) => setState(() => _buttonPos += details.delta),
              onTap: () => setState(() => _selectedIndex = (_selectedIndex == 0 ? 1 : 0)),
              child: Container(
                width: 60, height: 60,
                decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                child: Icon(_selectedIndex == 0 ? Icons.calendar_month : Icons.access_time, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- [TABS] ---
class TodayTab extends StatefulWidget {
  final DayRecord Function(DateTime) getRecord;
  final VoidCallback onUpdate;
  const TodayTab({super.key, required this.getRecord, required this.onUpdate});
  @override
  State<TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends State<TodayTab> {
  final TextEditingController _todoController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    DayRecord today = widget.getRecord(now);
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 60),
            const Text('TODAY', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 8)),
            const SizedBox(height: 40),
            Text(DateFormat('HH\nmm').format(now), textAlign: TextAlign.center, style: const TextStyle(fontSize: 80, fontWeight: FontWeight.w100, height: 1.0)),
            const SizedBox(height: 50),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(children: [
                _btn("MORNING", today.morning, () { today.morning = !today.morning; widget.onUpdate(); }),
                const SizedBox(width: 15),
                _btn("EVENING", today.evening, () { today.evening = !today.evening; widget.onUpdate(); }),
              ]),
            ),
            const SizedBox(height: 30),
            Container(
              margin: const EdgeInsets.all(30),
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(40)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('MISSIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ...today.todos.asMap().entries.map((e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(e.value.task),
                    trailing: IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () { setState(() => today.todos.removeAt(e.key)); widget.onUpdate(); }),
                  )),
                  TextField(
                    controller: _todoController,
                    decoration: const InputDecoration(hintText: '+ Add mission', border: InputBorder.none),
                    onSubmitted: (v) { if (v.isNotEmpty) { setState(() => today.todos.add(TodoItem(v))); widget.onUpdate(); _todoController.clear(); } },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _btn(String t, bool active, VoidCallback tap) => Expanded(
    child: ElevatedButton(
      onPressed: tap,
      style: ElevatedButton.styleFrom(backgroundColor: active ? Colors.black : Colors.white),
      child: Text(t, style: TextStyle(color: active ? Colors.white : Colors.black, fontSize: 10)),
    ),
  );
}

class CalendarTab extends StatelessWidget {
  final Map<String, DayRecord> records;
  final int remaining;
  final VoidCallback onSettings;
  const CalendarTab({super.key, required this.records, required this.remaining, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, actions: [IconButton(icon: const Icon(Icons.tune), onPressed: onSettings)]),
      body: Column(
        children: [
          const Text('REMAINING MISSES', style: TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.grey)),
          Text(remaining.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 80, fontWeight: FontWeight.w100)),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(30),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 10, crossAxisSpacing: 10),
              itemCount: 31,
              itemBuilder: (context, i) => Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.black12)), child: Center(child: Text('${i+1}', style: const TextStyle(fontSize: 10)))),
            ),
          )
        ],
      ),
    );
  }
}
