import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/dashboard_models.dart';
import '../expenses/add_expense_screen.dart';
import '../../services/auth_service.dart';
import '../../services/dashboard_repository.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';
import 'join_room_screen.dart';
import 'room_screen.dart';

class MyGroupsScreen extends StatefulWidget {
  const MyGroupsScreen({super.key});

  @override
  State<MyGroupsScreen> createState() => _MyGroupsScreenState();
}

class _MyGroupsScreenState extends State<MyGroupsScreen> {
  final service = FirestoreService();
  late final DashboardRepository dashboardRepository;
  final auth = AuthService();

  late Future<DashboardSummary> _dashboardFuture;
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    dashboardRepository = DashboardRepository(service: service);
    _reloadDashboard();
  }

  void _reloadDashboard() {
    _dashboardFuture = dashboardRepository.fetchDashboardSummary();
  }

  Future<void> _refresh() async {
    setState(_reloadDashboard);
    try {
      await _dashboardFuture;
    } catch (_) {}
  }

  Future<void> _openCreateOrJoin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const JoinRoomScreen()),
    );
    if (mounted) {
      setState(_reloadDashboard);
    }
  }

  Future<void> _openRoom(String roomId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RoomScreen(roomId: roomId)),
    );
    if (mounted) {
      setState(_reloadDashboard);
    }
  }

  Future<void> _openAddExpense(DashboardSummary dashboard) async {
    if (dashboard.rooms.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create or join a group first')),
      );
      return;
    }

    final selectedRoom = await showModalBottomSheet<RoomBalanceSummary>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.72,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Expense To',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Choose the group this expense belongs to.',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: dashboard.rooms.map((room) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            onTap: () => Navigator.pop(context, room),
                            tileColor: AppColors.card,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: const BorderSide(color: AppColors.border),
                            ),
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.greenSoft,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.groups_rounded,
                                color: AppColors.green,
                              ),
                            ),
                            title: Text(
                              room.roomName,
                              style: const TextStyle(
                                color: AppColors.text,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${room.members.length} members | Code ${room.roomCode}',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textFaint,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selectedRoom == null || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(roomId: selectedRoom.roomId),
      ),
    );

    if (mounted) {
      setState(_reloadDashboard);
    }
  }

  String _money(double amount) => 'Rs ${amount.abs().toStringAsFixed(2)}';

  Color _balanceColor(double amount) {
    if (amount > 0) return AppColors.green;
    if (amount < 0) return AppColors.danger;
    return AppColors.textMuted;
  }

  String _balanceLabel(double amount) {
    if (amount > 0) return '+ ${_money(amount)}';
    if (amount < 0) return '- ${_money(amount)}';
    return _money(0);
  }

  String _relativeLabel(double amount) {
    if (amount > 0) return 'owes you';
    if (amount < 0) return 'you owe';
    return 'all settled';
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

  Future<void> _copyGroupCode(String code) async {
    if (code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Group code $code copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: FutureBuilder<DashboardSummary>(
          future: _dashboardFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _buildEmptyCard(
                    title: 'Unable to load your dashboard',
                    subtitle: 'Pull to refresh and try again.',
                    icon: Icons.refresh_rounded,
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.green),
              );
            }

            final dashboard = snapshot.data!;
            return Column(
              children: [
                _buildHeader(dashboard),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    color: AppColors.green,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                      children: [
                        if (_navIndex == 0) _buildHomeTab(dashboard),
                        if (_navIndex == 1) _buildGroupsTab(dashboard),
                        if (_navIndex == 3) _buildFriendsTab(dashboard),
                        if (_navIndex == 4) _buildProfileTab(dashboard),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FutureBuilder<DashboardSummary>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          final dashboard = snapshot.data;
          return FloatingActionButton.extended(
            onPressed: dashboard == null ? null : () => _openAddExpense(dashboard),
            icon: const Icon(Icons.receipt_long_rounded),
            label: const Text('Add Expense'),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader(DashboardSummary dashboard) {
    final subtitle = switch (_navIndex) {
      0 => 'Overall balance and recent activity',
      1 => 'Every group with live net balances',
      3 => 'Friends across all shared groups',
      4 => 'Your account and quick stats',
      _ => 'Shared balances made simple',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: AppColors.green,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, ${dashboard.currentUserName.split(' ').first}',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async => auth.signOut(),
            icon: const Icon(Icons.logout_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.card,
              foregroundColor: AppColors.textMuted,
              side: const BorderSide(color: AppColors.border),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab(DashboardSummary dashboard) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildOverviewHero(dashboard),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                label: 'To receive',
                value: _money(dashboard.totalToReceive),
                color: AppColors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                label: 'To pay',
                value: _money(dashboard.totalToPay),
                color: AppColors.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSectionTitle(
          'Top Groups',
          action: dashboard.rooms.isNotEmpty ? 'View all' : null,
          onAction: () => setState(() => _navIndex = 1),
        ),
        const SizedBox(height: 12),
        if (dashboard.rooms.isEmpty)
          _buildEmptyCard(
            title: 'No groups yet',
            subtitle: 'Create your first group to start splitting expenses.',
            icon: Icons.groups_outlined,
          )
        else
          ...dashboard.rooms.take(3).map(_buildGroupTile),
        const SizedBox(height: 24),
        _buildSectionTitle(
          'Recent Activity',
          action: dashboard.activities.isNotEmpty ? 'Friends' : null,
          onAction: () => setState(() => _navIndex = 3),
        ),
        const SizedBox(height: 12),
        if (dashboard.activities.isEmpty)
          _buildEmptyCard(
            title: 'Nothing yet',
            subtitle: 'Expenses and settlements will show up here.',
            icon: Icons.receipt_long_outlined,
          )
        else
          ...dashboard.activities.take(8).map(
                (item) => _buildActivityTile(item, dashboard),
              ),
      ],
    );
  }

  Widget _buildGroupsTab(DashboardSummary dashboard) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Your Groups',
          action: '+ New Group',
          onAction: _openCreateOrJoin,
        ),
        const SizedBox(height: 12),
        if (dashboard.rooms.isEmpty)
          _buildEmptyCard(
            title: 'No groups yet',
            subtitle: 'Create or join a group to start tracking balances.',
            icon: Icons.group_add_outlined,
          )
        else
          ...dashboard.rooms.map(_buildGroupTile),
      ],
    );
  }

  Widget _buildFriendsTab(DashboardSummary dashboard) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Friends'),
        const SizedBox(height: 6),
        const Text(
          'Everyone you share at least one group with appears here automatically.',
          style: TextStyle(color: AppColors.textMuted, height: 1.5),
        ),
        const SizedBox(height: 14),
        if (dashboard.friends.isEmpty)
          _buildEmptyCard(
            title: 'No friends yet',
            subtitle: 'Join a group with someone and they will appear here.',
            icon: Icons.people_outline_rounded,
          )
        else
          ...dashboard.friends.map(_buildFriendTile),
      ],
    );
  }

  Widget _buildProfileTab(DashboardSummary dashboard) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.cardSoft, AppColors.bg],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  dashboard.currentUserName.isEmpty
                      ? 'Y'
                      : dashboard.currentUserName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.green,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                dashboard.currentUserName,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (dashboard.currentUserEmail.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  dashboard.currentUserEmail,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _statChip('${dashboard.rooms.length} groups'),
                  _statChip('${dashboard.friends.length} friends'),
                  _statChip('${dashboard.activities.length} recent updates'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                label: 'Overall net',
                value: _balanceLabel(dashboard.netBalance),
                color: _balanceColor(dashboard.netBalance),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                label: 'Shared with',
                value: '${dashboard.friends.length} people',
                color: AppColors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverviewHero(DashboardSummary dashboard) {
    final net = dashboard.netBalance;
    final label = net >= 0 ? 'Overall you should receive' : 'Overall you need to pay';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.cardSoft, AppColors.bg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.greenGlow,
            blurRadius: 26,
            spreadRadius: -18,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Home',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _money(net),
            style: TextStyle(
              color: _balanceColor(net),
              fontSize: 36,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '${dashboard.rooms.length} groups | ${dashboard.friends.length} friends',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(
    String title, {
    String? action,
    VoidCallback? onAction,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            child: Text(action),
          ),
      ],
    );
  }

  Widget _buildEmptyCard({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.green),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupTile(RoomBalanceSummary room) {
    final double balance = room.netBalance;

    return GestureDetector(
      onTap: () => _openRoom(room.roomId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.greenSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.groups_rounded, color: AppColors.green),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.roomName,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${room.members.length} members | Code ${room.roomCode}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _balanceLabel(balance),
                  style: TextStyle(
                    color: _balanceColor(balance),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  balance >= 0 ? 'net credit' : 'net due',
                  style: const TextStyle(
                    color: AppColors.textFaint,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed:
                      room.roomCode.isEmpty ? null : () => _copyGroupCode(room.roomCode),
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: const Text('Copy code'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.green,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendTile(FriendBalanceSummary friend) {
    final balance = friend.netBalance;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(
              friend.name.isEmpty ? '?' : friend.name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: AppColors.green,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.name,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${friend.sharedGroups.length} shared group${friend.sharedGroups.length == 1 ? '' : 's'} | ${_relativeLabel(balance)}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  friend.sharedGroups.take(3).join(', '),
                  style: const TextStyle(
                    color: AppColors.textFaint,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _balanceLabel(balance),
            style: TextStyle(
              color: _balanceColor(balance),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTile(GlobalActivityItem item, DashboardSummary dashboard) {
    String subtitle;
    if (item.type == 'settlement') {
      final from = dashboard.friends
          .where((friend) => friend.userId == item.subtitleUserId)
          .map((friend) => friend.name)
          .firstOrNull;
      final to = dashboard.friends
          .where((friend) => friend.userId == item.otherUserId)
          .map((friend) => friend.name)
          .firstOrNull;
      subtitle = '${from ?? 'You'} paid ${to ?? (item.otherUserId == service.uid ? 'you' : 'them')}';
    } else {
      final payer = dashboard.friends
          .where((friend) => friend.userId == item.subtitleUserId)
          .map((friend) => friend.name)
          .firstOrNull;
      subtitle = '${payer ?? 'You'} | ${item.roomName}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              item.type == 'settlement'
                  ? Icons.compare_arrows_rounded
                  : Icons.receipt_long_rounded,
              color: AppColors.green,
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
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
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
            _money(item.amount),
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      {'icon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.groups_rounded, 'label': 'Groups'},
      {'icon': Icons.add, 'label': 'Add'},
      {'icon': Icons.people_alt_outlined, 'label': 'Friends'},
      {'icon': Icons.person_outline_rounded, 'label': 'Profile'},
    ];

    return Container(
      height: 74,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          if (index == 2) return const SizedBox(width: 80);

          final selected = _navIndex == index;
          return GestureDetector(
            onTap: () => setState(() => _navIndex = index),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  item['icon'] as IconData,
                  color: selected ? AppColors.green : AppColors.textFaint,
                ),
                const SizedBox(height: 4),
                Text(
                  item['label'] as String,
                  style: TextStyle(
                    color: selected ? AppColors.green : AppColors.textFaint,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
