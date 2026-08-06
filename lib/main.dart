import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

final notificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('comeback_box');
  tz_data.initializeTimeZones();
  var box = Hive.box('comeback_box');
  if (box.get('onboard_done') == null) {
    await _initNotifications();
  }
  runApp(const ComebackApp());
}

Future<void> _initNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings();
  const settings = InitializationSettings(android: android, iOS: ios);
  await notificationsPlugin.initialize(settings);
}

class ComebackApp extends StatelessWidget {
  const ComebackApp({super.key});
  @override
  Widget build(BuildContext context) {
    bool done = Hive.box('comeback_box').get('onboard_done') == true;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
      ),
      home: done? const HomeScreen() : const OnboardingScreen(),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController pc = PageController();
  int step = 0;
  final box = Hive.box('comeback_box');

  String weight = '', height = '', age = '';
  String habit = 'Sometimes';
  String level = 'Beginner';
  String role = 'Fast Bowler';
  String location = 'Outdoor';
  Set<String> equip = {'Ball'};

  void next() {
    if (step < 5) {
      setState(() => step++);
      pc.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
    } else {
      saveAndStart();
    }
  }

  Future<void> saveAndStart() async {
    box.put('profile', {
      'weight': weight,
      'height': height,
      'age': age,
      'habit': habit,
      'level': level,
      'role': role,
      'location': location,
      'equip': equip.toList(),
    });
    box.put('onboard_done', true);
    box.put('current_week', level == 'Beginner'? 1 : level == 'Intermediate'? 3 : 5);
    box.put('streak', 0);
    await _scheduleAlarm();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  Future<void> _scheduleAlarm() async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      var sched = tz.TZDateTime(tz.local, now.year, now.month, now.day, 5, 30);
      if (sched.isBefore(now)) sched = sched.add(const Duration(days: 1));
      await notificationsPlugin.zonedSchedule(
        0,
        'COMEBACK TIME 🔥',
        'Uth bhai, ground bula raha hai - 5:30 ho gaye',
        sched,
        const NotificationDetails(
          android: AndroidNotificationDetails('comeback_id', 'Comeback Alarm', importance: Importance.max),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Alarm error $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: pc,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          qScreen('Tera current status kya hai?', Column(children: [
            inputField('Weight (kg)', (v) => weight = v),
            inputField('Height (cm)', (v) => height = v),
            inputField('Age', (v) => age = v),
          ])),
          qScreen('Habit check (honest rehna)', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('PMO kitna hota hai?', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            for (var e in ['Daily', 'Sometimes', 'Rarely', 'Trying to quit'])
              choiceChip(e, habit == e, () => setState(() => habit = e)),
          ])),
          qScreen('Tu kis level pe hai?', Column(children: [
            for (var e in ['Beginner', 'Intermediate', 'Expert'])
              choiceChip(e, level == e, () => setState(() => level = e)),
          ])),
          qScreen('Cricket me kya karta hai?', Column(children: [
            for (var e in ['Fast Bowler', 'Spinner', 'Batsman', 'All-rounder'])
              choiceChip(e, role == e, () => setState(() => role = e)),
          ])),
          qScreen('Kahan practice karega?', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: choiceChip('Outdoor Ground', location == 'Outdoor', () => setState(() => location = 'Outdoor'))),
              const SizedBox(width: 8),
              Expanded(child: choiceChip('Indoor / Ghar', location == 'Indoor', () => setState(() => location = 'Indoor'))),
            ]),
            const SizedBox(height: 16),
            const Text('Equipment kya hai?', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (var e in ['Ball', 'Stumps', 'Dumbbell', 'Resistance Band', 'Kuch nahi'])
                FilterChip(
                  label: Text(e),
                  selected: equip.contains(e),
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        equip.add(e);
                      } else {
                        equip.remove(e);
                      }
                    });
                  },
                  selectedColor: Colors.white,
                  labelStyle: TextStyle(color: equip.contains(e)? Colors.black : Colors.white),
                ),
            ]),
          ])),
          qScreen('Ready hai comeback ke liye?', Column(children: [
            const Text('Tera plan ban gaya hai. Weight graph, bowling speed, 5:30 alarm sab included hai.', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16)),
              child: Text('Role: $role\nLevel: $level\nLocation: $location\nEquipment: ${equip.join(', ')}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          ])),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(20),
        child: ElevatedButton(
          onPressed: next,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: Text(step == 5? 'START MY COMEBACK 🔥' : 'NEXT'),
        ),
      ),
    );
  }

  Widget qScreen(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 60),
        Text('STEP ${step + 1}/6', style: const TextStyle(color: Colors.blue, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 24),
        child,
      ]),
    );
  }

  Widget inputField(String hint, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          hintStyle: const TextStyle(color: Colors.white38),
        ),
      ),
    );
  }

  Widget choiceChip(String label, bool sel, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: sel? Colors.white : const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(14), border: Border.all(color: sel? Colors.white : const Color(0xFF2A2A2A))),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: sel? Colors.black : Colors.white, fontWeight: FontWeight.w600, fontSize: 13))),
          if (sel) const Icon(Icons.check_circle, color: Colors.black, size: 18),
        ]),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final box = Hive.box('comeback_box');
  int tab = 0;
  String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  Map<String, dynamic> buildPlan() {
    var profile = box.get('profile');
    String role = profile?['role']?? 'Fast Bowler';
    String level = profile?['level']?? 'Beginner';
    String loc = profile?['location']?? 'Outdoor';
    List equip = profile?['equip']?? ['Ball'];
    int week = box.get('current_week')?? 1;

    int basePush = level == 'Beginner'? 10 : level == 'Intermediate'? 20 : 30;
    int push = basePush + (week * 3);
    int overs = level == 'Beginner'? 3 : 5;
    overs = overs + (week ~/ 2);

    List tasks = [];
    tasks.add({'title': 'Fajr + Cold Shower', 'cat': 'Discipline', 'time': '05:00', 'detail': 'No phone 1hr', 'done': false});
    if (role.contains('Bowler')) {
      tasks.add({'title': 'Bowling Action Drills x 30', 'cat': 'Cricket', 'time': '05:45', 'detail': loc == 'Indoor'? 'Shadow bowling indoor' : 'Short runup $overs overs - ${equip.contains('Stumps')? 'stumps target' : 'wall target'}', 'done': false, 'overs': overs});
    } else {
      tasks.add({'title': 'Batting Shadow + Footwork', 'cat': 'Cricket', 'time': '05:45', 'detail': '100 shadow drives', 'done': false});
    }
    tasks.add({'title': '$push Pushups + Rows', 'cat': 'Fitness', 'time': '06:30', 'detail': equip.contains('Dumbbell')? 'Dumbbell Rows' : 'Bodyweight', 'done': false, 'count': push});
    tasks.add({'title': 'Jog 15min + Sprint', 'cat': 'Fitness', 'time': '07:00', 'detail': loc == 'Indoor'? 'Spot jog' : 'Ground 2km', 'done': false});
    tasks.add({'title': 'Diet + Water 3L', 'cat': 'Diet', 'time': 'All Day', 'detail': 'No sugar', 'done': false});
    tasks.add({'title': 'No PMO Control', 'cat': 'Discipline', 'time': 'All Day', 'detail': 'Urge = 20 pushups', 'done': false});

    return {'tasks': tasks, 'push': push, 'overs': overs, 'week': week};
  }

  List getTodayTasks() {
    var saved = box.get('tasks_$today');
    if (saved!= null) return saved;
    var plan = buildPlan();
    box.put('tasks_$today', plan['tasks']);
    return plan['tasks'];
  }

  void toggleTask(int i) {
    List tasks = getTodayTasks();
    tasks[i]['done'] =!tasks[i]['done'];
    box.put('tasks_$today', tasks);
    if (tasks[i]['cat'] == 'Discipline' && tasks[i]['title'].contains('No PMO') && tasks[i]['done'] == true) {
      box.put('streak', (box.get('streak')?? 0) + 1);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    var plan = buildPlan();
    var tasks = getTodayTasks();
    int done = tasks.where((t) => t['done'] == true).length;
    int pct = tasks.isEmpty? 0 : (done / tasks.length * 100).round();

    return Scaffold(
      body: [
        _todayTab(plan, tasks, done, pct),
        _historyTab(),
        _statsTab(),
      ][tab],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF151515),
        selectedItemColor: Colors.white,
        unselectedItemColor: const Color(0xFF666666),
        currentIndex: tab,
        onTap: (i) => setState(() => tab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.bolt), label: 'TODAY'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'HISTORY'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'BODY'),
        ],
      ),
    );
  }

  Widget _todayTab(Map plan, List tasks, int done, int pct) {
    return SafeArea(
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Text('WEEK ${plan['week']} • ${box.get('profile')?['role']}', style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.5)),
        const Text('COMEBACK 2.0', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: statCard('STREAK', '${box.get('streak')?? 0} days')),
          const SizedBox(width: 12),
          Expanded(child: statCard('TODAY', '$pct%', '$done/${tasks.length}')),
        ]),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: pct / 100, color: Colors.white, backgroundColor: const Color(0xFF222222), minHeight: 8),
        const SizedBox(height: 20),
        for (int i = 0; i < tasks.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF2A2A2A))),
            child: CheckboxListTile(
              value: tasks[i]['done'],
              onChanged: (_) => toggleTask(i),
              title: Text(tasks[i]['title'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, decoration: tasks[i]['done']? TextDecoration.lineThrough : null)),
              subtitle: Text('${tasks[i]['cat']} • ${tasks[i]['detail']}', style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
              activeColor: Colors.white,
              checkColor: Colors.black,
            ),
          ),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: showBowlingSheet, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E1E1E)), child: const Text('Log Bowling Speed + Overs')),
        ElevatedButton(onPressed: showWeightSheet, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black), child: const Text('Log Today Weight')),
      ]),
    );
  }

  Widget statCard(String l, String b, [String? s]) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF222222))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: const TextStyle(color: Color(0xFF888888), fontSize: 10)),
        const SizedBox(height: 4),
        Text(b, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        if (s!= null) Text(s, style: const TextStyle(color: Color(0xFF666666), fontSize: 11)),
      ]),
    );
  }

  Widget _historyTab() {
    return SafeArea(
      child: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('HISTORY', style: TextStyle(fontWeight: FontWeight.bold)),
        for (int i = 0; i < 14; i++)
          Builder(builder: (_) {
            var d = DateTime.now().subtract(Duration(days: i));
            var ds = DateFormat('yyyy-MM-dd').format(d);
            var day = box.get('tasks_$ds');
            int pct = 0;
            if (day!= null) {
              var l = day as List;
              pct = l.isEmpty? 0 : (l.where((t) => t['done'] == true).length / l.length * 100).round();
            }
            return ListTile(
              title: Text(DateFormat('EEE d MMM').format(d)),
              trailing: Text('$pct%'),
              leading: Icon(pct >= 80? Icons.check_circle : Icons.circle, color: pct >= 80? Colors.green : const Color(0xFF333333)),
            );
          }),
      ]),
    );
  }

  Widget _statsTab() {
    List weights = box.get('weights')?? [];
    return SafeArea(
      child: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('WEIGHT GRAPH', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          height: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF151515), borderRadius: BorderRadius.circular(16)),
          child: weights.isEmpty
             ? const Center(child: Text('No data yet - Log weight daily', style: TextStyle(color: Color(0xFF666666))))
              : LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(weights.length, (i) => FlSpot(i.toDouble(), (weights[i]['w'] as num).toDouble())),
                        isCurved: true,
                        color: Colors.white,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 20),
        const Text('BOWLING LOGS (Speed + Overs)', style: TextStyle(fontWeight: FontWeight.bold)),
        for (var e in (box.get('bowling_logs')?? []) as List)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${e['overs']} overs'),
              Text('${e['speed']} km/h'),
              Text(e['date'], style: const TextStyle(color: Color(0xFF666666), fontSize: 11)),
            ]),
          ),
      ]),
    );
  }

  void showBowlingSheet() {
    String overs = '', speed = '';
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(onChanged: (v) => overs = v, decoration: const InputDecoration(hintText: 'Overs bowled e.g. 4'), keyboardType: TextInputType.number),
          const SizedBox(height: 10),
          TextField(onChanged: (v) => speed = v, decoration: const InputDecoration(hintText: 'Speed km/h e.g. 120'), keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              List logs = box.get('bowling_logs')?? [];
              logs.insert(0, {'overs': overs, 'speed': speed.isEmpty? '--' : speed, 'date': DateFormat('d MMM').format(DateTime.now())});
              box.put('bowling_logs', logs);
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Save Bowling Log'),
          ),
        ]),
      ),
    );
  }

  void showWeightSheet() {
    String w = '';
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(onChanged: (v) => w = v, decoration: const InputDecoration(hintText: 'Today weight kg e.g. 72.5'), keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              List weights = box.get('weights')?? [];
              weights.add({'w': double.tryParse(w)?? 0, 'date': DateTime.now().toIso8601String()});
              box.put('weights', weights);
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Save Weight'),
          ),
        ]),
      ),
    );
  }
}