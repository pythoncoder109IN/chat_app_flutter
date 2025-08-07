import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class BaseRepository {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  User? get currentuser => auth.currentUser;
  String get uid => currentuser?.uid ?? "";
  bool get isAuthenticated => currentuser != null;
}
