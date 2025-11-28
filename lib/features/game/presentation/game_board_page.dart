import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../auth/state/auth_controller.dart';
import '../../auth/presentation/logout_button.dart';
import '../state/game_controller.dart';
import 'game_board_widget.dart';

class GameBoardPage extends StatefulWidget {
  final String gameId;
  const GameBoardPage({super.key, required this.gameId});

  @override
  State<GameBoardPage> createState() => _GameBoardPageState();
}

class _GameBoardPageState extends State<GameBoardPage>
    with TickerProviderStateMixin {
  late final AnimationController _diceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late final Animation<double> _diceScale =
      CurvedAnimation(parent: _diceController, curve: Curves.elasticOut);

  bool _showDice = false;
  int? _diceNumber;
  bool _diceRolling = false;

  // Solo para Matón (no para profesor)
  bool _showSpecialOverlay = false;
  String? _specialMessage;

  // Aggressive reload cuando el game llega sin players
  bool _waitingForPlayers = false;
  Timer? _aggressiveReloadTimer;
  int _aggressiveReloadAttempts = 0;

  @override
  void initState() {
    super.initState();
    final ctrl = Provider.of<GameController>(context, listen: false);

    // Esperar a que Auth cargue el token / user
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = Provider.of<AuthController>(context, listen: false);

      int attempts = 0;
      while (!auth.isLoggedIn && attempts < 15) {
        await Future.delayed(const Duration(milliseconds: 200));
        attempts++;
      }

      if (widget.gameId == 'new') {
        await ctrl.createOrJoinGame();
      } else {
        await ctrl.loadGame(widget.gameId);
      }
    });

    // Escuchar cambios del controlador (para animación de dado, etc.)
    ctrl.addListener(_onControllerChanged);

    // Polling solo una vez al entrar (se desactiva si SignalR está ok)
    try {
      ctrl.startPollingGame();
    } catch (_) {}

    // Aggressive reload si el game llega sin players
    ctrl.addListener(_maybeStartAggressiveReload);
  }

  void _maybeStartAggressiveReload() {
    final ctrl = Provider.of<GameController>(context, listen: false);
    try {
      if (ctrl.game != null && ctrl.game!.players.isEmpty) {
        if (!_waitingForPlayers) {
          _waitingForPlayers = true;
          _aggressiveReloadAttempts = 0;
          _aggressiveReloadTimer?.cancel();

          _aggressiveReloadTimer =
              Timer.periodic(const Duration(milliseconds: 400), (t) async {
            _aggressiveReloadAttempts++;
            try {
              await ctrl.loadGame(ctrl.game!.id);
            } catch (_) {}

            if (!mounted) return;

            if (ctrl.game == null ||
                ctrl.game!.players.isNotEmpty ||
                _aggressiveReloadAttempts >= 12) {
              _aggressiveReloadTimer?.cancel();
              _aggressiveReloadTimer = null;
              _waitingForPlayers = false;
              if (mounted) setState(() {});
            } else {
              if (mounted) setState(() {});
            }
          });

          if (mounted) setState(() {});
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Provider.of<GameController>(context);

    // Modo “offline”: sin SignalR, se usa polling/simulación
    final bool offlineMode = !ctrl.signalRAvailable;

    // Mostrar diálogo de profesor cuando `currentQuestion` tenga algo
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
                  ...q.options.map((opt) {
                    final label =
                        opt.trim().isEmpty ? '<sin texto>' : opt.trim();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: ElevatedButton(
                        onPressed: ctrl.answering
                            ? null
                            : () async {
                                Navigator.of(ctx).pop();
                                await _submitProfesorAnswer(
                                    q.questionId, opt, ctx);
                              },
                        child: ctrl.answering
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(label),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      }
    });

    final game = ctrl.game;
    final players = game?.players ?? <dynamic>[];
    final snakes = game?.snakes ?? <dynamic>[];
    final ladders = game?.ladders ?? <dynamic>[];
    final gameId = game?.id ?? '';
    final gameStatus = game?.status ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Game ${widget.gameId}'),
        actions: [
          IconButton(
            tooltip: 'Full screen board',
            icon: const Icon(Icons.open_in_full),
            onPressed: () {
              if (ctrl.game != null) _openFullScreenBoard(ctrl);
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Opciones',
            onSelected: (s) {
              if (s == 'toggle_sim') {
                ctrl.setSimulateEnabled(!ctrl.simulateEnabled);
              } else if (s == 'force_roll') {
                ctrl.setForceEnableRoll(!ctrl.forceEnableRoll);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                value: 'toggle_sim',
                child: Row(
                  children: [
                    const Text('Simulación'),
                    const Spacer(),
                    Text(ctrl.simulateEnabled ? 'On' : 'Off'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'force_roll',
                child: Row(
                  children: [
                    const Text('Forzar Roll'),
                    const Spacer(),
                    Text(ctrl.forceEnableRoll ? 'On' : 'Off'),
                  ],
                ),
              ),
            ],
          ),
          const LogoutButton(),
        ],
      ),
      body: Column(
        children: [
          if (offlineMode)
            Consumer<GameController>(
              builder: (ctx, c, _) {
                final err = c.lastSignalRError;
                return Container(
                  width: double.infinity,
                  color: Colors.amber.shade100,
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.signal_wifi_off, color: Colors.brown),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          err == null
                              ? 'Conexión degradada: usando polling/simulación. Es posible que otros jugadores no vean cambios inmediatamente.'
                              : 'Conexión degradada: ${err.length > 160 ? err.substring(0, 160) + '...' : err}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reconnect'),
                        onPressed: () async {
                          final ok = await c.tryReconnectSignalR();
                          if (!mounted) return;
                          if (!ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Reconnect failed: ${c.lastSignalRError ?? 'unknown'}',
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Reconnected to SignalR')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Stack(
                children: [
                  // Debug overlay
                  Positioned(
                    right: 12,
                    top: 6,
                    child: Consumer<GameController>(
                      builder: (ctx, c, _) {
                        final gid = c.game?.id ?? '<none>';
                        final pl = c.game?.players.length ?? 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white70,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'debug: game=$gid',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text('players=$pl',
                                  style: const TextStyle(fontSize: 12)),
                              Text('loading=${c.loading}',
                                  style: const TextStyle(fontSize: 12)),
                              Text('signalR=${c.signalRAvailable}',
                                  style: const TextStyle(fontSize: 12)),
                              Text('simulate=${c.simulateEnabled}',
                                  style: const TextStyle(fontSize: 12)),
                              Text('waiting=${c.waitingForMove}',
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  LayoutBuilder(
                    builder: (ctx, constraints) {
                      final large = constraints.maxWidth >= 1000;

                      if (!ctrl.loading && ctrl.game == null) {
                        return const Center(child: Text('No game loaded'));
                      }

                      // ===== TABLERO GRANDE =====
                      final boardCard = Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: large
                                  ? constraints.maxWidth * 0.72
                                  : constraints.maxWidth,
                              maxHeight: constraints.maxHeight * 0.9,
                            ),
                            child: InteractiveViewer(
                              panEnabled: true,
                              scaleEnabled: true,
                              boundaryMargin: const EdgeInsets.all(40),
                              minScale: 0.6,
                              maxScale: 3.5,
                              child: Center(
                                child: GameBoardWidget(
                                  players: players.cast(),
                                  snakes: snakes.cast(),
                                  ladders: ladders.cast(),
                                  animatePlayerId: ctrl.lastMovePlayerId,
                                  animateSteps: ctrl.lastMoveResult?.diceValue,
                                  onAnimationComplete: () {
                                    // Solo nos preocupamos por simulación local
                                    if (ctrl.hasPendingSimulatedGame()) {
                                      ctrl.applyPendingSimulatedGame();
                                      ctrl.lastMoveSimulated = false;
                                      ctrl.lastMovePlayerId = null;
                                      ctrl.lastMoveResult = null;
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      );

                      // Indicador de turno
                      final turnIndicator = Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.how_to_reg,
                                size: 18, color: Colors.blueGrey),
                            const SizedBox(width: 8),
                            Text(
                              'Turno: ${ctrl.currentTurnUsername.isNotEmpty ? ctrl.currentTurnUsername : '—'}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      );

                      // Lista de jugadores
                      final playersList = SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              'Players',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            ...players.map(
                              (p) => Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 6.0, horizontal: 8.0),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      child: Text(
                                        p.username.isNotEmpty
                                            ? p.username[0].toUpperCase()
                                            : '?',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(p.username)),
                                    if (p.isTurn) ...[
                                      const SizedBox(width: 8),
                                      const Icon(Icons.campaign,
                                          color: Colors.green, size: 18),
                                    ],
                                    const SizedBox(width: 8),
                                    Text(' ${p.position}'),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      );

                      // Botones de acciones
                      final actionsColumn = Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Builder(
                            builder: (ctx) {
                              final c = Provider.of<GameController>(ctx);
                              if (!c.isMyTurn) {
                                final who = c.currentTurnUsername.isNotEmpty
                                    ? c.currentTurnUsername
                                    : 'otro jugador';
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8.0),
                                  child: Text(
                                    'Turno de: $who',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: Colors.grey[700]),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                          Tooltip(
                            message: ctrl.isMyTurn
                                ? 'Tirar dado'
                                : (ctrl.simulateEnabled &&
                                        !ctrl.signalRAvailable)
                                    ? 'Simulación activa: tirar localmente'
                                    : 'No es tu turno: turno de ${ctrl.currentTurnUsername.isNotEmpty ? ctrl.currentTurnUsername : 'otro jugador'}',
                            child: ElevatedButton(
                              onPressed: (ctrl.loading ||
                                      ctrl.waitingForMove ||
                                      !(ctrl.isMyTurn ||
                                          (ctrl.simulateEnabled &&
                                              !ctrl.signalRAvailable) ||
                                          ctrl.forceEnableRoll))
                                  ? null
                                  : () async {
                                      final ok = await ctrl.roll();
                                      if (!ok) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              ctrl.error ?? 'Roll failed',
                                            ),
                                          ),
                                        );
                                      } else {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text('Roll sent')),
                                        );
                                      }
                                    },
                              child: ctrl.waitingForMove
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Text('Roll'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: ctrl.loading
                                ? null
                                : () async {
                                    final ok = await ctrl.surrender();
                                    if (!mounted) return;
                                    if (ok) {
                                      Navigator.pushReplacementNamed(
                                          context, '/lobby');
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            ctrl.error ?? 'Surrender failed',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                            child: const Text('Surrender'),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh Game'),
                            onPressed: (game == null || gameId.isEmpty)
                                ? null
                                : () async {
                                    await ctrl.loadGame(gameId);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Game refreshed')),
                                    );
                                  },
                          ),
                          const SizedBox(height: 16),
                          Text('Game $gameId - $gameStatus'),
                        ],
                      );

                      // Overlay mientras esperamos que lleguen los players
                      final boardWithOptionalOverlay = Stack(
                        children: [
                          Center(child: boardCard),
                          if (_waitingForPlayers)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black45,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        CircularProgressIndicator(),
                                        SizedBox(height: 12),
                                        Text(
                                          'Esperando sincronización de jugadores...',
                                          style: TextStyle(fontSize: 16),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );

                      if (large) {
                        return Row(
                          children: [
                            SizedBox(
                              width: 180,
                              child: Padding(
                                padding:
                                    const EdgeInsets.only(left: 8.0),
                                child: playersList,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                children: [
                                  turnIndicator,
                                  Expanded(child: boardWithOptionalOverlay),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 180,
                              child: Padding(
                                padding:
                                    const EdgeInsets.only(right: 8.0),
                                child: actionsColumn,
                              ),
                            ),
                          ],
                        );
                      }

                      // Layout vertical (pantalla angosta)
                      return Column(
                        children: [
                          if (ctrl.loading) const LinearProgressIndicator(),
                          const SizedBox(height: 8),
                          Text('Game $gameId - $gameStatus'),
                          turnIndicator,
                          const SizedBox(height: 8),
                          Expanded(child: Center(child: boardWithOptionalOverlay)),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 160,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12.0),
                              child: playersList,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Tooltip(
                                message: ctrl.isMyTurn
                                    ? 'Tirar dado'
                                    : (ctrl.simulateEnabled &&
                                            !ctrl.signalRAvailable)
                                        ? 'Simulación activa: tirar localmente'
                                        : 'No es tu turno: turno de ${ctrl.currentTurnUsername.isNotEmpty ? ctrl.currentTurnUsername : 'otro jugador'}',
                                child: ElevatedButton(
                                  onPressed: (ctrl.loading ||
                                          ctrl.waitingForMove ||
                                          !(ctrl.isMyTurn ||
                                              (ctrl.simulateEnabled &&
                                                  !ctrl.signalRAvailable)))
                                      ? null
                                      : () async {
                                          final ok = await ctrl.roll();
                                          if (!ok) {
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    ctrl.error ?? 'Roll failed'),
                                              ),
                                            );
                                          } else {
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text('Roll sent')),
                                            );
                                          }
                                        },
                                  child: ctrl.waitingForMove
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Text('Roll'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: ctrl.loading
                                    ? null
                                    : () async {
                                        final ok = await ctrl.surrender();
                                        if (!mounted) return;
                                        if (ok) {
                                          Navigator.pushReplacementNamed(
                                              context, '/lobby');
                                        } else {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  ctrl.error ?? 'Surrender failed'),
                                            ),
                                          );
                                        }
                                      },
                                child: const Text('Surrender'),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),

                  // Overlay de dado
                  if (_showDice && _diceNumber != null)
                    Positioned.fill(
                      child: Center(
                        child: ScaleTransition(
                          scale: _diceScale,
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'You rolled',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 18),
                                ),
                                const SizedBox(height: 8),
                                CircleAvatar(
                                  radius: 36,
                                  backgroundColor: Colors.white,
                                  child: Text(
                                    '$_diceNumber',
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Overlay solo para Matón (texto corto)
                  if (_showSpecialOverlay && _specialMessage != null)
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black45,
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _specialMessage!,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 18),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openFullScreenBoard(GameController ctrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) {
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
                    child: GameBoardWidget(
                      players: ctrl.game!.players,
                      snakes: ctrl.game!.snakes,
                      ladders: ctrl.game!.ladders,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    final ctrl = Provider.of<GameController>(context, listen: false);
    try {
      ctrl.removeListener(_onControllerChanged);
      ctrl.removeListener(_maybeStartAggressiveReload);
      try {
        ctrl.stopPollingGame();
      } catch (_) {}
    } catch (_) {}
    _diceController.dispose();
    try {
      _aggressiveReloadTimer?.cancel();
    } catch (_) {}
    super.dispose();
  }

  void _onControllerChanged() async {
    final ctrl = Provider.of<GameController>(context, listen: false);
    final mr = ctrl.lastMoveResult;
    if (mr == null) return;

    try {
      developer.log(
        'GameBoardPage._onControllerChanged lastMoveResult dice=${mr.diceValue} finalPosition=${mr.finalPosition}',
        name: 'GameBoardPage',
      );
    } catch (_) {}

    if (_showDice) return; // ya se está animando

    int appliedToShow =
        (mr.dice >= 1 && mr.dice <= 6) ? mr.dice : mr.dice;

    if (ctrl.game != null) {
      try {
        int prevPos = -1;
        final moverId = ctrl.lastMovePlayerId;
        if (moverId != null) {
          final moverIndex =
              ctrl.game!.players.indexWhere((p) => p.id == moverId);
          if (moverIndex >= 0) {
            prevPos = ctrl.game!.players[moverIndex].position;
          }
        }
        if (prevPos < 0) {
          final candidates = ctrl.game!.players
              .where((p) => p.position < mr.newPosition)
              .toList();
          if (candidates.isNotEmpty) {
            candidates.sort((a, b) => b.position.compareTo(a.position));
            prevPos = candidates.first.position;
          }
        }
        if (prevPos >= 0) {
          final comp = mr.newPosition - prevPos;
          if (comp > 0 && (mr.dice < 1 || mr.dice > 6)) {
            appliedToShow = comp.clamp(1, 6).toInt();
          }
        }
      } catch (_) {}
    }

    if (appliedToShow <= 0) appliedToShow = 1;
    if (appliedToShow > 6) {
      appliedToShow =
          (appliedToShow % 6 == 0) ? 6 : (appliedToShow % 6);
    }

    _diceNumber = 1;
    setState(() => _showDice = true);

    try {
      await _playDiceRollAnimation(appliedToShow);
    } catch (_) {}

    if (!mounted) return;
    setState(() => _showDice = false);

    // Overlay de Matón (solo si cayó en snake head)
    try {
      final newPos = mr.newPosition;
      bool hitMaton = false;

      if (ctrl.game != null) {
        hitMaton = ctrl.game!.snakes
            .any((s) => s.headPosition == newPos);
      }

      if (hitMaton) {
        _specialMessage =
            '¡Te comió un Matón! Retrocedes a ${mr.newPosition}';
        setState(() => _showSpecialOverlay = true);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() => _showSpecialOverlay = false);
          }
        });
      }
    } catch (_) {}

    // Limpiar resultado (ya se utilizó para animación)
    ctrl.lastMoveResult = null;

    if (ctrl.hasPendingSimulatedGame()) {
      ctrl.applyPendingSimulatedGame();
      ctrl.lastMoveSimulated = false;
    }
    // Importante: NO llamamos a loadGame aquí.
  }

  Future<void> _playDiceRollAnimation(int finalNumber) async {
    if (_diceRolling) return;
    _diceRolling = true;
    try {
      const List<int> phases = [60, 60, 60, 60, 80, 100, 140, 200];

      if (_diceNumber == null) _diceNumber = 1;

      for (final d in phases) {
        await Future.delayed(Duration(milliseconds: d));
        if (!mounted) return;
        setState(() {
          _diceNumber = (_diceNumber! % 6) + 1;
        });
      }

      await Future.delayed(const Duration(milliseconds: 160));
      if (!mounted) return;
      setState(() {
        _diceNumber = finalNumber.clamp(1, 6).toInt();
      });

      try {
        _diceController.reset();
        await _diceController.forward();
        await Future.delayed(const Duration(milliseconds: 260));
        await _diceController.reverse();
      } catch (_) {}
    } finally {
      _diceRolling = false;
    }
  }

  Future<void> _showErrorDialog(
      BuildContext ctx, String title, String message) async {
    try {
      await showDialog<void>(
        context: ctx,
        builder: (_) {
          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(child: Text(message)),
            actions: [
              TextButton(
                onPressed: () async {
                  try {
                    await Clipboard.setData(ClipboardData(text: message));
                  } catch (_) {}
                  Navigator.of(ctx).pop();
                },
                child: const Text('Copiar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      );
    } catch (_) {}
  }

  Future<void> _submitProfesorAnswer(
      String questionId, String answer, BuildContext ctx) async {
    final ctrl = Provider.of<GameController>(context, listen: false);
    try {
      var res;
      try {
        res = await ctrl
            .answerProfesor(questionId, answer)
            .timeout(const Duration(seconds: 15));
      } on TimeoutException {
        try {
          res = await ctrl
              .answerProfesor(questionId, answer)
              .timeout(const Duration(seconds: 15));
        } on TimeoutException {
          if (!mounted) return;
          await _showErrorDialog(
            ctx,
            'Timeout',
            'La respuesta tardó demasiado en procesarse y agotó el tiempo.',
          );
          return;
        }
      }

      if (!mounted) return;
      if (res == null) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(ctrl.error ?? 'Answer failed')),
        );
      } else {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Answer submitted')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      await _showErrorDialog(ctx, 'Answer error', e.toString());
    } finally {
      try {
        ctrl.setAnswering(false);
        ctrl.clearCurrentQuestion();
      } catch (_) {}
    }
  }
}
