import 'package:flutter/material.dart';
import '../../../core/models/player_state_dto.dart';
import '../../../core/models/snake_dto.dart';
import '../../../core/models/ladder_dto.dart';

class GameBoardWidgetClean extends StatefulWidget {
  final List<PlayerStateDto> players;
  final List<SnakeDto> snakes;
  final List<LadderDto> ladders;
  final int size; // number of tiles per side (10 => 100)
  const GameBoardWidgetClean({super.key, required this.players, this.snakes = const [], this.ladders = const [], this.size = 10});

  @override
  State<GameBoardWidgetClean> createState() => _GameBoardWidgetCleanState();
}

class _GameBoardWidgetCleanState extends State<GameBoardWidgetClean> {
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
        final tileSize = constraints.maxWidth / widget.size;
        return Container(
          decoration: BoxDecoration(border: Border.all(color: Colors.black87)),
          child: Stack(
            children: [
              Positioned.fill(
                child: Column(
                  children: List.generate(widget.size, (row) {
                    final isReversed = (widget.size - 1 - row) % 2 == 1;
                    return Expanded(
                      child: Row(
                        children: List.generate(widget.size, (col) {
                          final visualCol = isReversed ? (widget.size - 1 - col) : col;
                          final tileIndex = (widget.size * (widget.size - 1 - row)) + visualCol + 1;
                          return Container(
                            width: tileSize,
                            height: tileSize,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black26),
                              color: ((row + col) % 2 == 0) ? Colors.grey[100] : Colors.white,
                            ),
                            child: Stack(
                              children: [
                                Positioned(left: 4, top: 4, child: Text('$tileIndex', style: const TextStyle(fontSize: 10, color: Colors.black54))),
                                Positioned(
                                  right: 4,
                                  bottom: 4,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      ...widget.snakes.where((s) => s.headPosition == tileIndex).map((s) => Container(
                                            width: tileSize * 0.14,
                                            height: tileSize * 0.14,
                                            decoration: BoxDecoration(color: Colors.teal[300], borderRadius: BorderRadius.circular(4)),
                                            child: const Icon(Icons.school, size: 12, color: Colors.white),
                                          )),
                                      ...widget.ladders.where((l) => l.bottomPosition == tileIndex).map((l) => Container(
                                            width: tileSize * 0.14,
                                            height: tileSize * 0.14,
                                            decoration: BoxDecoration(color: Colors.brown[400], shape: BoxShape.circle),
                                            child: const Icon(Icons.person, size: 10, color: Colors.white),
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
              ),
              Positioned.fill(
                child: Stack(
                  children: widget.players.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final player = entry.value;
                    final center = _tileCenter(player.position, tileSize, widget.size);
                    final tokenSize = tileSize * 0.2;
                    final left = center.dx - tokenSize / 2;
                    final top = center.dy - tokenSize / 2;
                    return AnimatedPositioned(
                      key: ValueKey(player.id),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeInOut,
                      left: left,
                      top: top,
                      width: tokenSize,
                      height: tokenSize,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _playerColor(idx),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(player.username.isNotEmpty ? player.username[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Positioned(left: 6, bottom: 6, child: SizedBox(child: Text('Start: 1', style: TextStyle(fontSize: 12)))),
              const Positioned(right: 6, top: 6, child: SizedBox(child: Text('Finish: 100', style: TextStyle(fontSize: 12)))),
            ],
          ),
        );
      }),
    );
  }
}
