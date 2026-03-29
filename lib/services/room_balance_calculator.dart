import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/dashboard_models.dart';

double shareForExpense(Map<String, dynamic> expense, String memberId) {
  final splitMode = expense['splitMode'] as String? ?? 'equal';
  final amount = (expense['amount'] as num?)?.toDouble() ?? 0;
  final splitBetween = (expense['splitBetween'] as List<dynamic>? ?? [])
    .map((e) => e.toString())
    .toList();

  if (splitMode == 'uneven') {
    final splitAmounts = Map<String, dynamic>.from(
      expense['splitAmounts'] ?? const <String, dynamic>{},
    );
    final value = splitAmounts[memberId];
    if (value is num) {
      return value.toDouble();
    }
  }

  if (splitBetween.isEmpty) return amount;
  return amount / splitBetween.length;
}

RoomBalanceSummary calculateRoomSummary({
  required String currentUserId,
  required String roomId,
  required String roomName,
  required String roomCode,
  required List<String> members,
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> expenses,
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> settlements,
}) {
  final memberBalances = <String, double>{};

// ✅ ADD THIS BELOW
for (final m in members) {
  memberBalances[m] = 0.0;
}
  final activities = <GlobalActivityItem>[];

  _applyExpenseBalances(
    currentUserId: currentUserId,
    expenses: expenses,
    memberBalances: memberBalances,
    activities: activities,
    roomId: roomId,
    roomName: roomName,
  );

  _applySettlementBalances(
    currentUserId: currentUserId,
    settlements: settlements,
    memberBalances: memberBalances,
    activities: activities,
    roomId: roomId,
    roomName: roomName,
  );

  memberBalances.updateAll((key, value) => _roundCurrency(value));
  memberBalances.removeWhere((_, value) => value == 0);

  var totalToPay = 0.0;
  var totalToReceive = 0.0;
  for (final balance in memberBalances.values) {
    if (balance >= 0) {
      totalToReceive += balance;
    } else {
      totalToPay += balance.abs();
    }
  }

  return RoomBalanceSummary(
    roomId: roomId,
    roomName: roomName,
    roomCode: roomCode,
    members: members,
    memberBalances: memberBalances,
    totalToPay: _roundCurrency(totalToPay),
    totalToReceive: _roundCurrency(totalToReceive),
    activities: activities,
  );
}

double _roundCurrency(double value) {
  return double.parse(value.toStringAsFixed(2));
}

void _applyExpenseBalances({
  required String currentUserId,
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> expenses,
  required Map<String, double> memberBalances,
  required List<GlobalActivityItem> activities,
  required String roomId,
  required String roomName,
}) {
  for (final expenseDoc in expenses) {
    final expense = expenseDoc.data();
    final paidBy = expense['paidBy'] as String?;
    final splitBetween = (expense['splitBetween'] as List<dynamic>? ?? [])
    .map((e) => e.toString())
    .toList();

    if (paidBy == null || splitBetween.isEmpty) continue;

    if (paidBy == currentUserId) {
      for (final memberId in splitBetween) {
        if (memberId == currentUserId) continue;
        memberBalances[memberId] =
            (memberBalances[memberId] ?? 0) + shareForExpense(expense, memberId);
      }
    } else if (splitBetween.contains(currentUserId)) {
      memberBalances[paidBy] =
          (memberBalances[paidBy] ?? 0) - shareForExpense(expense, currentUserId);
    }

    activities.add(
      GlobalActivityItem(
        roomId: roomId,
        roomName: roomName,
        type: 'expense',
        title: expense['description'] as String? ?? 'Expense',
        subtitleUserId: paidBy,
        otherUserId: null,
        amount: (expense['amount'] as num?)?.toDouble() ?? 0,
        createdAt: expense['createdAt'] as Timestamp?,
      ),
    );
  }
}

void _applySettlementBalances({
  required String currentUserId,
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> settlements,
  required Map<String, double> memberBalances,
  required List<GlobalActivityItem> activities,
  required String roomId,
  required String roomName,
}) {
  for (final settlementDoc in settlements) {
    final settlement = settlementDoc.data();
    if (settlement['type'] != 'settlement') continue;

    final from = settlement['from'] as String?;
    final to = settlement['to'] as String?;
    final amount = (settlement['amount'] as num?)?.toDouble() ?? 0;

    if (from == null || to == null || amount <= 0) continue;

    if (from == currentUserId) {
      memberBalances[to] = (memberBalances[to] ?? 0) + amount;
    } else if (to == currentUserId) {
      memberBalances[from] = (memberBalances[from] ?? 0) - amount;
    }

    activities.add(
      GlobalActivityItem(
        roomId: roomId,
        roomName: roomName,
        type: 'settlement',
        title: 'Settlement',
        subtitleUserId: from,
        otherUserId: to,
        amount: amount,
        createdAt: settlement['createdAt'] as Timestamp?,
      ),
    );
  }
}
