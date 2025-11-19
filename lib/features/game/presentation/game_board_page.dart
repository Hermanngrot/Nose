import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/game_controller.dart';
import 'game_board_widget.dart';
import '../../auth/presentation/logout_button.dart';

class GameBoardPage extends StatefulWidget {
  final String gameId;
  const GameBoardPage({super.key, required this.gameId});

  @override
  State<GameBoardPage> createState() => _GameBoardPageState();
}

class _GameBoardPageState extends State<GameBoardPage> with TickerProviderStateMixin {
  late final AnimationController _diceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  late final Animation<double> _diceScale = CurvedAnimation(parent: _diceController, curve: Curves.elasticOut);
  bool _showDice = false;
  int? _diceNumber;
  @override
  void initState() {
    super.initState();
    final ctrl = Provider.of<GameController>(context, listen: false);
    if (widget.gameId == 'new') {
      ctrl.createOrJoinGame();
    } else {
      ctrl.loadGame(widget.gameId);
    }
    // Listen for move results to trigger dice animation reliably
    ctrl.addListener(_onControllerChanged);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Provider.of<GameController>(context);
    // Show profesor question dialog when the controller receives one
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (ctrl.currentQuestion != null) {
        final q = ctrl.currentQuestion!;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('Pregunta del profesor'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(q.question),
                  const SizedBox(height: 12),
                  ...q.options.map((opt) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: ElevatedButton(
                          onPressed: ctrl.answering
                              ? null
                              : () async {
                                  Navigator.of(ctx).pop();
                                  await ctrl.answerProfesor(q.questionId, opt);
                                  // clear currentQuestion after answering
                                  ctrl.currentQuestion = null;
                                },
                          child: ctrl.answering ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(opt),
                        ),
                      )),
                ],
              ),
            );
          },
        );
      }
      // lastMoveResult handling is done via ChangeNotifier listener to ensure
      // the animation triggers reliably regardless of sync timing.
    });
    // media query kept inline where needed

    return Scaffold(
      appBar: AppBar(title: Text('Game ${widget.gameId}'), actions: [
        IconButton(
          tooltip: 'Full screen board',
          icon: const Icon(Icons.open_in_full),
          onPressed: () {
            if (ctrl.game != null) _openFullScreenBoard(ctrl);
          },
        ),
        const LogoutButton(),
      ]),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            LayoutBuilder(builder: (ctx, constraints) {
              final large = constraints.maxWidth >= 1000;
              if (!ctrl.loading && ctrl.game == null) {
                return const Expanded(child: Center(child: Text('No game loaded')));
              }

              Widget boardCard = Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ConstrainedBox(
                    // Allow the board to take a large portion of the available width on desktop
                    constraints: BoxConstraints(maxWidth: large ? constraints.maxWidth * 0.72 : constraints.maxWidth, maxHeight: constraints.maxHeight * 0.9),
                    child: InteractiveViewer(
                      panEnabled: true,
                      scaleEnabled: true,
                      boundaryMargin: const EdgeInsets.all(40),
                      minScale: 0.6,
                      maxScale: 3.5,
                      child: Center(child: GameBoardWidget(players: ctrl.game!.players, snakes: ctrl.game!.snakes, ladders: ctrl.game!.ladders)),
                    ),
                  ),
                ),
              );

              Widget playersList = SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Text('Players', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...ctrl.game!.players.map((p) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                          child: Row(children: [CircleAvatar(child: Text(p.username.isNotEmpty ? p.username[0].toUpperCase() : '?')), const SizedBox(width: 8), Expanded(child: Text(p.username)), Text(' ${p.position}')]),
                        )),
                    const SizedBox(height: 12),
                  ],
                ),
              );

              Widget actionsColumn = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: (ctrl.loading || ctrl.waitingForMove) ? null : () async {
                      final ok = await ctrl.roll();
                      if (!ok) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ctrl.error ?? 'Roll failed')));
                      else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Roll sent')));
                    },
                    child: ctrl.waitingForMove ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Roll'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: ctrl.loading ? null : () async {
                      final ok = await ctrl.surrender();
                      if (ok) Navigator.pushReplacementNamed(context, '/lobby');
                      else ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ctrl.error ?? 'Surrender failed')));
                    },
                    child: const Text('Surrender'),
                  ),
                  const SizedBox(height: 16),
                  Text('Game ${ctrl.game!.id} - ${ctrl.game!.status}'),
                ],
              );

              if (large) {
                return Row(
                  children: [
                    // narrower sidebars so center board can grow
                    SizedBox(width: 180, child: Padding(padding: const EdgeInsets.only(left: 8.0), child: playersList)),
                    const SizedBox(width: 12),
                    Expanded(child: Center(child: boardCard)),
                    const SizedBox(width: 12),
                    SizedBox(width: 180, child: Padding(padding: const EdgeInsets.only(right: 8.0), child: actionsColumn)),
                  ],
                );
              }

              // Fallback / narrow layout — stack vertically (original behavior)
              return Column(
                children: [
                  if (ctrl.loading) const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  Text('Game ${ctrl.game!.id} - ${ctrl.game!.status}'),
                  const SizedBox(height: 8),
                  Expanded(child: Center(child: boardCard)),
                  const SizedBox(height: 8),
                  SizedBox(height: 160, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12.0), child: playersList)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: (ctrl.loading || ctrl.waitingForMove) ? null : () async {
                          final ok = await ctrl.roll();
                          if (!ok) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ctrl.error ?? 'Roll failed')));
                          else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Roll sent')));
                        },
                        child: ctrl.waitingForMove ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Roll'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: ctrl.loading ? null : () async {
                          final ok = await ctrl.surrender();
                          if (ok) Navigator.pushReplacementNamed(context, '/lobby');
                          else ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ctrl.error ?? 'Surrender failed')));
                        },
                        child: const Text('Surrender'),
                      ),
                    ],
                  ),
                ],
              );
            }),
            if (_showDice && _diceNumber != null)
              Positioned.fill(
                child: Center(
                  child: ScaleTransition(
                    scale: _diceScale,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 8)]),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('You rolled', style: TextStyle(color: Colors.white70, fontSize: 18)),
                        const SizedBox(height: 8),
                        CircleAvatar(radius: 36, backgroundColor: Colors.white, child: Text('${_diceNumber}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black))),
                      ]),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openFullScreenBoard(GameController ctrl) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) {
      return Scaffold(
        appBar: AppBar(title: const Text('Board (full screen)')),
        body: SafeArea(
          child: Center(
            child: InteractiveViewer(
              panEnabled: true,
              scaleEnabled: true,
              boundaryMargin: const EdgeInsets.all(40),
              minScale: 0.8,
              maxScale: 4.0,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: GameBoardWidget(players: ctrl.game!.players, snakes: ctrl.game!.snakes, ladders: ctrl.game!.ladders),
              ),
            ),
          ),
        ),
      );
    }));
  }

  @override
  void dispose() {
    final ctrl = Provider.of<GameController>(context, listen: false);
    try {
      ctrl.removeListener(_onControllerChanged);
    } catch (_) {}
    _diceController.dispose();
    super.dispose();
  }

  void _onControllerChanged() async {
    final ctrl = Provider.of<GameController>(context, listen: false);
    final mr = ctrl.lastMoveResult;
    if (mr == null) return;
    if (_showDice) return; // already animating
    // capture dice and show overlay
    _diceNumber = mr.dice;
    setState(() {
      _showDice = true;
    });
    try {
      _diceController.reset();
      await _diceController.forward();
      await Future.delayed(const Duration(milliseconds: 900));
      await _diceController.reverse();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _showDice = false;
    });
    // clear controller stored result and refresh game state
    ctrl.lastMoveResult = null;
    if (ctrl.game != null) {
      // schedule refresh without awaiting to avoid blocking UI during navigation
      Future.microtask(() => ctrl.loadGame(ctrl.game!.id));
    }
  }
}
