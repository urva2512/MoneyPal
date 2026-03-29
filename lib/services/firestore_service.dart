import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class FirestoreService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final Map<String, String> _nameCache = {};

  String? get uid => _auth.currentUser?.uid;

  String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890';
    Random rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  Future<String> getUserName(String userId) async {
    if (_nameCache.containsKey(userId)) return _nameCache[userId]!;

    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (doc.exists) {
        final name = doc['name'] as String? ?? '';
        final email = doc['email'] as String? ?? '';
        final display = name.trim().isNotEmpty
            ? name.trim()
            : (email.isNotEmpty ? email.split('@').first : userId.substring(0, 6));
        _nameCache[userId] = display;
        return display;
      }
    } catch (_) {}

    final fallback = userId.length > 6 ? userId.substring(0, 6) : userId;
    _nameCache[userId] = fallback;
    return fallback;
  }

  Future<Map<String, String>> getUserNames(List<String> userIds) async {
    final results = await Future.wait(userIds.map((id) => getUserName(id)));
    return Map.fromIterables(userIds, results);
  }

  Future<void> createRoom(String name) async {
    if (uid == null) throw Exception('User not logged in');
    await _db.collection('rooms').add({
      'name': name,
      'code': _generateCode(),
      'createdBy': uid,
      'members': [uid],
    });
  }

  Future<void> joinRoom(String code) async {
    if (uid == null) throw Exception('User not logged in');
    final query = await _db
        .collection('rooms')
        .where('code', isEqualTo: code)
        .get();

    if (query.docs.isNotEmpty) {
      final room = query.docs.first;
      await room.reference.update({
        'members': FieldValue.arrayUnion([uid])
      });
    } else {
      throw Exception('Room not found');
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getUserRooms() {
    if (uid == null) throw Exception('User not logged in');
    return _db
        .collection('rooms')
        .where('members', arrayContains: uid)
        .snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getRoomData(String roomId) {
    return _db.collection('rooms').doc(roomId).get();
  }

  Future<void> addExpense(
      String roomId,
      double amount,
      String description,
      List<String> members,
      {required Map<String, double> splitAmounts, required String splitMode}) async {
    if (uid == null) throw Exception('User not logged in');
    await _db
        .collection('rooms')
        .doc(roomId)
        .collection('expenses')
        .add({
      'amount': amount,
      'description': description,
      'paidBy': uid,
      'splitBetween': members,
      'createdAt': Timestamp.now(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getExpenses(String roomId) {
    return _db
        .collection('rooms')
        .doc(roomId)
        .collection('expenses')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // FIXED: UI now tells the service exactly who is paying whom
  Future<void> settleUp({
    required String roomId,
    required String fromUserId,
    required String toUserId,
    required double amount,
  }) async {
    if (uid == null) throw Exception("User not logged in");

    await _db
        .collection('rooms')
        .doc(roomId)
        .collection('transaction')
        .add({
      'type': 'settlement',
      'from': fromUserId,
      'to': toUserId,
      'amount': amount,
      'createdAt': Timestamp.now(),
    });
  }

  Future<Map<String, dynamic>> getCurrentUserProfile() async {
    if (uid == null) throw Exception('User not logged in');
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data() ?? {};
  }
}
