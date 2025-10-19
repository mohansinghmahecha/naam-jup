// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/god_provider.dart';
import '../models/god.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with TickerProviderStateMixin {
  late AnimationController _tapController;
  late AnimationController _resetController;
  late Animation<double> _scaleAnimation;

  bool isResetting = false;
  double animatedProgress = 0.0;
  int selectedGodIndex = 0;

  @override
  void initState() {
    super.initState();

    // 👆 Tap scale animation
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnimation = _tapController.drive(Tween(begin: 1.0, end: 0.95));

    // 🔄 Reset animation controller
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..addListener(() {
      setState(() {
        animatedProgress = 1.0 - _resetController.value;
      });
    });
  }

  @override
  void dispose() {
    _tapController.dispose();
    _resetController.dispose();
    super.dispose();
  }

  // 🧩 Handle Tap
  void _onTap(God currentGod) {
    if (isResetting) return;

    _tapController.reverse().then((_) => _tapController.forward());
    ref.read(godListProvider.notifier).incrementCount(currentGod.id);

    final progress =
        currentGod.sessionCount >= 108 ? 1.0 : currentGod.sessionCount / 108.0;

    setState(() {
      animatedProgress = progress;
    });

    // Auto reset when reaches 108
    if (currentGod.sessionCount + 1 >= 108) {
      Future.delayed(const Duration(milliseconds: 250), () {
        _animateReset(currentGod.id);
      });
    }
  }

  // ✅ Reset animation & stop cleanly
  void _animateReset(String godId) {
    if (isResetting) return;
    isResetting = true;

    _resetController.reset();
    _resetController.forward().whenComplete(() async {
      // After animation → reset session count only
      final notifier = ref.read(godListProvider.notifier);
      final gods =
          notifier.state.map((god) {
            if (god.id == godId) {
              return God(
                id: god.id,
                name: god.name,
                sessionCount: 0,
                totalCount: god.totalCount,
              );
            }
            return god;
          }).toList();

      notifier.state = gods;
      await Future.delayed(const Duration(milliseconds: 100));

      setState(() {
        animatedProgress = 0.0;
        isResetting = false;
      });

      _resetController.stop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final gods = ref.watch(godListProvider);
    if (gods.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentGod = gods[selectedGodIndex];
    final progress =
        isResetting
            ? animatedProgress
            : (currentGod.sessionCount % 108) / 108.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ---------- GOD NAME ----------
              GestureDetector(
                onTap: () => _showGodSelectionDialog(context, ref, gods),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    currentGod.name,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // ---------- TAP BUTTON WITH ANIMATION ----------
              ScaleTransition(
                scale: _scaleAnimation,
                child: GestureDetector(
                  onTapDown: (_) => _tapController.reverse(),
                  onTapUp: (_) {
                    _tapController.forward();
                    _onTap(currentGod);
                  },
                  onTapCancel: () => _tapController.forward(),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Circular progress
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 12,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.indigo,
                          ),
                        ),
                      ),

                      // Main button
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: Colors.indigo.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.indigo.withOpacity(0.4),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.touch_app,
                          color: Colors.white,
                          size: 60,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // ---------- COUNTERS ----------
              Text(
                'Session: ${currentGod.sessionCount % 108}',
                style: const TextStyle(fontSize: 18),
              ),
              Text(
                'Total: ${currentGod.totalCount}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),

      // ---------- ADD NEW GOD ----------
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddGodDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  // ================= DIALOGS =================

  void _showGodSelectionDialog(
    BuildContext context,
    WidgetRef ref,
    List<God> gods,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Select or Rename God'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: gods.length,
                itemBuilder: (context, index) {
                  final god = gods[index];
                  return ListTile(
                    title: Text(god.name),
                    onTap: () {
                      setState(() => selectedGodIndex = index);
                      Navigator.pop(context);
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () {
                        Navigator.pop(context);
                        _showRenameDialog(context, ref, god);
                      },
                    ),
                  );
                },
              ),
            ),
          ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref, God god) {
    final controller = TextEditingController(text: god.name);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Rename God'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'Enter new name'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = controller.text.trim();
                  if (name.isNotEmpty) {
                    ref.read(godListProvider.notifier).renameGod(god.id, name);
                  }
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  void _showAddGodDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add God'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'Enter name'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = controller.text.trim();
                  if (name.isNotEmpty) {
                    ref.read(godListProvider.notifier).addGod(name);
                    Navigator.pop(context);
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }
}
