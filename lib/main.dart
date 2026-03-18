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
        fontFamily: 'Pretendard',
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

  void _updateState() { setState(() {}); _saveData(); }
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('maxMiss', _maxMissAllowance);
    await prefs.setString('startDate', _startDate.toIso8601String());
    await prefs.setString('endDate', _endDate.toIso8601String());
    await prefs.setString('records', jsonEncode(_records.map((k, v) => MapEntry(k, v.toJson()))));
  }

  // [핵심] 실시간 남은 횟수 계산기
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
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          title: const Text('SETTINGS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 2)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'MAX MISSES', labelStyle: TextStyle(fontSize: 12)),
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: tempMiss.toString()),
                onChanged: (v) => tempMiss = int.tryParse(v) ?? tempMiss,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('START DATE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                subtitle: Text(DateFormat('yyyy.MM.dd').format(tempStart)),
                onTap: () async {
                  DateTime? picked = await showDatePicker(context: context, initialDate: tempStart, firstDate: DateTime(2024), lastDate: DateTime(2030));
                  if (picked != null) setDialogState(() => tempStart = picked);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('END DATE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                subtitle: Text(DateFormat('yyyy.MM.dd').format(tempEnd)),
                onTap: () async {
                  DateTime? picked = await showDatePicker(context: context, initialDate: tempEnd, firstDate: DateTime(2024), lastDate: DateTime(2030));
                  if (picked != null) setDialogState(() => tempEnd = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE', style: TextStyle(color: Colors.black))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
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
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.black)));
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _selectedIndex, children: [
            TodayScreen(getRecord: (d) => _records.putIfAbsent(DateFormat('yyyy-MM-dd').format(d), () => DayRecord()), onUpdate: _updateState),
            CalendarScreen(records: _records, remaining: remainingMisses, onSettings: _showSettings, onUpdate: _updateState),
          ]),
          Positioned(
            left: _buttonPos.dx, top: _buttonPos.dy,
            child: GestureDetector(
              onPanUpdate: (details) => setState(() => _buttonPos += details.delta),
              onTap: () => setState(() => _selectedIndex = (_selectedIndex == 0 ? 1 : 0)),
              child: Container(
                width: 65, height: 65,
                decoration: BoxDecoration(color: Colors.black, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)]),
                child: Icon(_selectedIndex == 0 ? Icons.calendar_month : Icons.access_time_filled, color: Colors.white, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- [TODAY SCREEN] ---
class TodayScreen extends StatefulWidget {
  final DayRecord Function(DateTime) getRecord;
  final VoidCallback onUpdate;
  const TodayScreen({super.key, required this.getRecord, required this.onUpdate});
  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late Timer _timer;
  DateTime _now = DateTime.now();
  final TextEditingController _todoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) { if (mounted) setState(() => _now = DateTime.now()); });
  }

  @override
  void dispose() { _timer.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    DayRecord today = widget.getRecord(_now);
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Text('TODAY', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 8)),
            Text(DateFormat('2026.MM.dd').format(_now), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w300, letterSpacing: 2, color: Colors.black45)),
            const SizedBox(height: 40),
            Column(children: [
              Text(DateFormat('HH').format(_now), style: const TextStyle(fontSize: 82, fontWeight: FontWeight.w100, height: 0.9)),
              Text(DateFormat('mm').format(_now), style: const TextStyle(fontSize: 82, fontWeight: FontWeight.w100, height: 1.0)),
            ]),
            const SizedBox(height: 50),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(children: [
                _checkBtn('MORNING', Icons.wb_sunny_outlined, today.morning, () { today.morning = !today.morning; widget.onUpdate(); }),
                const SizedBox(width: 15),
                _checkBtn('EVENING', Icons.nightlight_outlined, today.evening, () { today.evening = !today.evening; widget.onUpdate(); }),
              ]),
            ),
            const SizedBox(height: 30),
            Container(
              margin: const EdgeInsets.fromLTRB(30, 0, 30, 150),
              padding: const EdgeInsets.all(35),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(45), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 20)]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('MISSIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 2)),
                  ...today.todos.asMap().entries.map((e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: GestureDetector(onTap: () { e.value.isDone = !e.value.isDone; widget.onUpdate(); }, child: Icon(e.value.isDone ? Icons.check_circle : Icons.circle_outlined, color: Colors.black, size: 20)),
                    title: Text(e.value.task, style: TextStyle(fontSize: 14, decoration: e.value.isDone ? TextDecoration.lineThrough : null, color: e.value.isDone ? Colors.black26 : Colors.black)),
                    trailing: IconButton(icon: const Icon(Icons.close, size: 14), onPressed: () { today.todos.removeAt(e.key); widget.onUpdate(); }),
                  )),
                  const SizedBox(height: 5),
                  TextField(
                    controller: _todoController,
                    decoration: const InputDecoration(hintText: '+ Add mission', border: InputBorder.none, hintStyle: TextStyle(fontSize: 12, color: Colors.black26)),
                    onSubmitted: (v) { if (v.trim().isNotEmpty) { today.todos.add(TodoItem(v.trim())); widget.onUpdate(); _todoController.clear(); } },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkBtn(String label, IconData icon, bool isDone, VoidCallback onTap) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(color: isDone ? Colors.black : Colors.white, borderRadius: BorderRadius.circular(25), border: isDone ? null : Border.all(color: Colors.black.withOpacity(0.05))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: isDone ? Colors.white : Colors.black, size: 16), const SizedBox(width: 8), Text(label, style: TextStyle(color: isDone ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 10))]),
      ),
    ),
  );
}

// --- [CALENDAR SCREEN] ---
class CalendarScreen extends StatelessWidget {
  final Map<String, DayRecord> records;
  final int remaining;
  final VoidCallback onSettings;
  final VoidCallback onUpdate;

  const CalendarScreen({super.key, required this.records, required this.remaining, required this.onSettings, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    int daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, actions: [IconButton(icon: const Icon(Icons.tune, color: Colors.black), onPressed: onSettings)]),
      body: Column(
        children: [
          // [디자인] 연도 표시 복구
          const Text('2026', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w300, letterSpacing: 10, color: Colors.black26)),
          const SizedBox(height: 12),
          // [디자인] 월 이름 표시 복구
          Text(DateFormat('MMMM').format(now).toUpperCase(), style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w200, letterSpacing: 2.5, color: Colors.black, height: 1.0)),
          const SizedBox(height: 40),
          const Text('REMAINING MISSES', style: TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.black26)),
          // [실시간] 남은 횟수 숫자
          Text(remaining.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 65, fontWeight: FontWeight.w100)),
          const SizedBox(height: 30),
          // [디자인] 달력 그리드 & 색칠 기능 복구
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 15, crossAxisSpacing: 15),
              itemCount: daysInMonth,
              itemBuilder: (context, index) {
                DateTime d = DateTime(now.year, now.month, index + 1);
                String dateKey = DateFormat('yyyy-MM-dd').format(d);
                DayRecord r = records.putIfAbsent(dateKey, () => DayRecord());
                bool isSunday = d.weekday == DateTime.sunday;
                bool isAllDone = r.morning && r.evening;

                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: isSunday ? Colors.black.withOpacity(0.08) : Colors.black.withOpacity(0.04)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(size: Size.infinite, painter: CirclePainter(r.morning, r.evening)),
                      Text('${index + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: isAllDone ? Colors.white : Colors.black)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// [디자인] 원형 색칠 페인터 복구
class CirclePainter extends CustomPainter {
  final bool m; final bool e;
  CirclePainter(this.m, this.e);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.black..style = PaintingStyle.fill;
    if (m && e) canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2, p);
    else if (m) canvas.drawArc(Rect.fromLTWH(0, 0, size.width, size.height), 1.57, 3.14, true, p);
    else if (e) canvas.drawArc(Rect.fromLTWH(0, 0, size.width, size.height), 4.71, 3.14, true, p);
  }
  @override
  bool shouldRepaint(CustomPainter old) => true;
}
