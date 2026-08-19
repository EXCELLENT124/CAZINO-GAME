import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app_controller.dart';
import 'data/repositories.dart';
import 'data/supabase_repository.dart';
import 'domain/game/game_state.dart';
import 'domain/game/scoring.dart';
import 'domain/models/account.dart';
import 'domain/models/game_card.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppRepository repository;
  if (SupabaseConfig.configured) {
    await Supabase.initialize(
        url: SupabaseConfig.url, publishableKey: SupabaseConfig.key);
    repository = SupabaseRepository(Supabase.instance.client);
  } else {
    repository = LocalDemoRepository();
  }
  runApp(CazinoApp(controller: AppController(repository)));
}

class CazinoApp extends StatelessWidget {
  const CazinoApp({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'CAZINO',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xffd4a72c),
                brightness: Brightness.dark,
                surface: const Color(0xff101b18)),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xff08110f),
            inputDecorationTheme:
                const InputDecorationTheme(border: OutlineInputBorder())),
        home: SplashScreen(controller: controller),
      );
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<SplashScreen> createState() => _SplashState();
}

class _SplashState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted)
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => LoginScreen(controller: widget.controller)));
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
          body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.style, size: 88, color: Color(0xffd4a72c)),
        SizedBox(height: 18),
        Text('CAZINO',
            style: TextStyle(
                fontSize: 42, letterSpacing: 8, fontWeight: FontWeight.w800)),
        SizedBox(height: 8),
        Text('THE TABLE IS YOURS'),
        SizedBox(height: 28),
        CircularProgressIndicator(),
      ])));
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  final email = TextEditingController(text: 'lebo@cazino.demo'),
      password = TextEditingController(text: 'demo123');
  String? error;
  @override
  Widget build(BuildContext context) => Scaffold(
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.style,
                                size: 64, color: Color(0xffd4a72c)),
                            const SizedBox(height: 12),
                            const Text('Welcome to CAZINO',
                                style: TextStyle(
                                    fontSize: 28, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 28),
                            TextField(
                                controller: email,
                                decoration: const InputDecoration(
                                    labelText: 'Username or email address')),
                            const SizedBox(height: 12),
                            TextField(
                                controller: password,
                                obscureText: true,
                                decoration: const InputDecoration(
                                    labelText: 'Password')),
                            if (error != null)
                              Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(error!,
                                      style: const TextStyle(
                                          color: Colors.redAccent))),
                            const SizedBox(height: 16),
                            FilledButton(
                                onPressed: () async {
                                  try {
                                    await widget.controller
                                        .login(email.text, password.text);
                                    if (context.mounted)
                                      Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) => HomeScreen(
                                                  controller:
                                                      widget.controller)));
                                  } catch (e) {
                                    setState(() => error = '$e');
                                  }
                                },
                                child: const Text('Log in')),
                            TextButton(
                                onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => RegisterScreen(
                                            controller: widget.controller))),
                                child: const Text('Create an account')),
                          ]))))));
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<RegisterScreen> createState() => _RegisterState();
}

class _RegisterState extends State<RegisterScreen> {
  String? error;
  final fields = {
    for (final k in [
      'First name',
      'Last name',
      'Username',
      'Email',
      'Phone',
      'ID / passport number',
      'Address line 1',
      'City',
      'Province',
      'Postal code',
      'Country',
      'Password'
    ])
      k: TextEditingController()
  };
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Create your CAZINO account',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const Text(
            'Choose a unique username. You can log in using your username or email address.'),
        const SizedBox(height: 16),
        ...fields.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
                controller: e.value,
                obscureText: e.key == 'Password',
                decoration: InputDecoration(labelText: e.key)))),
        if (error != null)
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(error!,
                  style: const TextStyle(color: Colors.redAccent))),
        FilledButton(
            onPressed: () async {
              try {
                final f = fields;
                final username = f['Username']!.text.trim().toLowerCase();
                if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(username)) {
                  throw Exception(
                      'Username must use 3-20 letters, numbers, or underscores');
                }
                final account = PlayerAccount(
                    id: 'user-${DateTime.now().millisecondsSinceEpoch}',
                    firstName: f['First name']!.text,
                    lastName: f['Last name']!.text,
                    username: username,
                    email: f['Email']!.text,
                    phone: f['Phone']!.text,
                    idNumber: f['ID / passport number']!.text,
                    dateOfBirth: DateTime(1990),
                    address: Address(
                        line1: f['Address line 1']!.text,
                        city: f['City']!.text,
                        province: f['Province']!.text,
                        postalCode: f['Postal code']!.text,
                        country: f['Country']!.text));
                await widget.controller.register(account, f['Password']!.text);
                if (context.mounted) {
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              HomeScreen(controller: widget.controller)));
                }
              } catch (e) {
                if (mounted) setState(() => error = '$e');
              }
            },
            child: const Text('Create account')),
      ]));
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('CAZINO'), actions: [
        IconButton(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ProfileScreen(controller: controller))),
            icon: const Icon(Icons.person))
      ]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('Good game, ${controller.user!.firstName}',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
            'Challenge a player, keep your hand private, and own the table.'),
        const SizedBox(height: 12),
        Card(
            child: ListTile(
          leading: const Icon(Icons.monetization_on, color: Color(0xffd4a72c)),
          title: Text('${controller.coinBalance} coins'),
          subtitle: Text(controller.repository.isOnlineBackend
              ? '500 free coins available once per day'
              : 'Offline demonstration wallet'),
          trailing: TextButton(
            onPressed: () async {
              await controller.claimDailyCoins();
              if (context.mounted) (context as Element).markNeedsBuild();
            },
            child: const Text('Daily coins'),
          ),
        )),
        const SizedBox(height: 24),
        _MenuCard(
            icon: Icons.groups,
            title: 'Lobby',
            subtitle: 'Find players and start a 1v1 match',
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => LobbyScreen(controller: controller)))),
        _MenuCard(
            icon: Icons.sports_esports,
            title: 'Challenges',
            subtitle: 'View sent and received invitations',
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ChallengesScreen(controller: controller)))),
        _MenuCard(
            icon: Icons.chat,
            title: 'Player chat',
            subtitle: 'Messages stay in this local demo',
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ChatScreen(controller: controller)))),
      ]));
}

class _MenuCard extends StatelessWidget {
  const _MenuCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
      child: ListTile(
          contentPadding: const EdgeInsets.all(14),
          leading: Icon(icon, color: const Color(0xffd4a72c)),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap));
}

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    widget.controller.refreshOnlinePlayers().then((_) {
      if (mounted) setState(() {});
    });
    widget.controller.watchChallenges();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  Future<int?> chooseStake() => showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
          title: const Text('Choose equal stake'),
          children: AppController.allowedStakes
              .map((stake) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, stake),
                  child: Text('$stake coins each • ${stake * 2} coin pot')))
              .toList()));
  @override
  Widget build(BuildContext context) {
    final players = widget.controller.repository.players
        .where((p) => p.id != widget.controller.user!.id);
    return Scaffold(
        appBar: AppBar(title: const Text('Player lobby')),
        body: ListView(
            children: players
                .map((p) => ListTile(
                    leading: CircleAvatar(child: Text(p.firstName[0])),
                    title: Text(p.displayName),
                    subtitle: Text(
                        '${p.isOnline || !widget.controller.repository.isOnlineBackend ? 'Online' : 'Offline'}${widget.controller.repository.isFriend(p.id) ? ' • Friend' : ''}'),
                    trailing: Wrap(children: [
                      IconButton(
                          tooltip: 'Add friend',
                          onPressed: widget.controller.repository.isFriend(p.id)
                              ? null
                              : () async {
                                  await widget.controller.addFriend(p.id);
                                  if (mounted) setState(() {});
                                },
                          icon: Icon(widget.controller.repository.isFriend(p.id)
                              ? Icons.people
                              : Icons.person_add)),
                      FilledButton.tonal(
                          onPressed: () async {
                            final stake = await chooseStake();
                            if (stake == null) return;
                            await widget.controller
                                .challenge(p.id, stake: stake);
                            if (context.mounted)
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(
                                      'Challenge sent for $stake coins each')));
                          },
                          child: const Text('Challenge'))
                    ]),
                    onTap: () {
                      if (widget.controller.repository.isOnlineBackend) return;
                      widget.controller.startDemoGame(p.id);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  GameScreen(controller: widget.controller)));
                    }))
                .toList()));
  }
}

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  bool loading = false;
  String? error;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    widget.controller.refreshOnlinePlayers().then((_) {
      if (mounted) setState(() {});
    });
    widget.controller.watchChallenges();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final items = controller.repository.challengesFor(controller.user!.id);
    return Scaffold(
        appBar: AppBar(title: const Text('Challenges')),
        body: items.isEmpty
            ? const Center(
                child: Text(
                    'No challenges yet. Visit the lobby to invite a player.'))
            : ListView(children: [
                if (error != null)
                  Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(error!,
                          style: const TextStyle(color: Colors.redAccent))),
                ...items.map((c) => ListTile(
                    leading: const Icon(Icons.bolt),
                    title:
                        Text('${c.stake} coins each • ${c.stake * 2} coin pot'),
                    subtitle: Text(c.accepted
                        ? 'Accepted • Ready to play'
                        : c.fromPlayerId == controller.user!.id
                            ? 'Sent • Waiting for opponent'
                            : 'Received'),
                    trailing: c.accepted || c.toPlayerId == controller.user!.id
                        ? FilledButton(
                            onPressed: loading
                                ? null
                                : () async {
                                    setState(() {
                                      loading = true;
                                      error = null;
                                    });
                                    try {
                                      if (c.accepted) {
                                        await controller.joinOnlineChallenge(c);
                                      } else {
                                        await controller
                                            .acceptOnlineChallenge(c);
                                      }
                                      if (context.mounted)
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) => GameScreen(
                                                    controller: controller)));
                                    } catch (e) {
                                      if (mounted) setState(() => error = '$e');
                                    }
                                    if (mounted)
                                      setState(() => loading = false);
                                  },
                            child: Text(c.accepted ? 'Join' : 'Accept'))
                        : null))
              ]));
  }
}

class FicaScreen extends StatefulWidget {
  const FicaScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<FicaScreen> createState() => _FicaState();
}

class _FicaState extends State<FicaScreen> {
  final docs = <FicaDocument>[];
  Future<void> add(String type) async {
    final d = await widget.controller.repository.stageDocument(
        type, 'demo_${type.toLowerCase().replaceAll(' ', '_')}.pdf');
    setState(() => docs.add(d));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('FICA verification')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Icon(Icons.shield_outlined, size: 56, color: Color(0xffd4a72c)),
        const Text('Identity documents',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const Text(
            'Prototype only: files are represented by metadata and are not uploaded. A production adapter must use encrypted transport, private storage, retention controls, and an approved verifier.'),
        const SizedBox(height: 18),
        for (final type in [
          'Identity document',
          'Proof of address',
          'Selfie / liveness'
        ])
          ListTile(
              title: Text(type),
              subtitle: Text(docs.any((d) => d.type == type)
                  ? 'Staged for demo review'
                  : 'Required'),
              trailing: IconButton(
                  icon: const Icon(Icons.upload_file),
                  onPressed: () => add(type))),
        const SizedBox(height: 18),
        FilledButton(
            onPressed: docs.length == 3
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('FICA submission recorded for review')));
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              HomeScreen(controller: widget.controller)),
                      (_) => false,
                    );
                  }
                : null,
            child: const Text('Submit for review'))
      ]));
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final p = controller.user!;
    return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          CircleAvatar(
              radius: 42,
              child:
                  Text(p.firstName[0], style: const TextStyle(fontSize: 32))),
          const SizedBox(height: 14),
          Text(p.displayName,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
          ListTile(leading: const Icon(Icons.email), title: Text(p.email)),
          ListTile(leading: const Icon(Icons.phone), title: Text(p.phone)),
          ListTile(
              leading: const Icon(Icons.home),
              title: Text('${p.address.line1}, ${p.address.city}')),
          ListTile(
              leading: const Icon(Icons.badge),
              title: const Text('Identity details'),
              subtitle: const Text('Hidden for privacy')),
          OutlinedButton(
              onPressed: () async {
                await controller.logout();
                if (context.mounted)
                  Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (_) => LoginScreen(controller: controller)),
                      (_) => false);
              },
              child: const Text('Log out'))
        ]));
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<ChatScreen> createState() => _ChatState();
}

class _ChatState extends State<ChatScreen> {
  final text = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final messages = widget.controller.repository.messages('lobby');
    return Scaffold(
        appBar: AppBar(title: const Text('Player chat')),
        body: Column(children: [
          Expanded(
              child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: messages
                      .map((m) => Align(
                          alignment: m.senderId == widget.controller.user!.id
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Card(
                              child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(m.text)))))
                      .toList())),
          Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(
                    child: TextField(
                        controller: text,
                        decoration: const InputDecoration(
                            hintText: 'Message player...'))),
                IconButton(
                    onPressed: () async {
                      if (text.text.trim().isNotEmpty) {
                        await widget.controller.repository.sendMessage('lobby',
                            widget.controller.user!.id, text.text.trim());
                        text.clear();
                        setState(() {});
                      }
                    },
                    icon: const Icon(Icons.send))
              ]))
        ]));
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<GameScreen> createState() => _GameState();
}

class _GameState extends State<GameScreen> {
  GameCard? selected;
  final selectedOpponentCards = <GameCard>[];
  final selectedTable = <GameCard>[];
  final selectedBuilds = <TableBuild>[];
  String? notice;
  Timer? dealTimer;
  Timer? roundTwoDealTimer;
  Timer? scoreTimer;
  int introPhase = 0;
  int dealtCards = 0;
  int shuffleTick = 0;
  bool roundTwoDealActive = false;
  int roundTwoDealtCards = 0;
  int scoreStage = 0;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onlineChanged);
    dealTimer = Timer.periodic(const Duration(milliseconds: 120), (timer) {
      if (!mounted) return;
      if (introPhase == 0) {
        setState(() => shuffleTick++);
        if (shuffleTick >= 14) setState(() => introPhase = 1);
      } else if (introPhase == 1) {
        if (dealtCards < 20) {
          setState(() => dealtCards++);
        } else {
          timer.cancel();
          setState(() => introPhase = 2);
        }
      }
    });
  }

  void _onlineChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onlineChanged);
    dealTimer?.cancel();
    roundTwoDealTimer?.cancel();
    scoreTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final game = c.game!;
    if (introPhase < 3) return _buildDealIntro(context, game);
    if (roundTwoDealActive) return _buildRoundTwoDeal(context, game);
    if (game.phase == GamePhase.finished) return _buildFinalScoring(game);
    final activeId = c.gamePlayerId;
    final view = c.engine.viewFor(game, activeId);
    final mine = view.currentPlayerId == activeId;
    final opponentAdded =
        selectedOpponentCards.fold<int>(0, (sum, card) => sum + card.rank);
    final looseAdded = (selected?.rank ?? 0) +
        opponentAdded +
        selectedTable.fold<int>(0, (sum, card) => sum + card.rank);
    final retainsRawTarget = looseAdded <= 10 &&
        view.hand.any((card) => card != selected && card.rank == looseAdded);
    final explicitlySelectedBuild =
        selectedBuilds.isEmpty ? null : selectedBuilds.first;
    TableBuild? implicitOwnedBuild;
    if (explicitlySelectedBuild == null &&
        selected != null &&
        selectedTable.isNotEmpty) {
      for (final build in view.builds) {
        if (build.ownerId == activeId && build.target == looseAdded) {
          implicitOwnedBuild = build;
          break;
        }
      }
    }
    final actionBuild = explicitlySelectedBuild ?? implicitOwnedBuild;
    GameCard? strongAnchor;
    for (final anchor in selectedTable) {
      final otherTotal = (selected?.rank ?? 0) +
          opponentAdded +
          selectedTable
              .where((card) => card != anchor)
              .fold<int>(0, (sum, card) => sum + card.rank);
      if (actionBuild == null &&
          otherTotal > 0 &&
          otherTotal % anchor.rank == 0) {
        strongAnchor = anchor;
        break;
      }
    }
    final editingSimpleBuild = actionBuild != null &&
        !actionBuild.isStrong &&
        !actionBuild.isLocked &&
        actionBuild.ownerId != activeId;
    int? editableHigherTarget;
    if (editingSimpleBuild && selected != null) {
      for (var candidate = actionBuild.target + 1;
          candidate <= 10;
          candidate++) {
        final addedWithoutTargetAnchor = selected!.rank +
            opponentAdded +
            selectedTable
                .where((card) => card.rank != candidate)
                .fold<int>(0, (sum, card) => sum + card.rank);
        final retainsCandidate =
            view.hand.any((card) => card != selected && card.rank == candidate);
        if (actionBuild.target + addedWithoutTargetAnchor == candidate &&
            retainsCandidate) {
          editableHigherTarget = candidate;
          break;
        }
      }
    }
    final constructTotal = editingSimpleBuild && editableHigherTarget != null
        ? editableHigherTarget
        : actionBuild != null
            ? actionBuild.target
            : retainsRawTarget
                ? looseAdded
                : (strongAnchor?.rank ?? looseAdded);
    final strongConstruct =
        (strongAnchor != null && constructTotal == strongAnchor.rank) ||
            (editingSimpleBuild &&
                selectedTable.any((card) => card.rank == constructTotal)) ||
            (actionBuild != null &&
                actionBuild.ownerId == activeId &&
                looseAdded % actionBuild.target == 0);
    final opponentBuildSelected = actionBuild != null &&
        actionBuild.ownerId != activeId &&
        !editingSimpleBuild;
    final opponentOwnsTarget = actionBuild == null &&
        view.builds.any((build) =>
            build.target == constructTotal && build.ownerId != activeId);
    final canBuild = mine &&
        !c.buildGraceActive &&
        selected != null &&
        (selectedTable.isNotEmpty || actionBuild != null) &&
        !opponentBuildSelected &&
        !opponentOwnsTarget;
    final automaticChow = selected != null &&
        (view.tableCards.any((card) => card.rank == selected!.rank) ||
            view.builds.any((build) => build.target == selected!.rank));
    final continuationBuild = c.buildGraceActive &&
            actionBuild != null &&
            actionBuild.ownerId == activeId &&
            selectedTable.fold<int>(0, (sum, card) => sum + card.rank) +
                    opponentAdded ==
                actionBuild.target
        ? actionBuild
        : null;
    TableBuild? stashCandidate;
    if (selected != null &&
        view.hand
            .any((card) => card != selected && card.rank == selected!.rank)) {
      for (final build in view.builds) {
        if (build.ownerId == activeId &&
            build.target == selected!.rank &&
            !build.isLocked) {
          stashCandidate = build;
          break;
        }
      }
    }
    final activeName = c.playerName(activeId);
    return Scaffold(
        appBar: AppBar(
            title: Text(
                '$activeName • ${view.phase == GamePhase.roundOne ? 'FIRST ROUND' : 'SECOND ROUND'}'),
            actions: [
              IconButton(
                  tooltip: 'Edit player names',
                  onPressed: () => _editNames(context, game),
                  icon: const Icon(Icons.edit)),
              if (!c.isOnlineMatch)
                TextButton.icon(
                    onPressed: () {
                      c.switchDemoPlayer();
                      setState(() {
                        selected = null;
                        selectedOpponentCards.clear();
                        selectedTable.clear();
                        selectedBuilds.clear();
                        notice =
                            'Now controlling ${c.playerName(c.gamePlayerId)}';
                      });
                    },
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('SWITCH PLAYER')),
              IconButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ChatScreen(controller: c))),
                  icon: const Icon(Icons.chat))
            ]),
        body: SafeArea(
            child: Column(children: [
          Container(
              width: double.infinity,
              color: mine
                  ? Colors.green.withValues(alpha: .18)
                  : Colors.orange.withValues(alpha: .18),
              padding: const EdgeInsets.all(12),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        mine
                            ? '$activeName: YOUR TURN'
                            : '$activeName: WAITING',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                        'Taken ${view.capturedCounts[activeId]} • Other ${view.capturedCounts[game.opponentOf(activeId)]}')
                  ])),
          if (c.onlineSyncError != null)
            MaterialBanner(content: Text(c.onlineSyncError!), actions: [
              TextButton(
                  onPressed: () => setState(() {}),
                  child: const Text('DISMISS'))
            ]),
          Expanded(
              child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: const Color(0xff12372d),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white24)),
                  child: Row(children: [
                    CapturedPack(
                        label:
                            '${c.playerName(game.challengerId)}\nTAKEN CARDS',
                        cards:
                            view.capturedPacks[game.challengerId] ?? const [],
                        topSelectable: activeId != game.challengerId,
                        selectedCount: activeId == game.challengerId
                            ? 0
                            : selectedOpponentCards.length,
                        onTopTap: activeId == game.challengerId
                            ? null
                            : () => _selectNextOpponentCard(
                                view.capturedPacks[game.challengerId] ??
                                    const []),
                        onUndo: () =>
                            setState(() => selectedOpponentCards.removeLast())),
                    Expanded(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                          const Text(
                              'VISIBLE TABLE • TAP CARDS OR BUILDS TO SELECT'),
                          const SizedBox(height: 12),
                          if (game.drawPile.isNotEmpty)
                            DrawPile(count: game.drawPile.length),
                          const SizedBox(height: 12),
                          Wrap(
                              spacing: 8,
                              children: view.tableCards
                                  .map((card) => GestureDetector(
                                      onTap: () => setState(() =>
                                          selectedTable.contains(card)
                                              ? selectedTable.remove(card)
                                              : selectedTable.add(card)),
                                      child: Container(
                                          decoration: selectedTable.contains(card)
                                              ? BoxDecoration(
                                                  border: Border.all(
                                                      color: Colors.amber,
                                                      width: 3),
                                                  borderRadius:
                                                      BorderRadius.circular(9))
                                              : null,
                                          child: CardFace(
                                              card: card, small: true))))
                                  .toList()),
                          if (view.builds.isNotEmpty)
                            Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: view.builds
                                    .map((build) => BuildPile(
                                        tableBuild: build,
                                        ownerName: c.playerName(build.ownerId),
                                        selected:
                                            selectedBuilds.contains(build),
                                        onTap: () => setState(() =>
                                            selectedBuilds.contains(build)
                                                ? selectedBuilds.remove(build)
                                                : selectedBuilds.add(build))))
                                    .toList()),
                          if (selectedTable.isNotEmpty ||
                              selectedBuilds.isNotEmpty)
                            Text(
                                strongConstruct
                                    ? 'Compound constructed number $constructTotal'
                                    : 'Proposed construct: $constructTotal',
                                style: TextStyle(
                                    color: strongConstruct
                                        ? Colors.lightGreenAccent
                                        : Colors.amber,
                                    fontWeight: FontWeight.bold)),
                          if (c.buildGraceActive)
                            Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                    'CONTINUE BUILD: ${c.buildGraceSeconds}s before player switch',
                                    style: const TextStyle(
                                        color: Colors.lightGreenAccent,
                                        fontWeight: FontWeight.bold))),
                          if (notice != null)
                            Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(notice!,
                                    style:
                                        const TextStyle(color: Colors.amber)))
                        ])),
                    CapturedPack(
                        label: '${c.playerName(game.hostId)}\nTAKEN CARDS',
                        cards: view.capturedPacks[game.hostId] ?? const [],
                        topSelectable: activeId != game.hostId,
                        selectedCount: activeId == game.hostId
                            ? 0
                            : selectedOpponentCards.length,
                        onTopTap: activeId == game.hostId
                            ? null
                            : () => _selectNextOpponentCard(
                                view.capturedPacks[game.hostId] ?? const []),
                        onUndo: () =>
                            setState(() => selectedOpponentCards.removeLast())),
                  ]))),
          const Text('YOUR PRIVATE HAND'),
          SizedBox(
              height: 126,
              child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(10),
                  children: view.hand
                      .map((card) => GestureDetector(
                          onTap: () => setState(() => selected = card),
                          child: Container(
                              decoration: selected == card
                                  ? BoxDecoration(
                                      border: Border.all(
                                          color: Colors.amber, width: 3),
                                      borderRadius: BorderRadius.circular(10))
                                  : null,
                              child: CardFace(card: card))))
                      .toList())),
          Padding(
              padding: const EdgeInsets.all(10),
              child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton(
                        onPressed:
                            mine && !c.buildGraceActive && selected != null
                                ? () => act(() => c.throwCard(selected!))
                                : null,
                        child: Text(automaticChow
                            ? 'Chow ${selected!.rank} • matching build'
                            : 'Drift')),
                    if (stashCandidate != null)
                      FilledButton.tonal(
                          onPressed: mine && !c.buildGraceActive
                              ? () => act(() =>
                                  c.stashBuild(selected!, stashCandidate!))
                              : null,
                          child: Text(
                              'Drift ${selected!.rank} onto build • chow later')),
                    FilledButton.tonal(
                        onPressed: mine &&
                                !c.buildGraceActive &&
                                selected != null &&
                                (selectedTable.isNotEmpty ||
                                    selectedBuilds.isNotEmpty)
                            ? () => act(() => c.takeOff(
                                selected!, selectedTable, selectedBuilds))
                            : null,
                        child: const Text('Chow selected')),
                    if (c.buildGraceActive)
                      FilledButton(
                          onPressed: continuationBuild != null
                              ? () => act(() => c.continueBuild(
                                  continuationBuild,
                                  selectedTable,
                                  selectedOpponentCards))
                              : null,
                          child: Text(actionBuild == null
                              ? 'Select your build and a complete combination'
                              : 'Continue Build ${actionBuild.target}')),
                    OutlinedButton(
                        onPressed: canBuild
                            ? () => act(() => c.construct(
                                selected!,
                                selectedTable,
                                constructTotal,
                                actionBuild == null ? const [] : [actionBuild],
                                selectedOpponentCards))
                            : null,
                        child: Text(opponentBuildSelected || opponentOwnsTarget
                            ? 'Opponent build • chow only'
                            : selectedOpponentCards.isNotEmpty
                                ? 'Locked Strong Build $constructTotal'
                                : strongConstruct
                                    ? 'Add to Build $constructTotal'
                                    : 'Build $constructTotal'))
                  ]))
        ])));
  }

  Widget _buildDealIntro(BuildContext context, GameState game) {
    final playerOne = (dealtCards + 1) ~/ 2;
    final playerTwo = dealtCards ~/ 2;
    return Scaffold(
        appBar: AppBar(title: const Text('Preparing the table')),
        body: SafeArea(
            child: Container(
                color: const Color(0xff0d3128),
                padding: const EdgeInsets.all(18),
                child: Column(children: [
                  Text(
                      introPhase == 0
                          ? 'SHUFFLING ALL 40 CARDS'
                          : introPhase == 1
                              ? 'DEALING ONE CARD AT A TIME'
                              : 'THE TABLE IS READY',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(introPhase == 0
                      ? 'Shuffle ${shuffleTick + 1} of 14'
                      : '$dealtCards of 20 cards distributed'),
                  Expanded(
                      child: LayoutBuilder(
                          builder: (context, size) => Stack(children: [
                                if (introPhase == 0)
                                  Center(
                                      child: SizedBox(
                                          width: 260,
                                          height: 220,
                                          child: Stack(children: [
                                            for (var i = 0; i < 40; i++)
                                              AnimatedPositioned(
                                                duration: const Duration(
                                                    milliseconds: 100),
                                                left: 90 +
                                                    (((i * 17 +
                                                                    shuffleTick *
                                                                        31) %
                                                                70) -
                                                            35)
                                                        .toDouble(),
                                                top: 55 +
                                                    (((i * 29 +
                                                                    shuffleTick *
                                                                        19) %
                                                                60) -
                                                            30)
                                                        .toDouble(),
                                                child: Transform.rotate(
                                                  angle:
                                                      (((i + shuffleTick) % 9) -
                                                              4) *
                                                          0.035,
                                                  child: const CardBack(
                                                      width: 48, height: 68),
                                                ),
                                              ),
                                          ]))),
                                if (introPhase > 0) ...[
                                  Align(
                                      alignment: Alignment.topCenter,
                                      child: PlayerDealArea(
                                          label: widget.controller
                                              .playerName(game.hostId),
                                          cardCount: playerTwo)),
                                  Center(
                                      child: DrawPile(count: 40 - dealtCards)),
                                  Align(
                                      alignment: Alignment.bottomCenter,
                                      child: PlayerDealArea(
                                          label:
                                              '${widget.controller.playerName(game.challengerId)} • PLAYER 1',
                                          cardCount: playerOne)),
                                ],
                              ]))),
                  if (introPhase == 2)
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: FilledButton.icon(
                            onPressed: () => setState(() => introPhase = 3),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('COMMENCE GAME'))),
                ]))));
  }

  void _startRoundTwoDeal() {
    roundTwoDealTimer?.cancel();
    setState(() {
      roundTwoDealActive = true;
      roundTwoDealtCards = 0;
    });
    roundTwoDealTimer =
        Timer.periodic(const Duration(milliseconds: 180), (timer) {
      if (!mounted) return;
      if (roundTwoDealtCards < 20) {
        setState(() => roundTwoDealtCards++);
      } else {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) setState(() => roundTwoDealActive = false);
        });
      }
    });
  }

  Widget _buildRoundTwoDeal(BuildContext context, GameState game) {
    final playerOne = (roundTwoDealtCards + 1) ~/ 2;
    final playerTwo = roundTwoDealtCards ~/ 2;
    return Scaffold(
        appBar: AppBar(title: const Text('SECOND ROUND')),
        body: SafeArea(
            child: Container(
                color: const Color(0xff0d3128),
                padding: const EdgeInsets.all(18),
                child: Column(children: [
                  const Text('SECOND ROUND • DEALING ONE CARD AT A TIME',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('$roundTwoDealtCards of 20 cards distributed'),
                  Expanded(
                      child: Stack(children: [
                    Align(
                        alignment: Alignment.topCenter,
                        child: PlayerDealArea(
                            label: widget.controller.playerName(game.hostId),
                            cardCount: playerTwo)),
                    Center(child: DrawPile(count: 20 - roundTwoDealtCards)),
                    Align(
                        alignment: Alignment.bottomCenter,
                        child: PlayerDealArea(
                            label:
                                '${widget.controller.playerName(game.challengerId)} • OPENS ROUND 2',
                            cardCount: playerOne)),
                  ])),
                  const Text(
                      'The first-round opening player plays first again.',
                      style: TextStyle(
                          color: Colors.amber, fontWeight: FontWeight.bold)),
                ]))));
  }

  void _startScoreAnimation() {
    scoreTimer?.cancel();
    setState(() => scoreStage = 0);
    scoreTimer = Timer.periodic(const Duration(milliseconds: 850), (timer) {
      if (!mounted) return;
      if (scoreStage < 5) {
        setState(() => scoreStage++);
      } else {
        timer.cancel();
      }
    });
  }

  Widget _buildFinalScoring(GameState game) {
    final result = const ScoringRules().score(game.captured);
    return Scaffold(
        appBar: AppBar(title: const Text('GAME COMPLETE • POINT COUNT')),
        body: Container(
            width: double.infinity,
            color: const Color(0xff071713),
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Text('COUNTING THE FINAL POINTS',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Expanded(
                  child: Row(
                      children: game.players
                          .map((id) =>
                              Expanded(child: _scoreCard(game, result, id)))
                          .toList())),
              AnimatedScale(
                  duration: const Duration(milliseconds: 500),
                  scale: scoreStage >= 5 ? 1 : .7,
                  child: Opacity(
                      opacity: scoreStage >= 5 ? 1 : 0,
                      child: Column(children: [
                        const Text('WINNER',
                            style: TextStyle(
                                color: Colors.amber,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        Text(widget.controller.playerName(result.winnerId),
                            style: const TextStyle(
                                fontSize: 34, fontWeight: FontWeight.bold)),
                        Text('${result.points[result.winnerId]} TOTAL POINTS',
                            style: const TextStyle(fontSize: 18)),
                      ])))
            ])));
  }

  Widget _scoreCard(GameState game, ScoreResult result, String id) {
    final pack = game.captured[id]!;
    final breakdown = result.breakdowns[id]!;
    final realPoints = breakdown.aces + breakdown.spyTwo + breakdown.mummy;
    final spades =
        pack.where((card) => card.suit == CardSuit.blackSpade).length;
    Widget line(bool visible, String label, String value) => AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 400),
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label),
                  Text(value,
                      style: const TextStyle(fontWeight: FontWeight.bold))
                ])));
    return Card(
        margin: const EdgeInsets.all(10),
        child: Padding(
            padding: const EdgeInsets.all(18),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(widget.controller.playerName(id),
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const Divider(),
              line(scoreStage >= 1, 'Real-card points', '$realPoints'),
              line(scoreStage >= 2, 'Spades captured', '$spades'),
              line(scoreStage >= 2, 'Spade points', '${breakdown.mostSpades}'),
              line(scoreStage >= 3, 'Cards captured', '${pack.length}'),
              line(scoreStage >= 3, 'Card-count points',
                  '${breakdown.mostCards}'),
              const Divider(),
              line(scoreStage >= 4, 'TOTAL POINTS', '${breakdown.total}'),
            ])));
  }

  Future<void> _editNames(BuildContext context, GameState game) async {
    final one = TextEditingController(
        text: widget.controller.playerName(game.challengerId));
    final two =
        TextEditingController(text: widget.controller.playerName(game.hostId));
    await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
                title: const Text('Player names'),
                content: SizedBox(
                    width: 360,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: one,
                          decoration: const InputDecoration(
                              labelText: 'Player 1 name')),
                      const SizedBox(height: 12),
                      TextField(
                          controller: two,
                          decoration:
                              const InputDecoration(labelText: 'Player 2 name'))
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () {
                        widget.controller
                            .setDemoPlayerNames(one.text, two.text);
                        Navigator.pop(dialogContext);
                        setState(() {});
                      },
                      child: const Text('Save names'))
                ]));
  }

  void _selectNextOpponentCard(List<GameCard> pack) {
    if (selectedOpponentCards.length >= pack.length) return;
    setState(() => selectedOpponentCards
        .add(pack[pack.length - 1 - selectedOpponentCards.length]));
  }

  void act(VoidCallback fn) {
    try {
      final phaseBefore = widget.controller.game!.phase;
      fn();
      final phaseAfter = widget.controller.game!.phase;
      setState(() {
        selected = null;
        selectedOpponentCards.clear();
        selectedTable.clear();
        selectedBuilds.clear();
        notice = null;
      });
      if (phaseBefore == GamePhase.roundOne &&
          phaseAfter == GamePhase.roundTwo) {
        _startRoundTwoDeal();
      } else if (phaseAfter == GamePhase.finished) {
        _startScoreAnimation();
      }
    } on GameRuleException catch (e) {
      setState(() => notice = e.message);
    }
  }

  Future<void> showConstruct(BuildContext context, PlayerGameView view) async {
    final input = TextEditingController();
    await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Construct target'),
                content: TextField(
                    controller: input,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Target number')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        act(() => widget.controller.construct(selected!,
                            view.tableCards, int.tryParse(input.text) ?? 0));
                      },
                      child: const Text('Build with visible cards'))
                ]));
  }
}

class CardFace extends StatelessWidget {
  const CardFace({super.key, required this.card, this.small = false});
  final GameCard card;
  final bool small;
  @override
  Widget build(BuildContext context) => Container(
      width: small ? 48 : 68,
      height: small ? 68 : 100,
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black38)]),
      padding: const EdgeInsets.all(7),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(card.rankLabel,
            style: TextStyle(
                color: card.isRed ? Colors.red : Colors.black,
                fontSize: small ? 17 : 22,
                fontWeight: FontWeight.bold)),
        Expanded(
            child: Center(
                child: Text(card.suitSymbol,
                    style: TextStyle(
                        color: card.isRed ? Colors.red : Colors.black,
                        fontSize: small ? 22 : 32))))
      ]));
}

class CardBack extends StatelessWidget {
  const CardBack({super.key, this.width = 42, this.height = 60});
  final double width, height;
  @override
  Widget build(BuildContext context) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
          color: const Color(0xff9d1f2f),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: const Color(0xffffd76a), width: 2),
          boxShadow: const [
            BoxShadow(
                color: Colors.black45, blurRadius: 3, offset: Offset(1, 2))
          ]),
      child: Center(
          child: Container(
              width: width - 10,
              height: height - 10,
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.white70),
                  borderRadius: BorderRadius.circular(4)),
              child: const Icon(Icons.style, color: Color(0xffffd76a)))));
}

class PlayerDealArea extends StatelessWidget {
  const PlayerDealArea(
      {super.key, required this.label, required this.cardCount});
  final String label;
  final int cardCount;
  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$label — $cardCount / 10',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 7),
        SizedBox(
            height: 70,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < cardCount; i++)
                Align(
                    widthFactor: .34,
                    child: const CardBack(width: 42, height: 60))
            ]))
      ]);
}

class DrawPile extends StatelessWidget {
  const DrawPile({super.key, required this.count});
  final int count;
  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
            width: 62,
            height: 82,
            child: Stack(children: [
              for (var i = 0; i < (count > 4 ? 4 : count); i++)
                Positioned(
                    left: i * 2,
                    top: i * 2,
                    child: const CardBack(width: 52, height: 72))
            ])),
        Text('$count CARDS\nREMAINING',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))
      ]);
}

class BuildPile extends StatelessWidget {
  const BuildPile(
      {super.key,
      required this.tableBuild,
      required this.ownerName,
      required this.selected,
      required this.onTap});
  final TableBuild tableBuild;
  final String ownerName;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final cards = List<GameCard>.from(tableBuild.cards);
    // A simple build is one complete combination, so always render it high to
    // low even when an older in-memory game stored cards in selection order.
    if (!tableBuild.isStrong) {
      cards.sort((a, b) => b.rank.compareTo(a.rank));
    }
    final step = cards.length > 7 ? 15.0 : 22.0;
    final width = 52.0 + (cards.isEmpty ? 0 : (cards.length - 1) * step);
    return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: selected ? Colors.amber : Colors.white30,
                    width: selected ? 3 : 1)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(tableBuild.isStrong ? Icons.lock : Icons.construction,
                    size: 14,
                    color: tableBuild.isStrong
                        ? Colors.lightGreenAccent
                        : Colors.amber),
                const SizedBox(width: 4),
                Text(
                    '${tableBuild.isLocked ? 'LOCKED STRONG' : tableBuild.isStrong ? 'STRONG / COMPOUND' : 'SIMPLE'} ${tableBuild.target}',
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold))
              ]),
              SizedBox(
                  width: width,
                  height: 72,
                  child: Stack(children: [
                    for (var i = 0; i < cards.length; i++)
                      Positioned(
                          left: i * step,
                          child: CardFace(card: cards[i], small: true))
                  ])),
              Text('Built by $ownerName • base → top',
                  style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white70,
                      fontWeight: FontWeight.bold))
            ])));
  }
}

class CapturedPack extends StatelessWidget {
  const CapturedPack(
      {super.key,
      required this.label,
      required this.cards,
      this.topSelectable = false,
      this.selectedCount = 0,
      this.onTopTap,
      this.onUndo});
  final String label;
  final List<GameCard> cards;
  final bool topSelectable;
  final int selectedCount;
  final VoidCallback? onTopTap, onUndo;
  @override
  Widget build(BuildContext context) => Container(
      width: 108,
      height: double.infinity,
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.fromLTRB(5, 8, 5, 6),
      decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selectedCount > 0 ? Colors.amber : Colors.white24,
              width: selectedCount > 0 ? 3 : 1)),
      child: Column(children: [
        Text(label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
        Text('${cards.length}',
            style: const TextStyle(
                fontSize: 17,
                color: Color(0xffd4a72c),
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Expanded(
            child: cards.isEmpty
                ? Center(
                    child: Container(
                        width: 48,
                        height: 68,
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.white38),
                            borderRadius: BorderRadius.circular(7)),
                        child: const Icon(Icons.inventory_2_outlined,
                            color: Colors.white38)))
                : GestureDetector(
                    onTap: topSelectable ? onTopTap : null,
                    child: LayoutBuilder(builder: (context, constraints) {
                      final step = cards.length <= 1
                          ? 0.0
                          : ((constraints.maxHeight - 72) / (cards.length - 1))
                              .clamp(5.0, 15.0);
                      return Stack(alignment: Alignment.topCenter, children: [
                        for (var i = 0; i < cards.length; i++)
                          Positioned(
                              top: i * step,
                              child: Opacity(
                                  opacity: i >= cards.length - selectedCount
                                      ? 0.55
                                      : 1.0,
                                  child: CardFace(card: cards[i], small: true)))
                      ]);
                    }))),
        if (cards.isNotEmpty && topSelectable)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Expanded(
                child: Text(
                    selectedCount > 0
                        ? '$selectedCount TOP SELECTED\nTAP FOR NEXT'
                        : 'TAP TOP CARD',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 7,
                        color:
                            selectedCount > 0 ? Colors.amber : Colors.white60,
                        fontWeight: FontWeight.bold))),
            if (selectedCount > 0)
              InkWell(
                  onTap: onUndo,
                  child: const Icon(Icons.undo, size: 15, color: Colors.amber))
          ])
        else if (cards.isNotEmpty)
          const Text('LAST CHOW ON TOP',
              style: TextStyle(
                  fontSize: 7,
                  color: Colors.white60,
                  fontWeight: FontWeight.bold))
      ]));
}
