import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/lobby_controller.dart';
import '../../../core/models/room_summary_dto.dart';
import '../../../core/services/game_service.dart';

import 'package:profesoresymatones/core/signalr_client.dart';

import '../../auth/state/auth_controller.dart';
import '../../game/presentation/game_board_page.dart';

class WaitingRoomPage extends StatefulWidget {
  final String roomId;

  const WaitingRoomPage({super.key, required this.roomId});

  @override
  State<WaitingRoomPage> createState() => _WaitingRoomPageState();
}

class _WaitingRoomPageState extends State<WaitingRoomPage> {
  final GameService _gameService = GameService();

  RoomSummaryDto? _room;
  bool _startingGame = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();

    // Cargar una vez al entrar
    _loadRoomOnce();

    // Configurar SignalR + polling
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSignalRForLobby();
      _startPollingRoom();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();

    final client = SignalRClient();
    final idInt = int.tryParse(widget.roomId);

    if (client.isConnected && idInt != null) {
      client.invoke('LeaveLobbyGroup', args: [idInt]).catchError((_) {});
    }

    super.dispose();
  }

  // ------------------------------------------------------------
  // POLLING CADA 1s
  // ------------------------------------------------------------
  void _startPollingRoom() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _loadRoomOnce(),
    );
  }

  // ------------------------------------------------------------
  // SIGNALR EVENTOS DEL LOBBY
  // ------------------------------------------------------------
  Future<void> _initSignalRForLobby() async {
    final auth = context.read<AuthController>();
    final token = auth.token;

    final client = SignalRClient();
    final roomIdInt = int.tryParse(widget.roomId);

    try {
      if (!client.isConnected) {
        await client.connect(accessToken: token);
      }

      if (roomIdInt != null) {
        await client.invoke('JoinLobbyGroup', args: [roomIdInt]);
      }

      client.on('LobbyUpdated', (_) => _loadRoomOnce());
      client.on('LobbyPlayerJoined', (_) => _loadRoomOnce());
      client.on('LobbyPlayerLeft', (_) => _loadRoomOnce());
    } catch (e) {
      dev.log("[Lobby] SignalR error: $e", name: "WaitingRoom");
    }
  }

  // ------------------------------------------------------------
  // CARGAR SALA (HTTP GET)
  // ------------------------------------------------------------
  Future<void> _loadRoomOnce() async {
    try {
      final lobby = context.read<LobbyController>();
      final room = await lobby.getRoomById(widget.roomId);

      if (!mounted) return;

      if (room == null) {
        dev.log("[Lobby] GET returned null", name: "WaitingRoom");
        return;
      }

      setState(() {
        _room = room; // ← dato fresco del backend
      });

      dev.log("[Lobby] Loaded room: ${room.playerNames.length} players",
          name: "WaitingRoom");
    } catch (e) {
      dev.log("[Lobby] Error loading room: $e", name: "WaitingRoom");
    }
  }

  // ------------------------------------------------------------
  // CREAR / ENTRAR AL JUEGO (SOLO HOST CREA)
  // ------------------------------------------------------------
  Future<void> _hostCreateAndEnterGame(RoomSummaryDto room) async {
    if (_startingGame) return;

    if (room.playerNames.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Se necesitan al menos 2 jugadores")),
      );
      return;
    }

    setState(() => _startingGame = true);

    try {
      final game = await _gameService.createGame(roomId: room.id.toString());

      if (!mounted) return;
      _pollTimer?.cancel();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => GameBoardPage(gameId: game.id)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _startingGame = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error entering game: $e")),
      );
    }
  }

  // ------------------------------------------------------------
  // BUILD UI
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final lobby = context.watch<LobbyController>();
    final auth = context.read<AuthController>();

    // Usamos SIEMPRE primero el valor fresco del backend
    RoomSummaryDto? room = _room;

    // Respaldo: lista general del lobby
    if (room == null && lobby.rooms.isNotEmpty) {
      try {
        room = lobby.rooms.firstWhere(
          (r) => r.id.toString() == widget.roomId,
        );
      } catch (_) {}
    }

    if (room == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final players = room.playerNames;
    final maxPlayers = room.maxPlayers;
    final myUsername = auth.username ?? "";

    final bool isHost = players.isNotEmpty &&
        players.first.trim().toLowerCase() ==
            myUsername.trim().toLowerCase();

    // 👇 NUEVO: detectar si la sala ya tiene un Game creado
    final bool hasGame =
        room.gameId != null && room.gameId!.trim().isNotEmpty;

    // Texto del botón principal
    final String mainButtonText = hasGame
        ? "Enter Game"
        : (isHost ? "Create & Enter Game" : "Waiting for host");

    // ¿Está habilitado el botón?
    final bool canPressMainButton =
        hasGame || (isHost && !_startingGame);

    return Scaffold(
      appBar: AppBar(
        title: Text("Waiting Room ${room.id}"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Room ${room.id} - ${room.name}",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Players",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: ListView.builder(
              itemCount: players.length,
              itemBuilder: (_, i) {
                final name = players[i];
                final isMe = name.trim().toLowerCase() ==
                    myUsername.trim().toLowerCase();

                return ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(name),
                  subtitle: isMe ? const Text("You") : null,
                );
              },
            ),
          ),

          Center(
            child: Text(
              "Players: ${players.length} / $maxPlayers",
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 12),

          Center(
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _loadRoomOnce,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Refresh"),
                ),
                const SizedBox(height: 8),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !canPressMainButton
                        ? Colors.grey.shade600
                        : Colors.green,
                  ),
                  onPressed: !_startingGame && canPressMainButton
                      ? () {
                          if (hasGame) {
                            // ✅ Ya existe game → cualquier jugador entra al board
                            final gameId = room!.gameId!;
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    GameBoardPage(gameId: gameId),
                              ),
                            );
                          } else {
                            // ✅ No existe game → solo host crea
                            if (isHost) {
                              _hostCreateAndEnterGame(room!);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      "Sólo el host puede crear la partida"),
                                ),
                              );
                            }
                          }
                        }
                      : null,
                  child: _startingGame
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(mainButtonText),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
