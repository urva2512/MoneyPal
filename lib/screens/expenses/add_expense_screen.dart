import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';

enum SplitMode { equal, uneven }

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key, required this.roomId});

  final String roomId;

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final service = FirestoreService();
  final descController = TextEditingController();
  final amountController = TextEditingController();

  bool _saving = false;
  bool _loadingMembers = true;
  String? _error;
  SplitMode _splitMode = SplitMode.equal;

  List<Map<String, String>> _members = [];
  Set<String> _selectedMembers = {};
  final Map<String, TextEditingController> _splitControllers = {};

  static const bg = AppColors.bg;
  static const card = AppColors.card;
  static const cardAlt = AppColors.cardSoft;
  static const accent = AppColors.green;
  static const textMuted = AppColors.textMuted;
  static const border = AppColors.border;

  String? get _currentUserId => service.uid;

  double get _amount => double.tryParse(amountController.text.trim()) ?? 0;

  @override
  void initState() {
    super.initState();
    _loadMembers();
    amountController.addListener(_handleAmountChanged);
  }

  @override
  void dispose() {
    descController.dispose();
    amountController
      ..removeListener(_handleAmountChanged)
      ..dispose();
    for (final controller in _splitControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMembers() async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).get();
      if (!doc.exists) {
        if (!mounted) return;
        setState(() {
          _error = 'Room not found';
          _loadingMembers = false;
        });
        return;
      }

      final currentUserId = _currentUserId;
      final roomMemberIds = List<String>.from(doc['members'] ?? []);
      final memberIds = <String>{
        ...roomMemberIds,
        if (currentUserId != null) currentUserId,
      }.toList();
      final names = await service.getUserNames(memberIds);

      for (final id in memberIds) {
        _splitControllers[id] ??= TextEditingController();
      }

      if (!mounted) return;
      setState(() {
        _members = memberIds
            .map((id) => {'uid': id, 'name': names[id] ?? id})
            .toList()
          ..sort((a, b) {
            if (a['uid'] == currentUserId) return -1;
            if (b['uid'] == currentUserId) return 1;
            return (a['name'] ?? '').compareTo(b['name'] ?? '');
          });
        _selectedMembers = memberIds.toSet();
        _loadingMembers = false;
      });

      _distributeUnevenShares(force: true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMembers = false;
        _error = 'Unable to load members right now';
      });
    }
  }

  void _handleAmountChanged() {
    if (_splitMode == SplitMode.equal) {
      setState(() {});
      return;
    }

    _distributeUnevenShares(force: false);
  }

  void _setSplitMode(SplitMode mode) {
    if (_splitMode == mode) return;

    setState(() => _splitMode = mode);
    if (mode == SplitMode.uneven) {
      _distributeUnevenShares(force: true);
    }
  }

  void _toggleMember(String memberId, bool selected) {
    final currentUserId = _currentUserId;
    if (memberId == currentUserId) return;

    setState(() {
      if (selected) {
        _selectedMembers.add(memberId);
      } else {
        _selectedMembers.remove(memberId);
      }
    });

    if (_splitMode == SplitMode.uneven) {
      _distributeUnevenShares(force: true);
    }
  }

  void _distributeUnevenShares({required bool force}) {
    if (_selectedMembers.isEmpty) return;

    final total = _amount;
    if (total <= 0) {
      if (force) {
        for (final memberId in _selectedMembers) {
          _splitControllers[memberId]?.text = '';
        }
      }
      if (mounted) setState(() {});
      return;
    }

    final currentlyFilled = _selectedMembers.every((memberId) {
      final value = double.tryParse(_splitControllers[memberId]?.text.trim() ?? '');
      return value != null && value > 0;
    });

    if (!force && currentlyFilled && (_unevenTotal - total).abs() <= 0.01) {
      if (mounted) setState(() {});
      return;
    }

    final count = _selectedMembers.length;
    final baseShare = count == 0 ? 0 : total / count;
    double assigned = 0;
    final selectedIds = _members
        .map((member) => member['uid']!)
        .where(_selectedMembers.contains)
        .toList();

    for (var index = 0; index < selectedIds.length; index++) {
      final memberId = selectedIds[index];
      final value = index == selectedIds.length - 1 ? total - assigned : baseShare;
      final rounded = double.parse(value.toStringAsFixed(2));
      assigned += rounded;
      _splitControllers[memberId]?.text = rounded.toStringAsFixed(2);
    }

    if (mounted) setState(() {});
  }

  double get _equalShare {
    if (_selectedMembers.isEmpty || _amount <= 0) {
      return 0;
    }
    return _amount / _selectedMembers.length;
  }

  double get _unevenTotal {
    var sum = 0.0;
    for (final memberId in _selectedMembers) {
      sum += double.tryParse(_splitControllers[memberId]?.text.trim() ?? '') ?? 0;
    }
    return sum;
  }

  Map<String, double> _buildSplitAmounts() {
    if (_splitMode == SplitMode.equal) {
      return {
        for (final memberId in _selectedMembers)
          memberId: double.parse(_equalShare.toStringAsFixed(2)),
      };
    }

    return {
      for (final memberId in _selectedMembers)
        memberId: double.parse(
          ((double.tryParse(_splitControllers[memberId]?.text.trim() ?? '') ?? 0))
              .toStringAsFixed(2),
        ),
    };
  }

  Future<void> _save() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      setState(() => _error = 'Please login again');
      return;
    }

    _selectedMembers.add(currentUserId);

    if (_amount <= 0) {
      setState(() => _error = 'Enter an amount greater than Rs 0');
      return;
    }

    if (_selectedMembers.isEmpty) {
      setState(() => _error = 'Select at least one person to split with');
      return;
    }

    if (_splitMode == SplitMode.uneven) {
      final total = double.parse(_unevenTotal.toStringAsFixed(2));
      final amount = double.parse(_amount.toStringAsFixed(2));
      if ((total - amount).abs() > 0.01) {
        setState(() => _error = 'Uneven shares must add up to the total amount');
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await service.addExpense(
        widget.roomId,
        _amount,
        descController.text.trim().isEmpty ? 'Expense' : descController.text.trim(),
        _selectedMembers.toList(),
        splitAmounts: _buildSplitAmounts(),
        splitMode: _splitMode.name,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (_) {
      setState(() => _error = 'Failed to save the expense. Try again.');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'Add Expense',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _save,
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        color: accent,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'What did you pay for?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: descController,
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                            decoration: _inputDecoration('Dinner, rent, groceries...'),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Amount',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: amountController,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                            ),
                            decoration: _inputDecoration('0.00', prefixText: 'Rs '),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _sectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Split Style',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                _splitMode == SplitMode.equal
                                    ? 'Everyone pays equally'
                                    : 'Set a custom amount for each person',
                                style: const TextStyle(
                                  color: textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _modeChip(
                                  label: 'Equal',
                                  selected: _splitMode == SplitMode.equal,
                                  onTap: () => _setSplitMode(SplitMode.equal),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _modeChip(
                                  label: 'Uneven',
                                  selected: _splitMode == SplitMode.uneven,
                                  onTap: () => _setSplitMode(SplitMode.uneven),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _sectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Split With',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (_splitMode == SplitMode.uneven)
                                TextButton(
                                  onPressed: () => _distributeUnevenShares(force: true),
                                  child: const Text(
                                    'Auto-fill',
                                    style: TextStyle(color: accent),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'You are always included in the split because you paid for the expense.',
                            style: TextStyle(color: textMuted, fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                          if (_loadingMembers)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(18),
                                child: CircularProgressIndicator(color: accent),
                              ),
                            )
                          else
                            ..._members.map(_buildMemberRow),
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
                    const SizedBox(height: 16),
                    _summaryCard(),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: bg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: bg,
                                ),
                              )
                            : const Text(
                                'Save Expense',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }

  Widget _modeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? accent : cardAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? accent : border),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? bg : Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildMemberRow(Map<String, String> member) {
    final memberId = member['uid']!;
    final isMe = memberId == _currentUserId;
    final isSelected = _selectedMembers.contains(memberId);
    final displayName = isMe ? 'You' : (member['name'] ?? memberId);
    final initial =
        displayName.isEmpty ? '?' : displayName.substring(0, 1).toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? accent.withOpacity(0.35) : border,
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: isMe ? accent.withOpacity(0.18) : Colors.white.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: TextStyle(
                color: isMe ? accent : Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _splitMode == SplitMode.equal
                      ? (isSelected ? 'Rs ${_equalShare.toStringAsFixed(2)}' : 'Excluded')
                      : (isSelected
                          ? 'Custom share'
                          : 'Excluded from this expense'),
                  style: const TextStyle(color: textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (_splitMode == SplitMode.uneven && isSelected)
            SizedBox(
              width: 96,
              child: TextField(
                controller: _splitControllers[memberId],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                enabled: isSelected,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.right,
                decoration: _inputDecoration('0.00', prefixText: 'Rs '),
              ),
            )
          else
            Switch(
              value: isSelected,
              onChanged: isMe ? null : (value) => _toggleMember(memberId, value),
              activeColor: bg,
              activeTrackColor: accent,
              inactiveThumbColor: Colors.white70,
              inactiveTrackColor: Colors.white.withOpacity(0.15),
            ),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    final currentUserIncluded =
        _currentUserId != null && _selectedMembers.contains(_currentUserId);
    final helperText = _splitMode == SplitMode.equal
        ? 'Rs ${_equalShare.toStringAsFixed(2)} per selected person'
        : 'Rs ${_unevenTotal.toStringAsFixed(2)} assigned of Rs ${_amount.toStringAsFixed(2)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.cardSoft, AppColors.bg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            helperText,
            style: const TextStyle(color: textMuted, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            currentUserIncluded
                ? 'Your share is included in the split.'
                : 'You will be added back to the split when saving.',
            style: const TextStyle(color: accent, fontSize: 13),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, {String? prefixText}) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefixText,
      prefixStyle: const TextStyle(color: textMuted, fontSize: 18),
      hintStyle: const TextStyle(color: textMuted),
      filled: true,
      fillColor: cardAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: accent),
      ),
    );
  }
}
