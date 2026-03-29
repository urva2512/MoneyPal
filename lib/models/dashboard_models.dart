import 'package:cloud_firestore/cloud_firestore.dart';

class RoomBalanceSummary {
  final String roomId;
  final String roomName;
  final String roomCode;
  final List<String> members;
  final Map<String, double> memberBalances;
  final double totalToPay;
  final double totalToReceive;
  final List<GlobalActivityItem> activities;

  RoomBalanceSummary({
    required this.roomId,
    required this.roomName,
    required this.roomCode,
    required this.members,
    required this.memberBalances,
    required this.totalToPay,
    required this.totalToReceive,
    required this.activities,
  });

  double get netBalance => totalToReceive - totalToPay;
}

class FriendBalanceSummary {
  FriendBalanceSummary({
    required this.userId,
    required this.name,
    required this.netBalance,
    required Set<String> sharedGroups,
  }) : sharedGroups = sharedGroups;

  final String userId;
  String name;
  double netBalance;
  final Set<String> sharedGroups;
}

class GlobalActivityItem {
  GlobalActivityItem({
    required this.roomId,
    required this.roomName,
    required this.type,
    required this.title,
    required this.subtitleUserId,
    required this.otherUserId,
    required this.amount,
    required this.createdAt,
  });

  final String roomId;
  final String roomName;
  final String type;
  final String title;
  final String? subtitleUserId;
  final String? otherUserId;
  final double amount;
  final Timestamp? createdAt;
}

class DashboardSummary {
  DashboardSummary({
    required this.currentUserName,
    required this.currentUserEmail,
    required this.totalToPay,
    required this.totalToReceive,
    required this.rooms,
    required this.friends,
    required this.activities,
  });

  factory DashboardSummary.empty() {
    return DashboardSummary(
      currentUserName: 'You',
      currentUserEmail: '',
      totalToPay: 0,
      totalToReceive: 0,
      rooms: [],
      friends: [],
      activities: [],
    );
  }

  final String currentUserName;
  final String currentUserEmail;
  final double totalToPay;
  final double totalToReceive;
  final List<RoomBalanceSummary> rooms;
  final List<FriendBalanceSummary> friends;
  final List<GlobalActivityItem> activities;

  double get netBalance => totalToReceive - totalToPay;
}
