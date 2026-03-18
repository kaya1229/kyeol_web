import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

void main() => runApp(const DisciplineApp());

class DisciplineApp extends StatelessWidget {
  const DisciplineApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: const Color(0xFFFAF9F6)),
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
  factory TodoItem.fromJson(Map<String, dynamic> json) => TodoItem(json['task'] ?? '', isDone: json['isDone'] ?? false);
}

class DayRecord {
  bool morning; bool evening; List<TodoItem> todos;
  DayRecord({this.morning = false, this.evening = false, List<TodoItem>? todos}) : todos = todos ?? [];
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
    try {
      final prefs = await SharedPreferences.getInstance();
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
    } catch (e) { setState(() => _isLoading = false); }
  }

  void _updateState() { setState(() {}); _saveData(); }
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('maxMiss', _maxMissAllowance);
    await prefs.setString('startDate', _startDate.toIso8601String());
    await prefs.setString('endDate', _endDate.toIso8601String());
    await prefs.setString('records', jsonEncode(_records.map((k, v) => MapEntry(k, v.toJson()))));
  }

  // [핵심] 결석 횟수를 계산하는 로직을 부모가 직접 수행합니다.
  int get remainingMisses {
    int missCount = 0;
    DateTime now = DateTime.now();
    DateTime checkUntil = now.isBefore(_endDate) ? now : _endDate;

    for (int i = 0; i <= checkUntil.difference(_startDate).inDays; i++) {
      DateTime day = _startDate.add(Duration(days: i));
      String key = DateFormat('yyyy-MM-dd').format(day);
      DayRecord? r = _records[key];
      // 기록이 없거나 아침/저녁 중 하나라도 false면 결석
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
          title: const Text('SETTINGS'),
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
              ListTile(
                title: const Text('END DATE'),
                subtitle: Text(DateFormat('yyyy.MM.dd').format(tempEnd)),
                onTap: () async {
                  DateTime? picked = await showDatePicker(context: context, initialDate: tempEnd, firstDate: DateTime(2024), lastDate: DateTime(2030));
                  if (picked != null) setDialogState(() => tempEnd = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() { 
                  _maxMissAllowance = tempMiss; 
                  _startDate = tempStart; 
                  _endDate = tempEnd; 
                });
                _updateState(); // 저장 및 리빌드
                Navigator.pop(context);
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
          // IndexedStack이 자식들을 들고 있을 때, 
          // 부모의 setState가 불리면 자식들도 새로운 파라미터로 다시 빌드됩니다.
          IndexedStack(index: _selectedIndex, children: [
            TodayView(
              getRecord: (d) => _records.putIfAbsent(DateFormat('yyyy-MM-dd').format(d), () => DayRecord()), 
              onUpdate: _updateState
            ),
            CalendarView(
              remaining: remainingMisses, // 계산된 값을 직접 넘겨줌
              onSettings: _showSettings,
            ),
          ]),
          Positioned(
            left: _buttonPos.dx, top: _buttonPos.dy,
            child: GestureDetector(
              onPanUpdate: (details) => setState(() => _buttonPos += details.delta),
              onTap: () => setState(() => _selectedIndex = (_selectedIndex == 0 ? 1 : 0)),
              child: Container(
                width: 60, height: 60,
                decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                child: Icon(_selectedIndex == 0 ? Icons.calendar_month : Icons.timer, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- [TODAY VIEW] --- (내용 동일하지만 최적화)
class TodayView extends StatefulWidget {
  final DayRecord Function(DateTime) getRecord;
  final VoidCallback onUpdate;
  const TodayView({super.key, required this.getRecord, required this.onUpdate});
  @override
  State<TodayView> createState() => _TodayViewState();
}

class _TodayViewState extends State<TodayView> {
  final TextEditingController _todoController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    DayRecord record = widget.getRecord(now);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(DateFormat('HH:mm').format(now), style: const TextStyle(fontSize: 80, fontWeight: FontWeight.w100)),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _btn("MORNING", record.morning, () { setState(() => record.morning = !record.morning); widget.onUpdate(); }),
              const SizedBox(width: 10),
              _btn("EVENING", record.evening, () { setState(() => record.evening = !record.evening); widget.onUpdate(); }),
            ],
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 50),
            child: TextField(
              controller: _todoController,
              decoration: const InputDecoration(hintText: "Add Mission"),
              onSubmitted: (v) { if(v.isNotEmpty) { setState(()=>record.todos.add(TodoItem(v))); widget.onUpdate(); _todoController.clear(); } },
            ),
          ),
        ],
      ),
    );
  }
  Widget _btn(String txt, bool val, VoidCallback fn) => ElevatedButton(
    onPressed: fn, 
    style: ElevatedButton.styleFrom(backgroundColor: val ? Colors.black : Colors.white),
    child: Text(txt, style: TextStyle(color: val ? Colors.white : Colors.black)),
  );
}

// --- [CALENDAR VIEW] --- (실시간 파라미터를 받음)
class CalendarView extends StatelessWidget {
  final int remaining;
  final VoidCallback onSettings;

  const CalendarView({super.key, required this.remaining, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, actions: [IconButton(icon: const Icon(Icons.settings), onPressed: onSettings)]),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("REMAINING MISSES", style: TextStyle(letterSpacing: 2, color: Colors.grey)),
          const SizedBox(height: 10),
          // 부모로부터 받은 remaining 값을 그대로 보여줌
          Text("${remaining}".padLeft(2, '0'), style: const TextStyle(fontSize: 100, fontWeight: FontWeight.w100)),
          const SizedBox(height: 40),
          const Text("Keep going!", style: TextStyle(color: Colors.black26)),
        ],
      ),
    );
  }
}
