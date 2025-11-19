import 'package:flutter/material.dart';
import '../../../core/models/player_state_dto.dart';
import '../../../core/models/snake_dto.dart';
import '../../../core/models/ladder_dto.dart';

class GameBoardWidget extends StatefulWidget {
  final List<PlayerStateDto> players;
  final List<SnakeDto> snakes;
  final List<LadderDto> ladders;
  final int size; // number of tiles per side (10 => 100)
  const GameBoardWidget({super.key, required this.players, this.snakes = const [], this.ladders = const [], this.size = 10});

  @override
  State<GameBoardWidget> createState() => _GameBoardWidgetState();
}

class _GameBoardWidgetState extends State<GameBoardWidget> {
  Color _playerColor(int idx) {
    const palette = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.brown,
      Colors.pink,
    ];
    return palette[idx % palette.length];
  }

  Offset _tileCenter(int tileIndex, double tileSize, int size) {
    if (tileIndex <= 0) return Offset(-tileSize, -tileSize);
    final idx = tileIndex - 1;
    final rowFromBottom = idx ~/ size;
    final colInRow = idx % size;
    final row = (size - 1) - rowFromBottom;
    final isReversed = rowFromBottom % 2 == 1;
    final col = isReversed ? (size - 1 - colInRow) : colInRow;
    final left = col * tileSize;
    final top = row * tileSize;
    return Offset(left + tileSize / 2, top + tileSize / 2);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(builder: (context, constraints) {
        final minSide = constraints.maxWidth < constraints.maxHeight ? constraints.maxWidth : constraints.maxHeight;
        final tileSize = minSide / widget.size;
        final boardPx = tileSize * widget.size;

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth, maxHeight: constraints.maxHeight),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: boardPx,
                height: boardPx,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.blue.shade50, Colors.green.shade50], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  ),
                  child: Stack(
                    children: [
                      // Grid
                      Column(
                        children: List.generate(widget.size, (row) {
                          final isReversed = (widget.size - 1 - row) % 2 == 1;
                          return Expanded(
                            child: Row(
                              children: List.generate(widget.size, (col) {
                                final visualCol = isReversed ? (widget.size - 1 - col) : col;
                                final tileIndex = (widget.size * (widget.size - 1 - row)) + visualCol + 1;
                                final bool isEven = (row + col) % 2 == 0;
                                return Container(
                                  width: tileSize,
                                  height: tileSize,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.black12),
                                    color: isEven ? Colors.white.withOpacity(0.85) : Colors.blueGrey.withOpacity(0.06),
                                  ),
                                  child: Stack(
                                    children: [
                                      // Tile index
                                      Positioned(left: 6, top: 6, child: Text('$tileIndex', style: TextStyle(fontSize: (tileSize * 0.18).clamp(10.0, 18.0), color: Colors.black54))),
                                      // Professores (ladders) and Matones (snakes)
                                      Positioned(
                                        right: 6,
                                        bottom: 6,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            // Matones (previously snakes): show bully icon in red
                                            ...widget.snakes.where((s) => s.headPosition == tileIndex).map((s) => Container(
                                                  width: tileSize * 0.18,
                                                  height: tileSize * 0.18,
                                                  decoration: BoxDecoration(color: Colors.redAccent.shade200, borderRadius: BorderRadius.circular(6)),
                                                  child: const Icon(Icons.mood_bad, size: 14, color: Colors.white),
                                                )),
                                            // Profesores (previously ladders): show teacher icon in green
                                            ...widget.ladders.where((l) => l.bottomPosition == tileIndex).map((l) => Container(
                                                  width: tileSize * 0.18,
                                                  height: tileSize * 0.18,
                                                  decoration: BoxDecoration(color: Colors.green.shade600, borderRadius: BorderRadius.circular(6)),
                                                  child: const Icon(Icons.school, size: 14, color: Colors.white),
                                                )),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                          );
                        }),
                      ),

                      // Tokens layer
                      ...widget.players.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final player = entry.value;
                        final center = _tileCenter(player.position, tileSize, widget.size);
                        final tokenSize = (tileSize * 0.36).clamp(14.0, tileSize * 0.7);
                        double left = center.dx - tokenSize / 2;
                        double top = center.dy - tokenSize / 2;
                        left = left.clamp(0.0, boardPx - tokenSize);
                        top = top.clamp(0.0, boardPx - tokenSize);
                        return Positioned(
                          left: left.toDouble(),
                          top: top.toDouble(),
                          width: tokenSize,
                          height: tokenSize,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                            child: Tooltip(
                              message: player.username,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _playerColor(idx).withOpacity(0.95),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: const Offset(0, 3))],
                                ),
                                alignment: Alignment.center,
                                child: Text(player.username.isNotEmpty ? player.username[0].toUpperCase() : '?', style: TextStyle(color: Colors.white, fontSize: (tokenSize * 0.45).clamp(12.0, 18.0), fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        );
                      }).toList(),

                      // Labels
                      const Positioned(left: 8, bottom: 8, child: Text('Start: 1', style: TextStyle(fontSize: 12))),
                      Positioned(right: 8, top: 8, child: Text('Finish: ${widget.size * widget.size}', style: const TextStyle(fontSize: 12))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
