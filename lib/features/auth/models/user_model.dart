
import 'package:firebase_auth/firebase_auth.dart';


class UserModel {
  final String uid;
  final String email;
  final bool isPremium;
 final User? user;
  UserModel({required this.uid, required this.email, this.isPremium = false, required this.user});
}