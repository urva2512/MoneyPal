import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final codeController = TextEditingController();
  final nameController = TextEditingController();
  final service = FirestoreService();

  bool _joining = false;
  bool _creating = false;
  String? _error;

  @override
  void dispose() {
    codeController.dispose();
    nameController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (codeController.text.trim().isEmpty) return;
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      await service.joinRoom(codeController.text.trim().toUpperCase());
      if (mounted) Navigator.pop(context);
    } catch (_) {
      setState(() => _error = 'Room not found. Check the code and try again.');
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _create() async {
    if (nameController.text.trim().isEmpty) return;
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      await service.createRoom(nameController.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (_) {
      setState(() => _error = 'Failed to create group. Try again.');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.card,
                  foregroundColor: AppColors.text,
                  side: const BorderSide(color: AppColors.border),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Groups',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Join an existing group with a code or create a new one for shared expenses.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              _panel(
                icon: Icons.key_rounded,
                title: 'Join a group',
                subtitle: 'Enter the 6-character room code shared by a member.',
                child: Column(
                  children: [
                    TextField(
                      controller: codeController,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 6,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4,
                      ),
                      decoration: const InputDecoration(
                        counterText: '',
                        hintText: 'ABC123',
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _joining ? null : _join,
                        child: _joining
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Text('Join Group'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _panel(
                icon: Icons.group_add_rounded,
                title: 'Create a group',
                subtitle: 'Start a fresh group for a trip, home, event, or office spend.',
                child: Column(
                  children: [
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: AppColors.text),
                      decoration: const InputDecoration(
                        hintText: 'Weekend Trip',
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _creating ? null : _create,
                        child: _creating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Text('Create Group'),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.dangerSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.danger.withOpacity(0.5)),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _panel({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.green),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}
