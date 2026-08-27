import 'package:budu/features/auth/data/auth_repository.dart';
import 'package:budu/features/auth/data/user_profile_repository.dart';
import 'package:budu/features/auth/domain/auth_errors.dart';
import 'package:budu/features/auth/models/user_model.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(auth: null, googleSignIn: null);

  UserModel? currentUser;
  Object? currentUserError;
  UserModel? signInResult;
  Object? signInError;
  Object? signOutError;
  int signOutCalls = 0;

  @override
  Future<UserModel?> getCurrentUser() async {
    if (currentUserError != null) throw currentUserError!;
    return currentUser;
  }

  @override
  Future<UserModel?> signInWithGoogle() async {
    if (signInError != null) throw signInError!;
    return signInResult;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (signOutError != null) throw signOutError!;
  }
}

UserModel _user({String uid = 'u1', String email = 'a@b.c'}) =>
    UserModel(uid: uid, email: email, user: null);

void main() {
  late _FakeAuthRepository authRepo;
  late UserProfileRepository profiles;
  late AuthProvider provider;
  late int notifyCount;

  setUp(() {
    authRepo = _FakeAuthRepository();
    profiles = UserProfileRepository(firestore: FakeFirebaseFirestore());
    provider = AuthProvider(
      authRepository: authRepo,
      userProfileRepository: profiles,
    );
    notifyCount = 0;
    provider.addListener(() => notifyCount++);
  });

  test('initialize with current user -> authenticated and notifies', () async {
    authRepo.currentUser = _user();

    await provider.initialize();

    expect(provider.isInitialized, isTrue);
    expect(provider.authState, AuthState.authenticated);
    expect(provider.user?.uid, 'u1');
    expect(notifyCount, greaterThanOrEqualTo(2));
  });

  test('initialize with no current user -> unauthenticated and notifies',
      () async {
    authRepo.currentUser = null;

    await provider.initialize();

    expect(provider.isInitialized, isTrue);
    expect(provider.authState, AuthState.unauthenticated);
    expect(provider.user, isNull);
    expect(notifyCount, greaterThanOrEqualTo(2));
  });

  test('initialize failure -> unauthenticated, initialized, and rethrows',
      () async {
    authRepo.currentUserError = const AuthFailure(
      kind: AuthErrorKind.currentUser,
      message: 'Failed to get current user',
    );

    await expectLater(
      provider.initialize(),
      throwsA(isA<AuthFailure>()),
    );
    expect(provider.isInitialized, isTrue);
    expect(provider.authState, AuthState.unauthenticated);
    expect(provider.user, isNull);
  });

  test('signInWithGoogle success ensures profile and authenticates', () async {
    authRepo.signInResult = _user(uid: 'u2', email: 'new@b.c');

    await provider.signInWithGoogle();

    expect(provider.authState, AuthState.authenticated);
    expect(provider.user?.uid, 'u2');
    final profile = await profiles.getProfile('u2');
    expect(profile?.email, 'new@b.c');
    expect(notifyCount, greaterThanOrEqualTo(2));
  });

  test('signInWithGoogle cancellation -> unauthenticated without throw',
      () async {
    authRepo.signInResult = null;

    await provider.signInWithGoogle();

    expect(provider.authState, AuthState.unauthenticated);
    expect(provider.user, isNull);
    expect(notifyCount, greaterThanOrEqualTo(2));
  });

  test('signInWithGoogle failure -> unauthenticated and rethrows AuthFailure',
      () async {
    authRepo.signInError = const AuthFailure(
      kind: AuthErrorKind.signIn,
      message: 'Google Sign-In failed',
      code: 'network-request-failed',
    );

    await expectLater(
      provider.signInWithGoogle(),
      throwsA(
        isA<AuthFailure>()
            .having((e) => e.kind, 'kind', AuthErrorKind.signIn)
            .having((e) => e.code, 'code', 'network-request-failed'),
      ),
    );
    expect(provider.authState, AuthState.unauthenticated);
    expect(provider.user, isNull);
  });

  test(
      'signInWithGoogle profile failure -> unauthenticated and rethrows',
      () async {
    authRepo.signInResult = _user(uid: 'u3', email: 'x@y.z');
    final throwingProfiles = _ThrowingProfileRepository();
    provider = AuthProvider(
      authRepository: authRepo,
      userProfileRepository: throwingProfiles,
    );
    notifyCount = 0;
    provider.addListener(() => notifyCount++);

    await expectLater(
      provider.signInWithGoogle(),
      throwsA(
        isA<AuthFailure>().having(
          (e) => e.kind,
          'kind',
          AuthErrorKind.profileEnsure,
        ),
      ),
    );
    expect(provider.authState, AuthState.unauthenticated);
    expect(provider.user, isNull);
    expect(notifyCount, greaterThanOrEqualTo(2));
  });

  test('signOut -> unauthenticated and notifies', () async {
    authRepo.currentUser = _user();
    await provider.initialize();
    notifyCount = 0;

    await provider.signOut();

    expect(authRepo.signOutCalls, 1);
    expect(provider.authState, AuthState.unauthenticated);
    expect(provider.user, isNull);
    expect(notifyCount, greaterThanOrEqualTo(2));
  });
}

class _ThrowingProfileRepository extends UserProfileRepository {
  _ThrowingProfileRepository() : super(firestore: FakeFirebaseFirestore());

  @override
  Future<void> ensureUserDocument({
    required String uid,
    required String email,
  }) async {
    throw const AuthFailure(
      kind: AuthErrorKind.profileEnsure,
      message: 'Failed to create user document',
    );
  }
}
