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
    // start polling after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = Provider.of<LobbyController>(context, listen: false);
      // Start polling every 2 minutes (120s) to avoid excessive refreshes.
      ctrl.startPolling(intervalSeconds: 120);
      ctrl.loadRooms();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    final ctrl = Provider.of<LobbyController>(context, listen: false);
    ctrl.stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Provider.of<LobbyController>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Lobby'), actions: [
        IconButton(
          tooltip: 'Go to Login',
          icon: const Icon(Icons.login),
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
          },
        ),
        IconButton(
          tooltip: 'Register',
          icon: const Icon(Icons.app_registration),
          onPressed: () {
            Navigator.pushNamed(context, '/register');
          },
        ),
        const LogoutButton(),
      ]),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Search by room id
            Row(
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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a room id')));
                      return;
                    }
                    final room = await ctrl.getRoomById(id);
                    if (room != null) {
                      Navigator.pushNamed(context, '/rooms/${room.id}');
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ctrl.error ?? 'Room not found')));
                    }
                  },
                  child: const Text('Find'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text('Rooms', style: Theme.of(context).textTheme.titleLarge)),
                IconButton(
                  onPressed: () async {
                    // Manual reload: fetch immediately and reset the 2-minute timer
                    await ctrl.loadRooms();
                    ctrl.startPolling(intervalSeconds: 120);
                  },
                  icon: const Icon(Icons.refresh),
                )
              ],
            ),
            Expanded(
              child: ctrl.loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: ctrl.rooms.length,
                      itemBuilder: (ctx, i) {
                        final r = ctrl.rooms[i];
                        final initials = (r.name.isNotEmpty ? r.name.trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join() : 'R').toUpperCase();
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.secondary, child: Text(initials, style: const TextStyle(color: Colors.white))),
                            title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(r.ownerName != null ? 'Host: ${r.ownerName} • ${r.players}/${r.maxPlayers} players' : '${r.players}/${r.maxPlayers} players'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Chip(label: Text('${r.players}/${r.maxPlayers}')),
                                const SizedBox(height: 6),
                                if (r.ownerName != null) Text(r.ownerName!, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                              ],
                            ),
                            onTap: () => Navigator.pushNamed(context, '/rooms/${r.id}'),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Create Room', style: TextStyle(fontSize: 16)),
                  ),
                  onPressed: () => _showCreateDialog(context, ctrl),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, LobbyController ctrl) {
    final TextEditingController nameCtrl = TextEditingController(text: 'Room ${DateTime.now().millisecondsSinceEpoch % 1000}');
    int maxPlayers = 4;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Room'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Room name')),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Max players:'),
                const SizedBox(width: 12),
                DropdownButton<int>(value: maxPlayers, items: [2, 3, 4, 6].map((v) => DropdownMenuItem(value: v, child: Text('$v'))).toList(), onChanged: (v) { if (v != null) { maxPlayers = v; } }),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.of(ctx).pop();
              final room = await ctrl.createRoom(name);
              if (room == null || room.id.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ctrl.error ?? 'Create failed')));
              } else {
                Navigator.pushNamed(context, '/rooms/${room.id}');
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
