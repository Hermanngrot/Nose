import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/auth/state/auth_controller.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/auth/presentation/register_page.dart';
import 'features/lobby/presentation/lobby_page.dart';
import 'features/lobby/presentation/room_detail_page.dart';
import 'features/lobby/presentation/waiting_room_page.dart';
import 'features/game/presentation/game_board_page.dart';
import 'features/profile/presentation/profile_page.dart';
import 'features/leaderboard/presentation/leaderboard_page.dart';
import 'features/lobby/state/lobby_controller.dart';
import 'features/game/state/game_controller.dart';
import 'features/profile/state/profile_controller.dart';
import 'features/leaderboard/state/leaderboard_controller.dart';
import 'theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => LobbyController()),
        ChangeNotifierProvider(create: (_) => GameController()),
        ChangeNotifierProvider(create: (_) => ProfileController()),
        ChangeNotifierProvider(create: (_) => LeaderboardController()),
      ],
      child: MaterialApp(
        title: 'Profesores y Matones',
        theme: AppTheme.theme,
        initialRoute: '/login',
        routes: {
          '/login': (_) => const LoginPage(),
          '/register': (_) => const RegisterPage(),
          '/lobby': (_) => const LobbyPage(),
          '/profile': (_) => const ProfilePage(),
          '/leaderboard': (_) => const LeaderboardPage(),
        },
        onGenerateRoute: (settings) {
          final name = settings.name ?? '';
          if (name.startsWith('/rooms/')) {
              final sub = name.split('/rooms/').last;
              if (sub.contains('/waiting')) {
                final roomId = sub.split('/waiting').first.replaceAll(RegExp(r'^/'), '');
                return MaterialPageRoute(builder: (_) => WaitingRoomPage(roomId: roomId));
              }
              final roomId = sub;
              return MaterialPageRoute(builder: (_) => RoomDetailPage(roomId: roomId));
          }
          if (name.startsWith('/game/')) {
            final gameId = name.split('/game/').last;
            return MaterialPageRoute(builder: (_) => GameBoardPage(gameId: gameId));
          }
          return null;
        },
      ),
    );
  }
}
