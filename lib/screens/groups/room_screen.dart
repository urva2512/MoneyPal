import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/firestore_service.dart';
import '../../services/room_balance_calculator.dart';
import '../../theme/app_colors.dart';
import '../expenses/add_expense_screen.dart';
import 'settle_up_screen.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key, required this.roomId});

  final String roomId;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final service = FirestoreService();
  Map<String, String> _names = {};

  static const bg = AppColors.bg;
  static const card = AppColors.card;
  static const cardAlt = AppColors.cardSoft;
  static const accent = AppColors.green;
  static const border = AppColors.border;
  static const muted = AppColors.textMuted;
  static const danger = AppColors.danger;

  @override
  void initState() {
    super.initState();
    _loadRoomMemberNames();
  }

  Future<void> _loadRoomMemberNames() async {
    final doc = await service.getRoomData(widget.roomId);
    final data = doc.data() ?? <String, dynamic>{};
    final members = List<String>.from(data['members'] ?? const []);
    final names = await service.getUserNames(members);
    if (mounted) {
      setState(() => _names = names);
    }
  }

  String _nameFor(String uid) {
    if (uid == service.uid) return 'You';
    return _names[uid] ?? uid.substring(0, uid.length < 6 ? uid.length : 6);
  }

  Future<void> _copyGroupCode(String code) async {
    if (code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Group code $code copied')),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final sameDay = dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
    final time = TimeOfDay.fromDateTime(dateTime).format(context);
    if (sameDay) return 'Today, $time';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dateTime.day} ${months[dateTime.month - 1]}, $time';
  }

  List<_ActivityItem> _buildActivityItems({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> expenses,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> settlements,
  }) {
    final items = <_ActivityItem>[];

    for (final expense in expenses) {
      final data = expense.data();
      final amount = (data['amount'] as num?)?.toDouble() ?? 0;
      items.add(
        _ActivityItem(
          title: data['description'] as String? ?? 'Expense',
          subtitle: '${_nameFor(data['paidBy'] as String? ?? '')} paid',
          amountLabel: 'Rs ${amount.toStringAsFixed(2)}',
          createdAt: data['createdAt'] as Timestamp?,
          positive: true,
        ),
      );
    }

    for (final settlement in settlements) {
      final data = settlement.data();
      final amount = (data['amount'] as num?)?.toDouble() ?? 0;
      final from = data['from'] as String? ?? '';
      final to = data['to'] as String? ?? '';
      items.add(
        _ActivityItem(
          title: 'Settlement',
          subtitle: '${_nameFor(from)} paid ${_nameFor(to)}',
          amountLabel: 'Rs ${amount.toStringAsFixed(2)}',
          createdAt: data['createdAt'] as Timestamp?,
          positive: from != service.uid,
        ),
      );
    }

    items.sort((a, b) {
      final aMillis = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bMillis = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bMillis.compareTo(aMillis);
    });

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .snapshots(),
          builder: (context, roomSnapshot) {
            if (!roomSnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: accent),
              );
            }

            final roomData = roomSnapshot.data!.data() ?? <String, dynamic>{};
            final roomName = roomData['name'] as String? ?? 'Group';
            final roomCode = roomData['code'] as String? ?? '';
            final members = List<String>.from(roomData['members'] ?? const []);

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('rooms')
                  .doc(widget.roomId)
                  .collection('expenses')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, expenseSnapshot) {
                if (!expenseSnapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: accent),
                  );
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('rooms')
                      .doc(widget.roomId)
                      .collection('transaction')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, settlementSnapshot) {
                    if (!settlementSnapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: accent),
                      );
                    }

                    final expenses = expenseSnapshot.data!.docs;
                    final settlements = settlementSnapshot.data!.docs;
                    final summary = calculateRoomSummary(
                      currentUserId: service.uid ?? '',
                      roomId: widget.roomId,
                      roomName: roomName,
                      roomCode: roomCode,
                      members: members,
                      expenses: expenses,
                      settlements: settlements,
                    );
                    final recentActivity = _buildActivityItems(
                      expenses: expenses,
                      settlements: settlements,
                    );

                    return Column(
                      children: [
                        _buildHeader(
                          roomName: roomName,
                          roomCode: roomCode,
                          memberCount: members.length,
                        ),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _loadRoomMemberNames,
                            color: accent,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                              children: [
                                _buildHeroCard(
                                  roomName: roomName,
                                  netBalance: summary.netBalance,
                                  totalToReceive: summary.totalToReceive,
                                  totalToPay: summary.totalToPay,
                                ),
                                const SizedBox(height: 18),
                                _buildBalancesCard(summary.memberBalances),
                                const SizedBox(height: 18),
                                _buildActivityCard(recentActivity),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: accent,
        foregroundColor: bg,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddExpenseScreen(roomId: widget.roomId),
          ),
        ).then((_) => _loadRoomMemberNames()),
        label: const Text(
          'Add Expense',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        icon: const Icon(Icons.add, size: 18),
      ),
    );
  }

  Widget _buildHeader({
    required String roomName,
    required String roomCode,
    required int memberCount,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roomName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$memberCount members',
                  style: const TextStyle(color: muted, fontSize: 13),
                ),
              ],
            ),
          ),
          if (roomCode.isNotEmpty)
            IconButton(
              onPressed: () => _copyGroupCode(roomCode),
              icon: const Icon(Icons.copy_rounded, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: card,
                side: const BorderSide(color: border),
              ),
              tooltip: 'Copy group code',
            ),
        ],
      ),
    );
  }

  Widget _buildHeroCard({
    required String roomName,
    required double netBalance,
    required double totalToReceive,
    required double totalToPay,
  }) {
    final positive = netBalance >= 0;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.cardSoft, AppColors.bg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            roomName,
            style: const TextStyle(color: muted, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            positive ? 'You should receive' : 'You need to pay',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Rs ${netBalance.abs().toStringAsFixed(2)}',
            style: TextStyle(
              color: positive ? accent : danger,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildStatTile(
                  label: 'To receive',
                  value: 'Rs ${totalToReceive.toStringAsFixed(2)}',
                  valueColor: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatTile(
                  label: 'To pay',
                  value: 'Rs ${totalToPay.toStringAsFixed(2)}',
                  valueColor: danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalancesCard(Map<String, double> memberBalances) {
    final sortedEntries = memberBalances.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Balances',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Positive means they owe you. Negative means you owe them.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (sortedEntries.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardAlt,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'Everything is settled in this group.',
                style: TextStyle(color: muted),
              ),
            )
          else
            ...sortedEntries.map(
              (entry) => _buildBalanceRow(entry.key, entry.value),
            ),
        ],
      ),
    );
  }

  Widget _buildBalanceRow(String memberId, double balance) {
    final userWillPay = balance < 0;
    final displayName = _nameFor(memberId);
    final title = userWillPay
        ? 'You owe $displayName'
        : '$displayName owes you';
    final initial =
        displayName.isEmpty ? '?' : displayName.substring(0, 1).toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
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
                  title,
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Rs ${balance.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  color: userWillPay ? danger : accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SettleUpScreen(
                        roomId: widget.roomId,
                        counterpartyId: memberId,
                        counterpartyName: _nameFor(memberId),
                        maxAmount: balance.abs(),
                        userWillPay: userWillPay,
                      ),
                    ),
                  );
                },
                child: const Text(
                  'Settle',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(List<_ActivityItem> items) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Text(
              'No expenses or settlements yet.',
              style: TextStyle(color: muted),
            )
          else
            ...items.take(12).map(
              (item) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardAlt,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        item.title == 'Settlement'
                            ? Icons.compare_arrows_rounded
                            : Icons.receipt_long_outlined,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.subtitle,
                            style: const TextStyle(
                              color: muted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatTimestamp(item.createdAt),
                            style: const TextStyle(
                              color: AppColors.textFaint,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      item.amountLabel,
                      style: TextStyle(
                        color: item.positive ? accent : danger,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityItem {
  const _ActivityItem({
    required this.title,
    required this.subtitle,
    required this.amountLabel,
    required this.createdAt,
    required this.positive,
  });

  final String title;
  final String subtitle;
  final String amountLabel;
  final Timestamp? createdAt;
  final bool positive;
}
