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
  int _maxMissAllowance = 20; 
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  Map<String, DayRecord> _records = {};
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _maxMissAllowance = prefs.getInt('maxMiss') ?? 20;
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

  int get remainingMisses {
    int missPoints = 0;
    DateTime now = DateTime.now();
    DateTime todayStart = DateTime(now.year, now.month, now.day);
    for (int i = 0; i < todayStart.difference(_startDate).inDays; i++) {
      DateTime day = _startDate.add(Duration(days: i));
      if (day.weekday == DateTime.sunday) continue;
      String key = DateFormat('yyyy-MM-dd').format(day);
      DayRecord r = _records[key] ?? DayRecord();
      if (!r.morning) missPoints++;
      if (!r.evening) missPoints++;
    }
    int res = _maxMissAllowance - missPoints;
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
          title: const Text('SETTINGS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'MAX MISS POINTS'),
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: tempMiss.toString()),
                onChanged: (v) => tempMiss = int.tryParse(v) ?? tempMiss,
              ),
              ListTile(
                title: const Text('START DATE', style: TextStyle(fontSize: 12)),
                subtitle: Text(DateFormat('yyyy.MM.dd').format(tempStart)),
                onTap: () async {
                  DateTime? picked = await showDatePicker(context: context, initialDate: tempStart, firstDate: DateTime(2024), lastDate: DateTime(2030));
                  if (picked != null) setDialogState(() => tempStart = picked);
                },
              ),
              ListTile(
                title: const Text('END DATE', style: TextStyle(fontSize: 12)),
                subtitle: Text(DateFormat('yyyy.MM.dd').format(tempEnd)),
                onTap: () async {
                  DateTime? picked = await showDatePicker(context: context, initialDate: tempEnd, firstDate: DateTime(2024), lastDate: DateTime(2030));
                  if (picked != null) setDialogState(() => tempEnd = picked);
                },
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
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
    bool isSunday = _now.weekday == DateTime.sunday; 
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 60),
            const Text('TODAY', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 8)),
            const SizedBox(height: 15), 
            Text(DateFormat('2026.MM.dd').format(_now), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w300, letterSpacing: 2, color: Colors.black45)),
            const SizedBox(height: 50),
            Column(children: [
              Text(DateFormat('HH').format(_now), style: const TextStyle(fontSize: 82, fontWeight: FontWeight.w100, height: 0.9)),
              Text(DateFormat('mm').format(_now), style: const TextStyle(fontSize: 82, fontWeight: FontWeight.w100, height: 1.0)),
            ]),
            const SizedBox(height: 60),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(children: [
                _checkBtn('MORNING', Icons.wb_sunny_outlined, today.morning, () { if (isSunday) return; today.morning = !today.morning; widget.onUpdate(); }),
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
                    leading: GestureDetector(
                      onTap: () { e.value.isDone = !e.value.isDone; widget.onUpdate(); }, 
                      child: Icon(e.value.isDone ? Icons.check_circle : Icons.circle_outlined, color: Colors.black, size: 20)
                    ),
                    title: Text(e.value.task, style: TextStyle(fontSize: 14, decoration: e.value.isDone ? TextDecoration.lineThrough : null, color: e.value.isDone ? Colors.black26 : Colors.black)),
                    trailing: IconButton(icon: const Icon(Icons.close, size: 14), onPressed: () { today.todos.removeAt(e.key); widget.onUpdate(); }),
                  )),
                  TextField(
                    controller: _todoController,
                    decoration: const InputDecoration(hintText: '+ Add mission', border: InputBorder.none, hintStyle: TextStyle(fontSize: 12, color: Colors.black26)),
                    onSubmitted: (v) { if (v.trim().isNotEmpty) { setState(() { today.todos.add(TodoItem(v.trim())); }); widget.onUpdate(); _todoController.clear(); } },
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
class CalendarScreen extends StatefulWidget {
  final Map<String, DayRecord> records;
  final int remaining;
  final VoidCallback onSettings;
  final VoidCallback onUpdate;
  const CalendarScreen({super.key, required this.records, required this.remaining, required this.onSettings, required this.onUpdate});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _viewDate = DateTime.now();

  void _showDayDetails(BuildContext context, DateTime date) {
    String dateKey = DateFormat('yyyy-MM-dd').format(date);
    DayRecord record = widget.records[dateKey] ?? DayRecord();
    DateTime now = DateTime.now();
    DateTime todayOnly = DateTime(now.year, now.month, now.day);
    bool canEdit = !date.isBefore(todayOnly) && date.isBefore(todayOnly.add(const Duration(days: 8)));
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setPopupState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35)),
          title: Center(child: Text(DateFormat('MMMM dd').format(date).toUpperCase(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 2))),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (record.todos.isEmpty && !canEdit)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Text('No missions.', style: TextStyle(color: Colors.black26, fontSize: 13))),
                if (canEdit) ...[
                  ...record.todos.asMap().entries.map((e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(e.value.isDone ? Icons.check_circle : Icons.circle_outlined, color: Colors.black, size: 18),
                    title: Text(e.value.task, style: const TextStyle(fontSize: 13)),
                    trailing: IconButton(icon: const Icon(Icons.remove_circle_outline, size: 16), onPressed: () { setPopupState(() => record.todos.removeAt(e.key)); widget.onUpdate(); }),
                  )),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: '+ Future plan', filled: true, fillColor: const Color(0xFFF5F5F5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (v) { if (v.trim().isNotEmpty) { setPopupState(() => record.todos.add(TodoItem(v.trim()))); widget.onUpdate(); controller.clear(); } },
                  ),
                ] else if (record.todos.isNotEmpty) ...[
                  ...record.todos.map((e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(e.isDone ? Icons.check_circle : Icons.circle_outlined, color: Colors.black, size: 18),
                    title: Text(e.task, style: const TextStyle(fontSize: 13)),
                  )),
                ]
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              onPressed: () => Navigator.pop(context), 
              child: const Text('CLOSE')
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int daysInMonth = DateTime(_viewDate.year, _viewDate.month + 1, 0).day;
    DateTime firstDay = DateTime(_viewDate.year, _viewDate.month, 1);
    int emptyDays = firstDay.weekday % 7;
    DateTime todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.tune, color: Colors.black), onPressed: widget.onSettings)],
      ),
      body: Column(
        children: [
          Text('${_viewDate.year}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w300, letterSpacing: 10, color: Colors.black26)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(icon: const Icon(Icons.chevron_left, color: Colors.black), onPressed: () => setState(() => _viewDate = DateTime(_viewDate.year, _viewDate.month - 1))),
              Expanded(
                child: Center(
                  child: Text(DateFormat('MMMM').format(_viewDate).toUpperCase(), 
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w200, letterSpacing: 1.5),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              IconButton(icon: const Icon(Icons.chevron_right, color: Colors.black), onPressed: () => setState(() => _viewDate = DateTime(_viewDate.year, _viewDate.month + 1))),
            ],
          ),
          const SizedBox(height: 20),
          const Text('REMAINING', style: TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.black26)), 
          Text(widget.remaining.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 60, fontWeight: FontWeight.w100)),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ['S','M','T','W','T','F','S'].map((s) => Text(s, style: const TextStyle(fontSize: 11, color: Colors.black26, fontWeight: FontWeight.w900))).toList(),
            ),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 12, crossAxisSpacing: 12),
              itemCount: daysInMonth + emptyDays,
              itemBuilder: (context, index) {
                if (index < emptyDays) return const SizedBox();
                DateTime d = DateTime(_viewDate.year, _viewDate.month, index - emptyDays + 1);
                bool isSunday = d.weekday == DateTime.sunday;
                
                String dateKey = DateFormat('yyyy-MM-dd').format(d);
                DayRecord r = widget.records.putIfAbsent(dateKey, () => DayRecord());
                bool isAllDone = r.morning && r.evening;
                bool isMissionsCompleted = d.isBefore(todayStart) && r.todos.isNotEmpty && r.todos.every((t) => t.isDone);
                
                return GestureDetector(
                  onTap: () => _showDayDetails(context, d),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, color: isSunday ? const Color(0xFFF5F5F5) : Colors.white,
                      border: Border.all(
                        color: isMissionsCompleted ? const Color(0xFFAF4448).withOpacity(0.8) : Colors.black.withOpacity(0.04),
                        width: isMissionsCompleted ? 2.2 : 1.0,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if(!isSunday) 
                          CustomPaint(size: Size.infinite, painter: CirclePainter(r.morning, r.evening)),
                        Text('${d.day}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: isSunday ? Colors.black26 : (isAllDone ? Colors.white : Colors.black),
                      ))],
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
