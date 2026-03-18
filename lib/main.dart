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
              const SizedBox(height: 10),
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
            CalendarScreen(records: _records, onUpdate: _updateState, maxMiss: _maxMissAllowance, startDate: _startDate, endDate: _endDate, onSettings: _showSettings),
          ]),
          Positioned(
            left: _buttonPos.dx, top: _buttonPos.dy,
            child: GestureDetector(
              onPanUpdate: (details) => setState(() => _buttonPos += details.delta),
              onTap: () => setState(() => _selectedIndex = (_selectedIndex == 0 ? 1 : 0)),
              child: Container(
                width: 65, height: 65,
                decoration: BoxDecoration(
                  color: Colors.black, 
                  shape: BoxShape.circle, 
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 6))]
                ),
                child: Icon(_selectedIndex == 0 ? Icons.calendar_month : Icons.access_time_filled, color: Colors.white, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- [PAGE 1: TODAY] ---
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
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(45), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 20, offset: const Offset(0, 10))]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('MISSIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 2)),
                  ...today.todos.asMap().entries.map((e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: GestureDetector(onTap: () { setState(() => e.value.isDone = !e.value.isDone); widget.onUpdate(); }, child: Icon(e.value.isDone ? Icons.check_circle : Icons.circle_outlined, color: Colors.black, size: 20)),
                    title: Text(e.value.task, style: TextStyle(fontSize: 14, decoration: e.value.isDone ? TextDecoration.lineThrough : null, color: e.value.isDone ? Colors.black26 : Colors.black)),
                    trailing: IconButton(icon: const Icon(Icons.close, size: 14), onPressed: () { setState(() => today.todos.removeAt(e.key)); widget.onUpdate(); }),
                  )).toList(),
                  const SizedBox(height: 5),
                  TextField(
                    controller: _todoController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(hintText: '+ Add mission', border: InputBorder.none, hintStyle: TextStyle(fontSize: 12, color: Colors.black26)),
                    onSubmitted: (v) { if (v.trim().isNotEmpty) { setState(() => today.todos.add(TodoItem(v.trim()))); widget.onUpdate(); _todoController.clear(); } },
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

// --- [PAGE 2: CALENDAR] ---
class CalendarScreen extends StatelessWidget {
  final Map<String, DayRecord> records;
  final int maxMiss;
  final DateTime startDate;
  final DateTime endDate; // endDate 추가됨
  final VoidCallback onSettings;
  final VoidCallback onUpdate;

  const CalendarScreen({super.key, required this.records, required this.maxMiss, required this.startDate, required this.endDate, required this.onSettings, required this.onUpdate});

  // [수정된 부분] 남은 결석 횟수 계산 함수
  int _calculateRemaining() {
    DateTime now = DateTime.now();
    int missCount = 0;
    
    // 시작일부터 오늘(혹은 종료일 중 빠른 날)까지 체크
    DateTime checkUntil = now.isBefore(endDate) ? now : endDate;
    
    for (int i = 0; i <= checkUntil.difference(startDate).inDays; i++) {
      DateTime day = startDate.add(Duration(days: i));
      String key = DateFormat('yyyy-MM-dd').format(day);
      DayRecord? r = records[key];
      
      // 기록이 없거나, 아침/저녁 중 하나라도 안 되어있으면 결석 카운트
      if (r == null || (!r.morning || !r.evening)) {
        missCount++;
      }
    }
    return maxMiss - missCount;
  }

  void _showDayDetails(BuildContext context, String dateKey, DayRecord record, bool isModifiable) {
    final TextEditingController dialogController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35)),
          child: Padding(
            padding: const EdgeInsets.all(35),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateKey.replaceAll('-', '.'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w200, letterSpacing: 1)),
                const SizedBox(height: 25),
                const Text('MISSIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 2)),
                const SizedBox(height: 15),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: record.todos.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              setDialogState(() => record.todos[i].isDone = !record.todos[i].isDone);
                              onUpdate();
                            },
                            child: Icon(record.todos[i].isDone ? Icons.check_circle : Icons.circle_outlined, size: 18, color: Colors.black),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(record.todos[i].task, style: TextStyle(fontSize: 14, color: record.todos[i].isDone ? Colors.black26 : Colors.black, decoration: record.todos[i].isDone ? TextDecoration.lineThrough : null)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 14),
                            onPressed: () {
                              setDialogState(() => record.todos.removeAt(i));
                              onUpdate();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isModifiable) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: dialogController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(hintText: '+ Add mission', border: InputBorder.none, hintStyle: TextStyle(fontSize: 12, color: Colors.black26)),
                    onSubmitted: (v) {
                      if (v.trim().isNotEmpty) {
                        setDialogState(() => record.todos.add(TodoItem(v.trim())));
                        onUpdate();
                        dialogController.clear();
                      }
                    },
                  ),
                ],
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CLOSE'),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    int remaining = _calculateRemaining(); // [수정] 실시간 계산된 값

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, actions: [IconButton(icon: const Icon(Icons.tune, color: Colors.black), onPressed: onSettings)]),
      body: Column(
        children: [
          const Text('2026', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w300, letterSpacing: 10, color: Colors.black26)),
          const SizedBox(height: 12),
          Text(DateFormat('MMMM').format(now).toUpperCase(), style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w200, letterSpacing: 2.5, color: Colors.black, height: 1.0)),
          const SizedBox(height: 40),
          const Text('REMAINING MISSES', style: TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.black26)),
          // [수정된 부분] 고정된 '08' 대신 변수를 연결
          Text(
            remaining < 0 ? '00' : remaining.toString().padLeft(2, '0'), 
            style: const TextStyle(fontSize: 65, fontWeight: FontWeight.w100)
          ),
          const SizedBox(height: 30),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 15, crossAxisSpacing: 15),
              itemCount: daysInMonth,
              itemBuilder: (context, index) {
                DateTime d = DateTime(now.year, now.month, index + 1);
                String dateKey = DateFormat('yyyy-MM-dd').format(d);
                DayRecord r = records.putIfAbsent(dateKey, () => DayRecord());
                bool allDone = r.todos.isNotEmpty && r.todos.every((t) => t.isDone);
                bool isSunday = d.weekday == DateTime.sunday;
                
                bool isModifiable = d.isAfter(now.subtract(const Duration(days: 1))) && d.isBefore(now.add(const Duration(days: 8)));

                return GestureDetector(
                  onTap: () => _showDayDetails(context, dateKey, r, isModifiable),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: allDone ? const Color(0xFFA04040) : (isSunday ? Colors.black.withOpacity(0.08) : Colors.black.withOpacity(0.04)),
                        width: allDone ? 3.0 : 1.0,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(size: Size.infinite, painter: CirclePainter(r.morning, r.evening)),
                        Text('${index + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: (r.morning && r.evening) ? Colors.white : Colors.black)),
                      ],
                    ),
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
    await prefs.setInt('maxMiss', _maxMissAllowance);
    await prefs.setString('startDate', _startDate.toIso8601String());
    await prefs.setString('endDate', _endDate.toIso8601String());
    await prefs.setString('records', jsonEncode(_records.map((k, v) => MapEntry(k, v.toJson()))));
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
              const SizedBox(height: 10),
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
            CalendarScreen(records: _records, onUpdate: _updateState, maxMiss: _maxMissAllowance, startDate: _startDate, endDate: _endDate, onSettings: _showSettings),
          ]),
          Positioned(
            left: _buttonPos.dx, top: _buttonPos.dy,
            child: GestureDetector(
              onPanUpdate: (details) => setState(() => _buttonPos += details.delta),
              onTap: () => setState(() => _selectedIndex = (_selectedIndex == 0 ? 1 : 0)),
              child: Container(
                width: 65, height: 65,
                decoration: BoxDecoration(
                  color: Colors.black, 
                  shape: BoxShape.circle, 
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 6))]
                ),
                child: Icon(_selectedIndex == 0 ? Icons.calendar_month : Icons.access_time_filled, color: Colors.white, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- [PAGE 1: TODAY] ---
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
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(45), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 20, offset: const Offset(0, 10))]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('MISSIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 2)),
                  ...today.todos.asMap().entries.map((e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: GestureDetector(onTap: () { setState(() => e.value.isDone = !e.value.isDone); widget.onUpdate(); }, child: Icon(e.value.isDone ? Icons.check_circle : Icons.circle_outlined, color: Colors.black, size: 20)),
                    title: Text(e.value.task, style: TextStyle(fontSize: 14, decoration: e.value.isDone ? TextDecoration.lineThrough : null, color: e.value.isDone ? Colors.black26 : Colors.black)),
                    trailing: IconButton(icon: const Icon(Icons.close, size: 14), onPressed: () { setState(() => today.todos.removeAt(e.key)); widget.onUpdate(); }),
                  )).toList(),
                  const SizedBox(height: 5),
                  TextField(
                    controller: _todoController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(hintText: '+ Add mission', border: InputBorder.none, hintStyle: TextStyle(fontSize: 12, color: Colors.black26)),
                    onSubmitted: (v) { if (v.trim().isNotEmpty) { setState(() => today.todos.add(TodoItem(v.trim()))); widget.onUpdate(); _todoController.clear(); } },
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

// --- [PAGE 2: CALENDAR] ---
class CalendarScreen extends StatelessWidget {
  final Map<String, DayRecord> records;
  final int maxMiss;
  final DateTime startDate;
  final DateTime endDate; // endDate 추가됨
  final VoidCallback onSettings;
  final VoidCallback onUpdate;

  const CalendarScreen({super.key, required this.records, required this.maxMiss, required this.startDate, required this.endDate, required this.onSettings, required this.onUpdate});

  // [수정된 부분] 남은 결석 횟수 계산 함수
  int _calculateRemaining() {
    DateTime now = DateTime.now();
    int missCount = 0;
    
    // 시작일부터 오늘(혹은 종료일 중 빠른 날)까지 체크
    DateTime checkUntil = now.isBefore(endDate) ? now : endDate;
    
    for (int i = 0; i <= checkUntil.difference(startDate).inDays; i++) {
      DateTime day = startDate.add(Duration(days: i));
      String key = DateFormat('yyyy-MM-dd').format(day);
      DayRecord? r = records[key];
      
      // 기록이 없거나, 아침/저녁 중 하나라도 안 되어있으면 결석 카운트
      if (r == null || (!r.morning || !r.evening)) {
        missCount++;
      }
    }
    return maxMiss - missCount;
  }

  void _showDayDetails(BuildContext context, String dateKey, DayRecord record, bool isModifiable) {
    final TextEditingController dialogController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35)),
          child: Padding(
            padding: const EdgeInsets.all(35),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateKey.replaceAll('-', '.'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w200, letterSpacing: 1)),
                const SizedBox(height: 25),
                const Text('MISSIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 2)),
                const SizedBox(height: 15),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: record.todos.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              setDialogState(() => record.todos[i].isDone = !record.todos[i].isDone);
                              onUpdate();
                            },
                            child: Icon(record.todos[i].isDone ? Icons.check_circle : Icons.circle_outlined, size: 18, color: Colors.black),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(record.todos[i].task, style: TextStyle(fontSize: 14, color: record.todos[i].isDone ? Colors.black26 : Colors.black, decoration: record.todos[i].isDone ? TextDecoration.lineThrough : null)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 14),
                            onPressed: () {
                              setDialogState(() => record.todos.removeAt(i));
                              onUpdate();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isModifiable) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: dialogController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(hintText: '+ Add mission', border: InputBorder.none, hintStyle: TextStyle(fontSize: 12, color: Colors.black26)),
                    onSubmitted: (v) {
                      if (v.trim().isNotEmpty) {
                        setDialogState(() => record.todos.add(TodoItem(v.trim())));
                        onUpdate();
                        dialogController.clear();
                      }
                    },
                  ),
                ],
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CLOSE'),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    int remaining = _calculateRemaining(); // [수정] 실시간 계산된 값

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, actions: [IconButton(icon: const Icon(Icons.tune, color: Colors.black), onPressed: onSettings)]),
      body: Column(
        children: [
          const Text('2026', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w300, letterSpacing: 10, color: Colors.black26)),
          const SizedBox(height: 12),
          Text(DateFormat('MMMM').format(now).toUpperCase(), style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w200, letterSpacing: 2.5, color: Colors.black, height: 1.0)),
          const SizedBox(height: 40),
          const Text('REMAINING MISSES', style: TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.black26)),
          // [수정된 부분] 고정된 '08' 대신 변수를 연결
          Text(
            remaining < 0 ? '00' : remaining.toString().padLeft(2, '0'), 
            style: const TextStyle(fontSize: 65, fontWeight: FontWeight.w100)
          ),
          const SizedBox(height: 30),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 15, crossAxisSpacing: 15),
              itemCount: daysInMonth,
              itemBuilder: (context, index) {
                DateTime d = DateTime(now.year, now.month, index + 1);
                String dateKey = DateFormat('yyyy-MM-dd').format(d);
                DayRecord r = records.putIfAbsent(dateKey, () => DayRecord());
                bool allDone = r.todos.isNotEmpty && r.todos.every((t) => t.isDone);
                bool isSunday = d.weekday == DateTime.sunday;
                
                bool isModifiable = d.isAfter(now.subtract(const Duration(days: 1))) && d.isBefore(now.add(const Duration(days: 8)));

                return GestureDetector(
                  onTap: () => _showDayDetails(context, dateKey, r, isModifiable),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: allDone ? const Color(0xFFA04040) : (isSunday ? Colors.black.withOpacity(0.08) : Colors.black.withOpacity(0.04)),
                        width: allDone ? 3.0 : 1.0,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(size: Size.infinite, painter: CirclePainter(r.morning, r.evening)),
                        Text('${index + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: (r.morning && r.evening) ? Colors.white : Colors.black)),
                      ],
                    ),
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
              const SizedBox(height: 10),
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
            CalendarScreen(records: _records, onUpdate: _updateState, maxMiss: _maxMissAllowance, startDate: _startDate, onSettings: _showSettings),
          ]),
          Positioned(
            left: _buttonPos.dx, top: _buttonPos.dy,
            child: GestureDetector(
              onPanUpdate: (details) => setState(() => _buttonPos += details.delta),
              onTap: () => setState(() => _selectedIndex = (_selectedIndex == 0 ? 1 : 0)),
              child: Container(
                width: 65, height: 65,
                decoration: BoxDecoration(
                  color: Colors.black, 
                  shape: BoxShape.circle, 
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 6))]
                ),
                child: Icon(_selectedIndex == 0 ? Icons.calendar_month : Icons.access_time_filled, color: Colors.white, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- [PAGE 1: TODAY] ---
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
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(45), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 20, offset: const Offset(0, 10))]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('MISSIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 2)),
                  ...today.todos.asMap().entries.map((e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: GestureDetector(onTap: () { setState(() => e.value.isDone = !e.value.isDone); widget.onUpdate(); }, child: Icon(e.value.isDone ? Icons.check_circle : Icons.circle_outlined, color: Colors.black, size: 20)),
                    title: Text(e.value.task, style: TextStyle(fontSize: 14, decoration: e.value.isDone ? TextDecoration.lineThrough : null, color: e.value.isDone ? Colors.black26 : Colors.black)),
                    trailing: IconButton(icon: const Icon(Icons.close, size: 14), onPressed: () { setState(() => today.todos.removeAt(e.key)); widget.onUpdate(); }),
                  )).toList(),
                  const SizedBox(height: 5),
                  TextField(
                    controller: _todoController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(hintText: '+ Add mission', border: InputBorder.none, hintStyle: TextStyle(fontSize: 12, color: Colors.black26)),
                    onSubmitted: (v) { if (v.trim().isNotEmpty) { setState(() => today.todos.add(TodoItem(v.trim()))); widget.onUpdate(); _todoController.clear(); } },
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

// --- [PAGE 2: CALENDAR] ---
class CalendarScreen extends StatelessWidget {
  final Map<String, DayRecord> records;
  final int maxMiss;
  final DateTime startDate;
  final VoidCallback onSettings;
  final VoidCallback onUpdate;

  const CalendarScreen({super.key, required this.records, required this.maxMiss, required this.startDate, required this.onSettings, required this.onUpdate});

  void _showDayDetails(BuildContext context, String dateKey, DayRecord record, bool isModifiable) {
    final TextEditingController dialogController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35)),
          child: Padding(
            padding: const EdgeInsets.all(35),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateKey.replaceAll('-', '.'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w200, letterSpacing: 1)),
                const SizedBox(height: 25),
                const Text('MISSIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 2)),
                const SizedBox(height: 15),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: record.todos.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              setDialogState(() => record.todos[i].isDone = !record.todos[i].isDone);
                              onUpdate();
                            },
                            child: Icon(record.todos[i].isDone ? Icons.check_circle : Icons.circle_outlined, size: 18, color: Colors.black),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(record.todos[i].task, style: TextStyle(fontSize: 14, color: record.todos[i].isDone ? Colors.black26 : Colors.black, decoration: record.todos[i].isDone ? TextDecoration.lineThrough : null)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 14),
                            onPressed: () {
                              setDialogState(() => record.todos.removeAt(i));
                              onUpdate();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isModifiable) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: dialogController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(hintText: '+ Add mission', border: InputBorder.none, hintStyle: TextStyle(fontSize: 12, color: Colors.black26)),
                    onSubmitted: (v) {
                      if (v.trim().isNotEmpty) {
                        setDialogState(() => record.todos.add(TodoItem(v.trim())));
                        onUpdate();
                        dialogController.clear();
                      }
                    },
                  ),
                ],
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CLOSE'),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    int daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, actions: [IconButton(icon: const Icon(Icons.tune, color: Colors.black), onPressed: onSettings)]),
      body: Column(
        children: [
          const Text('2026', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w300, letterSpacing: 10, color: Colors.black26)),
          const SizedBox(height: 12),
          Text(DateFormat('MMMM').format(now).toUpperCase(), style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w200, letterSpacing: 2.5, color: Colors.black, height: 1.0)),
          const SizedBox(height: 40),
          const Text('REMAINING MISSES', style: TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.black26)),
          const Text('08', style: TextStyle(fontSize: 65, fontWeight: FontWeight.w100)),
          const SizedBox(height: 30),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 15, crossAxisSpacing: 15),
              itemCount: daysInMonth,
              itemBuilder: (context, index) {
                DateTime d = DateTime(now.year, now.month, index + 1);
                String dateKey = DateFormat('yyyy-MM-dd').format(d);
                DayRecord r = records.putIfAbsent(dateKey, () => DayRecord());
                bool allDone = r.todos.isNotEmpty && r.todos.every((t) => t.isDone);
                bool isSunday = d.weekday == DateTime.sunday;
                
                // 오늘부터 7일 이내의 날짜는 수정 가능하도록 설정
                bool isModifiable = d.isAfter(now.subtract(const Duration(days: 1))) && d.isBefore(now.add(const Duration(days: 8)));

                return GestureDetector(
                  onTap: () => _showDayDetails(context, dateKey, r, isModifiable),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: allDone ? const Color(0xFFA04040) : (isSunday ? Colors.black.withOpacity(0.08) : Colors.black.withOpacity(0.04)),
                        width: allDone ? 3.0 : 1.0,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(size: Size.infinite, painter: CirclePainter(r.morning, r.evening)),
                        Text('${index + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: (r.morning && r.evening) ? Colors.white : Colors.black)),
                      ],
                    ),
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
