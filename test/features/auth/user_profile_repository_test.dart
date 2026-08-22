import 'package:budu/features/auth/data/user_profile_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ensureUserDocument creates once and does not overwrite', () async {
    final fake = FakeFirebaseFirestore();
    final repo = UserProfileRepository(firestore: fake);

    await repo.ensureUserDocument(uid: 'u1', email: 'a@b.c');
    await repo.mergeProfile('u1', {'isAdmin': true});
    await repo.ensureUserDocument(uid: 'u1', email: 'other@b.c');

    final profile = await repo.getProfile('u1');
    expect(profile!.email, 'a@b.c');
    expect(profile.isAdmin, isTrue);
    expect(profile.isPremium, isFalse);
  });

  test('getProfile returns null when missing', () async {
    final fake = FakeFirebaseFirestore();
    final repo = UserProfileRepository(firestore: fake);
    expect(await repo.getProfile('missing'), isNull);
  });
}
