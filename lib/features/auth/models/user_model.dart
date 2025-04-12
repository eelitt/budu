
class UserModel {
  final String uid;
  final String email;
  final bool isPremium;

  UserModel({required this.uid, required this.email, this.isPremium = false});
}