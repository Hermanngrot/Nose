import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/lobby_controller.dart';
import '../../../core/models/room_summary_dto.dart';
import '../../../core/models/game_state_dto.dart';
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
      ctrl.startPolling(intervalSeconds: 3);

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
      if (username.isNotEmpty && !r.playerNames.contains(username)) {
        final ok = await lobby.joinRoom(widget.roomId);
        if (ok) {
          await lobby.getRoomById(widget.roomId);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You were added to the room.')));
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Auto-join failed: ${lobby.error}')));
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    try {
      final ctrl = Provider.of<LobbyController>(context, listen: false);
      ctrl.stopPolling();
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
                                        if (!mounted) return;
                                        Navigator.pushReplacementNamed(context, '/game/${gameCtrl.game!.id}');
                                        return;
                                      }
                                    }

                                    // Try loading by roomId (some backends use the same id)
                                    final tryByRoom = await gameCtrl.loadGameByRoom(widget.roomId);
                                    if (tryByRoom && gameCtrl.game != null) {
                                      if (!mounted) return;
                                      Navigator.pushReplacementNamed(context, '/game/${gameCtrl.game!.id}');
                                      return;
                                    }

                                    // If we couldn't find a game for this room, inform the user
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(gameCtrl.error ?? 'No active game found for this room.')));
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

                                    final ok = await gameCtrl.createOrJoinGame(roomId: widget.roomId);
                                    if (ok && gameCtrl.game != null) {
                                      final id = gameCtrl.game!.id;
                                      if (!mounted) return;
                                      Navigator.pushReplacementNamed(context, '/game/$id');
                                    } else {
                                      final err = gameCtrl.error ?? 'Failed to create game';
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
