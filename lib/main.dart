import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(CardGameTrackerApp());
}

class CardGameTrackerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Card Game Tracker',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Color(0xFF0D0D0D),
        textTheme: GoogleFonts.orbitronTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: Colors.white),
        ),
        cardColor: Color(0xFF1A1A1A),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.black,
            backgroundColor: Colors.cyanAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[850],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      home: SetupScreen(),
    );
  }
}

class SetupScreen extends StatefulWidget {
  @override
  _SetupScreenState createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int playerCount = 0;
  final TextEditingController _countController = TextEditingController();
  final List<TextEditingController> _nameControllers = [];

  @override
  void initState() {
    super.initState();
    _loadSavedSetup();
  }

  Future<void> _loadSavedSetup() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString('saved_setup');
    if (savedData != null) {
      try {
        final decoded = jsonDecode(savedData);
        final players = List<String>.from(decoded['players']);
        setState(() {
          playerCount = players.length;
          _countController.text = playerCount.toString();
          _nameControllers.clear();
          for (var name in players) {
            _nameControllers.add(TextEditingController(text: name));
          }
        });
      } catch (_) {}
    }
  }

  Future<void> _saveSetup() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode({
      'players': _nameControllers.map((c) => c.text.trim()).toList(),
    });
    await prefs.setString('saved_setup', data);
  }

  void _nextStep() {
    if (playerCount > 0) {
      _saveSetup();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GameScreen(
            players: _nameControllers.map((c) => c.text.trim()).toList(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('設定玩家')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _countController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: '請輸入玩家人數'),
              onSubmitted: (value) {
                final count = int.tryParse(value);
                if (count != null && count > 0) {
                  setState(() {
                    playerCount = count;
                    _nameControllers.clear();
                    for (int i = 0; i < count; i++) {
                      _nameControllers.add(TextEditingController());
                    }
                  });
                }
              },
            ),
            SizedBox(height: 20),
            if (playerCount > 0)
              Expanded(
                child: ListView.builder(
                  itemCount: playerCount,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: TextField(
                        controller: _nameControllers[index],
                        decoration: InputDecoration(
                          labelText: '玩家 ${index + 1} 名字',
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (playerCount > 0)
              ElevatedButton(onPressed: _nextStep, child: Text('開始遊戲')),
          ],
        ),
      ),
    );
  }
}

class GameScreen extends StatefulWidget {
  final List<String> players;
  GameScreen({required this.players});

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late Map<String, int> _scores;
  String? _winner;
  final Map<String, TextEditingController> _lossControllers = {};
  final List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _scores = {for (var p in widget.players) p: 0};
    for (var p in widget.players) {
      _lossControllers[p] = TextEditingController();
    }
    _loadSavedGame();
  }

  Future<void> _loadSavedGame() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString('saved_game');
    if (savedData != null) {
      try {
        final decoded = jsonDecode(savedData);
        final savedPlayers = List<String>.from(decoded['players']);
        final savedScores = Map<String, dynamic>.from(decoded['scores']);
        if (savedPlayers.length == widget.players.length &&
            savedPlayers.every((p) => widget.players.contains(p))) {
          setState(() {
            for (var p in savedPlayers) {
              _scores[p] = savedScores[p] as int;
            }
            _history.clear();
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _saveGame() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode({'players': widget.players, 'scores': _scores});
    await prefs.setString('saved_game', data);
  }

  void _recordRound() {
    if (_winner == null) return;
    int totalLoss = 0;
    Map<String, int> roundRecord = {};

    for (var p in widget.players) {
      if (p == _winner) continue;
      final loss = int.tryParse(_lossControllers[p]!.text) ?? 0;
      _scores[p] = (_scores[p] ?? 0) - loss;
      totalLoss += loss;
      roundRecord[p] = -loss;
    }

    _scores[_winner!] = (_scores[_winner!] ?? 0) + totalLoss;
    roundRecord[_winner!] = totalLoss;

    _history.add({'winner': _winner, 'changes': roundRecord});
    setState(() {});
    _saveGame();
  }

  void _undo() {
    if (_history.isEmpty) return;
    final last = _history.removeLast();
    final changes = last['changes'] as Map<String, int>;
    changes.forEach((player, change) {
      _scores[player] = (_scores[player]! - change);
    });
    setState(() {});
    _saveGame();
  }

  void _reset() {
    _scores.updateAll((key, value) => 0);
    _history.clear();
    setState(() {});
    _saveGame();
  }

  Future<void> _shareGame() async {
    final data = jsonEncode({'players': widget.players, 'scores': _scores});
    await Clipboard.setData(ClipboardData(text: data));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('遊戲資料已複製到剪貼簿！')));
  }

  Future<void> _importGame() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      try {
        final decoded = jsonDecode(data!.text!);
        final importedPlayers = List<String>.from(decoded['players']);
        final importedScores = Map<String, dynamic>.from(decoded['scores']);
        if (importedPlayers.length == widget.players.length &&
            importedPlayers.every((p) => widget.players.contains(p))) {
          setState(() {
            for (var p in importedPlayers) {
              _scores[p] = importedScores[p] as int;
            }
            _history.clear();
          });
          _saveGame();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('成功匯入遊戲資料！')));
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('匯入的玩家資料與目前不符')));
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('匯入資料格式錯誤')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('遊戲進行中'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            tooltip: '分享遊戲資料（複製剪貼簿）',
            onPressed: _shareGame,
          ),
          IconButton(
            icon: Icon(Icons.download),
            tooltip: '匯入遊戲資料（從剪貼簿）',
            onPressed: _importGame,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('選擇這輪贏家：'),
            Wrap(
              spacing: 8,
              children: widget.players
                  .map(
                    (p) => ChoiceChip(
                      label: Text(p),
                      selected: _winner == p,
                      onSelected: (_) {
                        setState(() {
                          _winner = p;
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
            if (_winner != null) ...[
              SizedBox(height: 20),
              Text('請輸入其他人輸多少：'),
              Column(
                children: widget.players
                    .where((p) => p != _winner)
                    .map(
                      (p) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: TextField(
                          controller: _lossControllers[p],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: '$p 輸多少'),
                        ),
                      ),
                    )
                    .toList(),
              ),
              ElevatedButton(onPressed: _recordRound, child: Text('記錄這一輪')),
            ],
            SizedBox(height: 20),
            Text('目前分數', style: TextStyle(fontSize: 20)),
            Expanded(
              child: ListView(
                children: widget.players
                    .map(
                      (p) => ListTile(
                        title: Text(p),
                        trailing: Text('${_scores[p]} 分'),
                      ),
                    )
                    .toList(),
              ),
            ),
            Wrap(
              spacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: _undo,
                  icon: Icon(Icons.undo),
                  label: Text('復原'),
                ),
                ElevatedButton.icon(
                  onPressed: _reset,
                  icon: Icon(Icons.refresh),
                  label: Text('重設'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
