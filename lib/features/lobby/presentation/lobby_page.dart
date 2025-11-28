import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/lobby_controller.dart';
import '../../auth/presentation/logout_button.dart';

class LobbyPage extends StatefulWidget {
  const LobbyPage({super.key});

  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = Provider.of<LobbyController>(context, listen: false);

      // Poll cada 2 minutos para refrescar lista de salas
      ctrl.startPolling(intervalSeconds: 120);
      ctrl.loadRooms();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    Provider.of<LobbyController>(context, listen: false).stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Provider.of<LobbyController>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lobby'),
        actions: const [LogoutButton()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _buildSearchBar(context, ctrl),
            const SizedBox(height: 16),
            _buildHeader(context, ctrl),
            Expanded(
              child: ctrl.loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildRoomList(context, ctrl),
            ),
            const SizedBox(height: 16),
            _buildCreateButton(context, ctrl),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // SEARCH BAR
  // ---------------------------------------------------------------
  Widget _buildSearchBar(BuildContext context, LobbyController ctrl) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              labelText: 'Find room by ID',
              hintText: 'Enter room id',
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () async {
            final id = _searchCtrl.text.trim();
            if (id.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a room id')),
              );
              return;
            }

            final room = await ctrl.getRoomById(id);
            if (room != null) {
              Navigator.pushNamed(context, '/rooms/${room.id}');
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(ctrl.error ?? 'Room not found')),
              );
            }
          },
          child: const Text('Find'),
        )
      ],
    );
  }

  // ---------------------------------------------------------------
  // HEADER WITH REFRESH BUTTON
  // ---------------------------------------------------------------
  Widget _buildHeader(BuildContext context, LobbyController ctrl) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Rooms',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        IconButton(
          onPressed: () async {
            await ctrl.loadRooms();
            ctrl.startPolling(intervalSeconds: 120);
          },
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------
  // LIST OF ROOMS
  // ---------------------------------------------------------------
  Widget _buildRoomList(BuildContext context, LobbyController ctrl) {
    return ListView.builder(
      itemCount: ctrl.rooms.length,
      itemBuilder: (ctx, i) {
        final r = ctrl.rooms[i];

        final initials = r.name.isNotEmpty
            ? r.name
                .trim()
                .split(' ')
                .where((s) => s.isNotEmpty)
                .map((s) => s[0])
                .take(2)
                .join()
                .toUpperCase()
            : "R";

        final currentPlayers = r.playerNames.length;
        final maxPlayers = r.maxPlayers;

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              child: Text(
                initials,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(
              r.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('$currentPlayers/$maxPlayers players'),
            trailing: Chip(label: Text('$currentPlayers/$maxPlayers')),
            onTap: () => Navigator.pushNamed(context, '/rooms/${r.id}'),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------
  // CREATE ROOM BUTTON
  // ---------------------------------------------------------------
  Widget _buildCreateButton(BuildContext context, LobbyController ctrl) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.add),
        label: const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('Create Room', style: TextStyle(fontSize: 16)),
        ),
        onPressed: () => _showCreateDialog(context, ctrl),
      ),
    );
  }

  // ---------------------------------------------------------------
  // CREATE ROOM DIALOG
  // ---------------------------------------------------------------
  void _showCreateDialog(BuildContext context, LobbyController ctrl) {
    final nameCtrl = TextEditingController(
      text: 'Room ${DateTime.now().millisecondsSinceEpoch % 1000}',
    );

    int maxPlayers = 4;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Room'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Room name'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Max players:'),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: maxPlayers,
                  items: [2, 3, 4, 6]
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text('$v'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) maxPlayers = v;
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              Navigator.of(ctx).pop();

              final room =
                  await ctrl.createRoom(name, maxPlayers: maxPlayers);

              if (room == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ctrl.error ?? 'Create failed')),
                );
                return;
              }

              Navigator.pushNamed(context, '/rooms/${room.id}');
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
