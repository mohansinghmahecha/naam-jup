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
    with SingleTickerProviderStateMixin {
  int selectedGodIndex = 0;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.9,
      upperBound: 1.0,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gods = ref.watch(godListProvider);

    if (gods.isEmpty) {
      return const Scaffold(body: Center(child: Text("No gods found.")));
    }

    final currentGod = gods[selectedGodIndex];

    // Progress circle loops every 108 taps (optional)
    final progress = (currentGod.sessionCount % 108) / 108;

    return Scaffold(
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
                  onTapDown: (_) => _controller.reverse(),
                  onTapUp: (_) {
                    _controller.forward();
                    ref
                        .read(godListProvider.notifier)
                        .incrementCount(currentGod.id);
                  },
                  onTapCancel: () => _controller.forward(),
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
                          valueColor: AlwaysStoppedAnimation<Color>(
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
                'Session: ${currentGod.sessionCount}',
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
