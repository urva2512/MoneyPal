import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/dashboard_models.dart';
import 'firestore_service.dart';
import 'room_balance_calculator.dart';

class DashboardRepository {
  DashboardRepository({FirestoreService? service})
      : _service = service ?? FirestoreService();

  final FirestoreService _service;

  Future<List<RoomBalanceSummary>> fetchUserRoomSummaries() async {
    final currentUserId = _service.uid;
    if (currentUserId == null) return [];

    final roomQuery = await _service.getUserRooms().first;
    final summaries = <RoomBalanceSummary>[];

    for (final room in roomQuery.docs) {
      final roomData = room.data() as Map<String, dynamic>;
      final roomRef = room.reference;
      final expenses = await roomRef
          .collection('expenses')
          .orderBy('createdAt', descending: true)
          .get();
      final settlements = await roomRef
          .collection('transaction')
          .orderBy('createdAt', descending: true)
          .get();

      summaries.add(
        calculateRoomSummary(
          currentUserId: currentUserId, // 🔥 ADD THIS LINE
          roomId: room.id,
          roomName: roomData['name'] as String? ?? 'Group',
          roomCode: roomData['code'] as String? ?? '',
          members: (roomData['members'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList(),
          expenses: List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
            expenses.docs,
          ),
          settlements: List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
            settlements.docs,
          ),
        ),
      );
    }

    summaries.sort((a, b) => a.roomName.compareTo(b.roomName));
    return summaries;
  }

  Future<DashboardSummary> fetchDashboardSummary() async {
    final currentUserId = _service.uid;
    if (currentUserId == null) {
      return DashboardSummary.empty();
    }

    final profile = await _service.getCurrentUserProfile();
    final roomSummaries = await fetchUserRoomSummaries();

    final friendMap = <String, FriendBalanceSummary>{};
    final allUserIds = <String>{currentUserId};
    final allActivities = <GlobalActivityItem>[];
    var totalToPay = 0.0;
    var totalToReceive = 0.0;

    for (final room in roomSummaries) {
      totalToPay += room.totalToPay;
      totalToReceive += room.totalToReceive;
      allActivities.addAll(room.activities);

      for (final memberId in room.members) {
        if (memberId == currentUserId) continue;
        allUserIds.add(memberId);

        final existing = friendMap[memberId];
        final balance = room.memberBalances[memberId] ?? 0;
        if (existing == null) {
          friendMap[memberId] = FriendBalanceSummary(
            userId: memberId,
            name: '',
            netBalance: balance,
            sharedGroups: {room.roomName},
          );
        } else {
          existing.netBalance += balance;
          existing.sharedGroups.add(room.roomName);
        }
      }
    }

    final names = await _service.getUserNames(allUserIds.toList());

    for (final friend in friendMap.values) {
      friend.name = names[friend.userId] ?? friend.userId;
      friend.netBalance = double.parse(friend.netBalance.toStringAsFixed(2));
    }

    allActivities.sort((a, b) {
      final aMillis = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bMillis = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bMillis.compareTo(aMillis);
    });

    return DashboardSummary(
      currentUserName: (profile['name'] as String?)?.trim().isNotEmpty == true
          ? (profile['name'] as String).trim()
          : (names[currentUserId] ?? 'You'),
      currentUserEmail: profile['email'] as String? ?? '',
      totalToPay: double.parse(totalToPay.toStringAsFixed(2)),
      totalToReceive: double.parse(totalToReceive.toStringAsFixed(2)),
      rooms: roomSummaries,
      friends: friendMap.values.toList()
        ..sort((a, b) => b.netBalance.abs().compareTo(a.netBalance.abs())),
      activities: allActivities.take(20).toList(),
    );
  }
}
