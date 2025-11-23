import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../state/lobby_controller.dart';
import '../../../core/models/room_summary_dto.dart';
import '../../auth/presentation/logout_button.dart';
import '../../auth/state/auth_controller.dart';
import '../../game/state/game_controller.dart';
import '../../../core/api_client.dart';
import 'dart:convert';

class WaitingRoomPage extends StatefulWidget {
  final String roomId;
  const WaitingRoomPage({super.key, required this.roomId});

  @override
  State<WaitingRoomPage> createState() => _WaitingRoomPageState();
}

class _WaitingRoomPageState extends State<WaitingRoomPage> {
  Timer? _roomWatcherTimer;
  @override
  void initState() {
    super.initState();
    final ctrl = Provider.of<LobbyController>(context, listen: false);
    // load initial room info
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final gameCtrl = Provider.of<GameController>(context, listen: false);
      final r = await ctrl.getRoomById(widget.roomId);

      // If the room is already in-game, attempt to enter the active game directly
      try {
        if (r != null && r.status != null && r.status!.toLowerCase().contains('ingame')) {
          // Prefer explicit gameId when provided by the server
          final gid = r.gameId;
          if (gid != null && gid.isNotEmpty) {
            final ok = await gameCtrl.loadGame(gid);
            if (ok && gameCtrl.game != null) {
              if (!mounted) return;
              Navigator.pushReplacementNamed(context, '/game/${gameCtrl.game!.id}');
              return;
            }
          }

          // Fallbacks: try loading by using roomId as a game id
          try {
            final tryByRoom = await gameCtrl.loadGameByRoom(widget.roomId);
            if (tryByRoom && gameCtrl.game != null) {
              if (!mounted) return;
              Navigator.pushReplacementNamed(context, '/game/${gameCtrl.game!.id}');
              return;
            }
          } catch (_) {}

          // If we reach here, we couldn't find the active game — let
          // the user stay in the waiting room and use the debug buttons to inspect.
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room already in-game but no active game could be located.')));
        }
      } catch (_) {}

      // start polling so the waiting room updates automatically
      // Polling merged safely in controller; enable it for normal behavior.
      // Use a shorter interval (1s) to reduce perceived latency when SignalR is unavailable.
      ctrl.startPolling(intervalSeconds: 1);

      // Also start a focused watcher that checks whether an active game
      // exists for this room (some backends create a game but do not
      // immediately update the public rooms list). This ensures players
      // in the waiting room are redirected to the active game promptly.
      _roomWatcherTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
        try {
          // First refresh the room info from the lobby so we pick up any
          // server-side updates such as `status` or `gameId`.
          final lobby = Provider.of<LobbyController>(context, listen: false);
          final refreshed = await lobby.getRoomById(widget.roomId);
          if (refreshed != null) {
            // If the room has an explicit game id or status changed to in-game,
            // try to load the game by id first (preferred), otherwise probe
            // using loadGameByRoom as a fallback.
            final gid = refreshed.gameId;
            if (gid != null && gid.isNotEmpty) {
              final ok = await gameCtrl.loadGame(gid);
              if (ok && gameCtrl.game != null) {
                // Wait briefly for players to be present; sometimes the
                // server creates the game record before populating players.
                bool ready = false;
                for (int attempt = 0; attempt < 5; attempt++) {
                  if (gameCtrl.game != null && gameCtrl.game!.players.isNotEmpty) { ready = true; break; }
                  await Future.delayed(const Duration(milliseconds: 400));
                  try { await gameCtrl.loadGame(gid); } catch (_) {}
                }
                if (!mounted) return;
                if (!ready && (gameCtrl.game == null || gameCtrl.game!.players.isEmpty)) {
                  // If still not ready, inform user and continue watching
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Esperando a que se sincronicen los jugadores...')));
                  return;
                }
                _roomWatcherTimer?.cancel();
                Navigator.pushReplacementNamed(context, '/game/${gameCtrl.game!.id}');
                return;
              }
            }
            if (refreshed.status != null && refreshed.status!.toLowerCase().contains('ingame')) {
              final found = await gameCtrl.loadGameByRoom(widget.roomId);
              if (found && gameCtrl.game != null) {
                bool ready = false;
                for (int attempt = 0; attempt < 5; attempt++) {
                  if (gameCtrl.game != null && gameCtrl.game!.players.isNotEmpty) { ready = true; break; }
                  await Future.delayed(const Duration(milliseconds: 400));
                  try { await gameCtrl.loadGameByRoom(widget.roomId); } catch (_) {}
                }
                if (!mounted) return;
                if (!ready && (gameCtrl.game == null || gameCtrl.game!.players.isEmpty)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Esperando a que se sincronicen los jugadores...')));
                  return;
                }
                _roomWatcherTimer?.cancel();
                Navigator.pushReplacementNamed(context, '/game/${gameCtrl.game!.id}');
                return;
              }
            }
          }
          // Final attempt: probe the game endpoint directly by room id
          final found = await gameCtrl.loadGameByRoom(widget.roomId);
          if (found && gameCtrl.game != null) {
            if (!mounted) return;
            _roomWatcherTimer?.cancel();
            Navigator.pushReplacementNamed(context, '/game/${gameCtrl.game!.id}');
            return;
          }
        } catch (e) {
          // keep watching; log for debugging
          try { final s = e.toString();  print('WaitingRoom watcher error: $s'); } catch (_) {}
        }
      });

      await _ensureJoinedIfNeeded();
    });
  }

  Future<void> _ensureJoinedIfNeeded() async {
    try {
      final lobby = Provider.of<LobbyController>(context, listen: false);
      final auth = Provider.of<AuthController>(context, listen: false);
      if (!auth.isLoggedIn) return;
      final username = auth.username ?? '';
      // Refresh room info first
      final r = await lobby.getRoomById(widget.roomId);
      if (r == null) return;
      if (username.isNotEmpty && !r.playerNames.map((s) => s.trim().toLowerCase()).contains(username.trim().toLowerCase())) {
        // Try to join up to a few times — some servers are eventually consistent
        bool joined = false;
        String? lastErr;
        for (int attempt = 0; attempt < 4 && !joined; attempt++) {
          try {
            final ok = await lobby.joinRoom(widget.roomId);
            if (ok) {
              joined = true;
              break;
            }
            lastErr = lobby.error;
          } catch (e) {
            lastErr = e.toString();
          }
          // Refresh room info before retrying
          try { await lobby.getRoomById(widget.roomId); } catch (_) {}
          await Future.delayed(const Duration(milliseconds: 500));
        }
        if (joined) {
          await lobby.getRoomById(widget.roomId);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You were added to the room.')));
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Auto-join failed: ${lastErr ?? lobby.error}')));
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    try {
      final ctrl = Provider.of<LobbyController>(context, listen: false);
      ctrl.stopPolling();
      _roomWatcherTimer?.cancel();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lobby = Provider.of<LobbyController>(context);
    final gameCtrl = Provider.of<GameController>(context, listen: false);
    final auth = Provider.of<AuthController>(context, listen: false);

    final room = lobby.rooms.firstWhere((r) => r.id == widget.roomId, orElse: () => RoomSummaryDto(id: widget.roomId, name: 'Room', players: 0, maxPlayers: 0));

    final bool canStart = (room.players) >= 2;
    final bool isOwner = (room.ownerId != null && auth.userId != null && room.ownerId == auth.userId) || room.ownerId == null;

    return Scaffold(
      appBar: AppBar(title: Text('Waiting Room ${widget.roomId}'), actions: const [LogoutButton()]),
      body: Column(
        children: [
          // Gradient header with room title
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF4A90E2), Color(0xFF6FB1FF)]),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(room.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('Players: ${room.players}/${room.maxPlayers}', style: const TextStyle(color: Colors.white70)),
                    const SizedBox(width: 12),
                    if (room.ownerName != null) Chip(label: Text(room.ownerName!), backgroundColor: Colors.white24, labelStyle: const TextStyle(color: Colors.white)),
                  ],
                )
              ],
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Waiting players:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: room.playerNames.isNotEmpty
                            ? ListView.separated(
                                itemCount: room.playerNames.length,
                                separatorBuilder: (_, __) => const Divider(),
                                itemBuilder: (context, i) {
                                  final name = room.playerNames[i];
                                  final initials = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
                                  final isOwnerTile = room.ownerName != null && room.ownerName == name;
                                  final isMe = (auth.username != null && auth.username == name);
                                  return ListTile(
                                    leading: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        CircleAvatar(radius: 22, backgroundColor: isOwnerTile ? Colors.amber.shade700 : Theme.of(context).primaryColor.withOpacity(0.15)),
                                        CircleAvatar(radius: 18, backgroundColor: isOwnerTile ? Colors.amber : (isMe ? Colors.green : Theme.of(context).primaryColor), child: Text(initials, style: const TextStyle(color: Colors.white))),
                                      ],
                                    ),
                                    title: Text(name, style: TextStyle(fontWeight: isOwnerTile ? FontWeight.bold : FontWeight.normal)),
                                    subtitle: isMe ? const Text('You', style: TextStyle(color: Colors.green)) : null,
                                    trailing: isOwnerTile ? const Icon(Icons.star, color: Colors.amber) : null,
                                  );
                                },
                              )
                            : const Center(child: Text('No players joined yet.')),
                      ),

                      // Debug panel to help diagnose empty player lists
                      if (room.playerNames.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Debug info:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
                              const SizedBox(height: 6),
                              if (lobby.error != null) Text('Last error: ${lobby.error}', style: const TextStyle(color: Colors.red)),
                              Text('Known rooms cached: ${lobby.rooms.length}', style: const TextStyle(color: Colors.black54)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Fetch Room'),
                                    onPressed: () async {
                                      await lobby.getRoomById(widget.roomId);
                                      setState(() {});
                                      await _ensureJoinedIfNeeded();
                                    },
                                  ),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.sync),
                                    label: const Text('Fetch All Rooms'),
                                    onPressed: () async {
                                      await lobby.loadRooms();
                                      setState(() {});
                                    },
                                  ),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.code),
                                    label: const Text('Show Raw JSON'),
                                    onPressed: () async {
                                      try {
                                        final client = ApiClient();
                                        final raw = await client.getJson('/api/Lobby/rooms/${widget.roomId}');
                                        final pretty = const JsonEncoder.withIndent('  ').convert(raw);
                                        if (!mounted) return;
                                        showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Room JSON'), content: SingleChildScrollView(child: Text(pretty)), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))]));
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching raw JSON: ${e.toString()}')));
                                      }
                                    },
                                  ),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.login),
                                    label: const Text('Try Re-join'),
                                    onPressed: () async {
                                      final ok = await lobby.joinRoom(widget.roomId);
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Join succeeded' : 'Join failed: ${lobby.error}')));
                                      await lobby.getRoomById(widget.roomId);
                                      setState(() {});
                                      await _ensureJoinedIfNeeded();
                                    },
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),

                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh'),
                            onPressed: () async {
                              await lobby.getRoomById(widget.roomId);
                              setState(() {});
                            },
                          ),
                          const SizedBox(width: 12),
                          // If a game is active for this room, allow entering directly
                          if ((room.status != null && room.status!.toLowerCase().contains('ingame')) || (room.gameId?.isNotEmpty ?? false))
                            Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.videogame_asset),
                                label: const Text('Enter Game'),
                                onPressed: () async {
                                  // Attempt to load/join the active game for this room
                                  try {
                                    // Prefer explicit gameId
                                    if (room.gameId != null && room.gameId!.isNotEmpty) {
                                      final ok = await gameCtrl.loadGame(room.gameId!);
                                      if (ok && gameCtrl.game != null) {
                                        // Verify local player is present on the server-side game
                                        final prefs = Provider.of<AuthController>(context, listen: false);
                                        final localName = prefs.username ?? '';
                                        bool present = gameCtrl.game!.players.any((p) => p.username.trim().toLowerCase() == localName.trim().toLowerCase());
                                        if (!present) {
                                          // Try to join the lobby room and also attempt to attach
                                          // to the existing game via `createOrJoinGame` which some
                                          // backends use to add an existing room player into the
                                          // active game. Retry a few times to handle eventual consistency.
                                          final lobby = Provider.of<LobbyController>(context, listen: false);
                                          for (int attempt = 0; attempt < 4 && !present; attempt++) {
                                            try { await lobby.joinRoom(widget.roomId); } catch (_) {}
                                            try { await lobby.getRoomById(widget.roomId); } catch (_) {}
                                            // Attempt to join the game explicitly (safe: server may
                                            // return existing game or add player to it).
                                            try { await gameCtrl.createOrJoinGame(roomId: widget.roomId); } catch (_) {}
                                            try { await gameCtrl.loadGame(room.gameId!); } catch (_) {}
                                            if (gameCtrl.game != null) {
                                              present = gameCtrl.game!.players.any((p) => p.username.trim().toLowerCase() == localName.trim().toLowerCase());
                                            }
                                            if (present) break;
                                            await Future.delayed(const Duration(milliseconds: 500));
                                          }
                                        }

                                        if (present) {
                                          if (!mounted) return;
                                          Navigator.pushReplacementNamed(context, '/game/${gameCtrl.game!.id}');
                                          return;
                                        }
                                      }
                                    }

                                    // Try loading by roomId (some backends use the same id)
                                    final tryByRoom = await gameCtrl.loadGameByRoom(widget.roomId);
                                    if (tryByRoom && gameCtrl.game != null) {
                                      // Verify presence similarly
                                      final prefs = Provider.of<AuthController>(context, listen: false);
                                      final localName = prefs.username ?? '';
                                      bool present = gameCtrl.game!.players.any((p) => p.username.trim().toLowerCase() == localName.trim().toLowerCase());
                                      if (!present) {
                                        final lobby = Provider.of<LobbyController>(context, listen: false);
                                        for (int attempt = 0; attempt < 4 && !present; attempt++) {
                                          try { await lobby.joinRoom(widget.roomId); } catch (_) {}
                                          try { await lobby.getRoomById(widget.roomId); } catch (_) {}
                                          // Try to attach to the active game if server requires
                                          // an explicit game join action.
                                          try { await gameCtrl.createOrJoinGame(roomId: widget.roomId); } catch (_) {}
                                          try { await gameCtrl.loadGameByRoom(widget.roomId); } catch (_) {}
                                          if (gameCtrl.game != null) {
                                            present = gameCtrl.game!.players.any((p) => p.username.trim().toLowerCase() == localName.trim().toLowerCase());
                                          }
                                          if (present) break;
                                          await Future.delayed(const Duration(milliseconds: 500));
                                        }
                                      }
                                      if (present) {
                                        if (!mounted) return;
                                        Navigator.pushReplacementNamed(context, '/game/${gameCtrl.game!.id}');
                                        return;
                                      }
                                    }

                                    // If we couldn't find a game for this room or local user isn't in it, inform the user
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(gameCtrl.error ?? 'No active game found for this room or you are not in the game yet.')));
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enter game failed: ${e.toString()}')));
                                  }
                                },
                              ),
                            ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canStart ? Colors.green : Colors.grey,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.play_arrow),
                            label: Text(canStart ? 'Start Game' : 'Need more players'),
                            onPressed: (!canStart || !isOwner)
                                ? null
                                : () async {
                                    // refresh before starting
                                    final r = await lobby.getRoomById(widget.roomId);
                                    if (r == null || (r.players < 2)) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Need at least 2 players to start the game.')));
                                      setState(() {});
                                      return;
                                    }

                                      // Try to create/join the game. If the server complains
                                      // about player counts, refresh the room a few times
                                      // and retry briefly to handle eventual consistency.
                                      bool created = false;
                                      String? lastErr;
                                      for (int attempt = 0; attempt < 4 && !created; attempt++) {
                                        final ok = await gameCtrl.createOrJoinGame(roomId: widget.roomId);
                                        if (ok && gameCtrl.game != null) {
                                          created = true;
                                          break;
                                        }
                                        lastErr = gameCtrl.error;
                                        // If server indicates missing players, refresh room and wait
                                        if (lastErr != null && lastErr.toLowerCase().contains('need at least')) {
                                          await lobby.getRoomById(widget.roomId);
                                          await Future.delayed(const Duration(milliseconds: 600));
                                          continue;
                                        }
                                        // For other errors, don't retry aggressively
                                        break;
                                      }
                                      if (created && gameCtrl.game != null) {
                                        // Ensure local player is present in the server game
                                        final prefs = Provider.of<AuthController>(context, listen: false);
                                        final localName = prefs.username ?? '';
                                        bool present = false;
                                        // Try a few short retries to wait for server to include the player
                                        for (int check = 0; check < 6 && !present; check++) {
                                          try {
                                            // Refresh room and attempt to load the game by room
                                            await lobby.getRoomById(widget.roomId);
                                            await gameCtrl.loadGameByRoom(widget.roomId);
                                          } catch (_) {}
                                          if (gameCtrl.game != null) {
                                            present = gameCtrl.game!.players.any((p) => (p.username.trim().toLowerCase() == localName.trim().toLowerCase()));
                                          }
                                          if (present) break;
                                          await Future.delayed(const Duration(milliseconds: 500));
                                        }
                                        if (!present) {
                                          // If still not present, show error so user knows join may have failed
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo confirmar que estés en la partida. Intenta entrar manualmente.')));
                                        } else {
                                          final id = gameCtrl.game!.id;
                                          if (!mounted) return;
                                          Navigator.pushReplacementNamed(context, '/game/$id');
                                          return;
                                        }
                                      } else {
                                        final err = gameCtrl.error ?? lastErr ?? 'Failed to create game';
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                                      }
                                  },
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
