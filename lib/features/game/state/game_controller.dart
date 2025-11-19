import 'dart:async';
import 'dart:math';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/game_state_dto.dart';
import '../../../core/models/player_state_dto.dart';
import '../../../core/models/move_result_dto.dart';
import '../../../core/models/profesor_question_dto.dart';
import '../../../core/services/game_service.dart';
import '../../../core/services/move_service.dart';
import '../../../core/signalr_client.dart';

class GameController extends ChangeNotifier {
  final GameService _gameService = GameService();
  final MoveService _moveService = MoveService();
  final SignalRClient _signalR = SignalRClient();
  // Protect sequential hub operations to avoid concurrent connect/stop races
  bool _hubBusy = false;
  // operation counter to ignore stale async results when navigating quickly
  int _opCounter = 0;
  ProfesorQuestionDto? currentQuestion;

  /// Indicates whether a SignalR connection was successfully established
  /// for the current game. If false, controller will fall back to REST calls.
  bool signalRAvailable = false;

  bool loading = false;
  GameStateDto? game;
  String? error;
  MoveResultDto? lastMoveResult;
  bool waitingForMove = false;
  bool answering = false;

  Future<bool> createOrJoinGame({String? roomId}) async {
    final int op = ++_opCounter;
    loading = true; error = null; notifyListeners();
    try {
      final g = await _gameService.createGame(roomId: roomId);
      if (op != _opCounter) return false; // stale
      game = g;
      // connect websocket for this game if available (sequentialized)
      if (game != null) await _connectToGameHub(game!.id);
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      if (op == _opCounter) {
        loading = false; notifyListeners();
      }
    }
  }

  Future<bool> loadGame(String gameId) async {
    final int op = ++_opCounter;
    loading = true; error = null; notifyListeners();
    try {
      final g = await _gameService.getGame(gameId);
      if (op != _opCounter) return false; // stale
      game = g;
      if (game != null) await _connectToGameHub(game!.id);
      return true;
    } catch (e) {
      if (op == _opCounter) error = e.toString();
      return false;
    } finally {
      if (op == _opCounter) { loading = false; notifyListeners(); }
    }
  }

  /// Try to find and load an active game associated with a room id.
  /// Uses `GameService.getGameByRoom` which probes common endpoints.
  Future<bool> loadGameByRoom(String roomId) async {
    final int op = ++_opCounter;
    loading = true; error = null; notifyListeners();
    try {
      final gs = await _gameService.getGameByRoom(roomId);
      if (op != _opCounter) return false;
      if (gs == null) {
        if (op == _opCounter) error = 'No active game found for room';
        return false;
      }
      game = gs;
      if (game != null) await _connectToGameHub(game!.id);
      return true;
    } catch (e) {
      if (op == _opCounter) error = e.toString();
      return false;
    } finally {
      if (op == _opCounter) { loading = false; notifyListeners(); }
    }
  }

  Future<void> _connectToGameHub(String gameId) async {
    // Avoid concurrent hub operations
    while (_hubBusy) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    _hubBusy = true;
    try {
      // Stop any previous connection (with its own timeout)
      try { await _signalR.stop(); } catch (_) {}

      // Get token for authorized hub (GameHub has [Authorize])
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      try {
        // Default hub path is '/gameHub' — adjust if your server maps differently
        await _signalR.connect(hubPath: '/gameHub', accessToken: token);
        signalRAvailable = true;

      // Register handlers
      _signalR.on('GameStateUpdate', (args) {
        if (args != null && args.isNotEmpty && args[0] is Map) {
          final Map<String, dynamic> gameJson = Map<String, dynamic>.from(args[0] as Map);
          game = GameStateDto.fromJson(gameJson);
          notifyListeners();
        }
      });

      _signalR.on('PlayerJoined', (args) {
        // could show notification or reload state
      });

      _signalR.on('ReceiveProfesorQuestion', (args) {
        if (args != null && args.isNotEmpty && args[0] is Map) {
          currentQuestion = ProfesorQuestionDto.fromJson(Map<String, dynamic>.from(args[0] as Map));
          notifyListeners();
        }
      });

      _signalR.on('MoveCompleted', (args) {
        try {
          if (args != null && args.isNotEmpty && args[0] is Map) {
            final Map<String, dynamic> payload = Map<String, dynamic>.from(args[0] as Map);
            final mr = payload['MoveResult'] ?? payload['moveResult'] ?? payload['move'] ?? null;
            if (mr is Map<String, dynamic>) {
              lastMoveResult = MoveResultDto.fromJson(mr);
              try {
                developer.log('MoveCompleted payload: $payload', name: 'GameController');
                developer.log('Parsed MoveResult dice=${lastMoveResult?.dice} newPosition=${lastMoveResult?.newPosition}', name: 'GameController');
              } catch (_) {}
            }
          }
        } catch (_) {}
        // Clear waiting flag when move completed arrives
        waitingForMove = false;
        notifyListeners();
      });

      _signalR.on('GameFinished', (args) {
        // handle game finished notification
      });

      // After registering handlers, join the game group on the hub so the
      // server adds this connection to the game's group (GameHub.JoinGameGroup)
      try {
        final int gid = int.tryParse(gameId) ?? 0;
        if (gid > 0) {
          _signalR.invoke('JoinGameGroup', args: [gid]);
        }
      } catch (_) {
        // ignore join errors
      }

      } catch (e) {
        // If SignalR connection fails, fall back to REST polling
        signalRAvailable = false;
        developer.log('GameController._connectToGameHub: signalR connect failed: ${e.toString()}', name: 'GameController');
      }
    } finally {
      _hubBusy = false;
    }
  }

  Future<bool> roll() async {
    if (game == null) return false;
    try {
      final gid = int.tryParse(game!.id) ?? 0;
      if (gid <= 0) throw Exception('Invalid game id');
      // If SignalR is available/connected try real-time invoke, otherwise use REST fallback
      if (_signalR.isConnected || signalRAvailable) {
        try {
          await _signalR.invoke('SendMove', args: [gid]);
        } catch (e) {
          // If the invoke failed due to disconnected state, try reconnecting once
          try {
            await _connectToGameHub(game!.id);
            if (_signalR.isConnected) {
              await _signalR.invoke('SendMove', args: [gid]);
            } else {
              // fallback to REST
              final res = await _moveService.roll(game!.id);
              lastMoveResult = res;
              try { developer.log('REST roll result: dice=${res.dice} newPosition=${res.newPosition}', name: 'GameController'); } catch (_) {}
              await loadGame(game!.id);
            }
          } catch (e2) {
            // fallback to REST if real-time failed
            final res = await _moveService.roll(game!.id);
            lastMoveResult = res;
            try { developer.log('REST roll result (retry): dice=${res.dice} newPosition=${res.newPosition}', name: 'GameController'); } catch (_) {}
            await loadGame(game!.id);
          }
        }
        // Server will broadcast MoveCompleted and GameStateUpdate; rely on handlers
        waitingForMove = true;
        notifyListeners();
        return true;
      } else {
        // Simulate locally when SignalR is not available so gameplay continues
        final rnd = Random();
        final players = game!.players;
        if (players.isEmpty) return false;
        final currentIndex = players.indexWhere((p) => p.isTurn);
        final int idx = currentIndex >= 0 ? currentIndex : 0;
        final mover = players[idx];
        final dice = rnd.nextInt(6) + 1; // 1..6
        int newPos = mover.position + dice;
        final int boardSize = 100; // default board size
        if (newPos > boardSize) newPos = boardSize;

        // apply ladders (profesores)
        for (final l in game!.ladders) {
          if (l.bottomPosition == newPos) {
            newPos = l.topPosition;
            break;
          }
        }
        // apply snakes (matones)
        for (final s in game!.snakes) {
          if (s.headPosition == newPos) {
            newPos = s.tailPosition;
            break;
          }
        }

        // build new players list with updated mover and turn rotation
        final newPlayers = <dynamic>[];
        for (var i = 0; i < players.length; i++) {
          final p = players[i];
          if (i == idx) {
            newPlayers.add(PlayerStateDto(id: p.id, username: p.username, position: newPos, isTurn: false));
          } else if (i == ((idx + 1) % players.length)) {
            newPlayers.add(PlayerStateDto(id: p.id, username: p.username, position: p.position, isTurn: true));
          } else {
            newPlayers.add(PlayerStateDto(id: p.id, username: p.username, position: p.position, isTurn: false));
          }
        }

        final newStatus = (newPos >= boardSize) ? 'Finished' : game!.status;
        final updatedGame = GameStateDto(id: game!.id, players: newPlayers.cast<PlayerStateDto>(), status: newStatus, snakes: game!.snakes, ladders: game!.ladders);
        game = updatedGame;

        final res = MoveResultDto(dice: dice, newPosition: newPos, moved: true, message: 'Simulated move');
        lastMoveResult = res;
        try { developer.log('Simulated roll result: dice=${res.dice} newPosition=${res.newPosition}', name: 'GameController'); } catch (_) {}

        waitingForMove = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<ProfesorQuestionDto?> getProfesorQuestion() async {
    if (game == null) return null;
    try {
      final q = await _moveService.getProfesor(game!.id);
      return q;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<MoveResultDto?> answerProfesor(String questionId, String answer) async {
    if (game == null) return null;
    answering = true;
    notifyListeners();
    try {
      final res = await _moveService.answerProfesor(game!.id, questionId, answer);
      await loadGame(game!.id);
      return res;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return null;
    } finally {
      answering = false;
      notifyListeners();
    }
  }

  Future<bool> surrender() async {
    if (game == null) return false;
    try {
      final gid = int.tryParse(game!.id) ?? 0;
      if (gid <= 0) throw Exception('Invalid game id');
      // Prefer SignalR invoke when connected, otherwise fallback to REST
      if (_signalR.isConnected || signalRAvailable) {
        try {
          await _signalR.invoke('SendSurrender', args: [gid]);
          return true;
        } catch (e) {
          // fallthrough to REST fallback
        }
      }
      // REST fallback
      await _moveService.surrender(game!.id);
      // After surrender via REST, update local state (server may have removed player)
      await loadGame(game!.id);
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    try {
      _signalR.stop();
    } catch (_) {}
    super.dispose();
  }
}
