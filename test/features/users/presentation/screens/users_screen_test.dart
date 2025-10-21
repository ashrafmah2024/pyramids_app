import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:pyramids/features/users/domain/entities/user.dart';
import 'package:pyramids/features/users/domain/entities/user_role.dart';
import 'package:pyramids/features/users/domain/entities/user_status.dart';
import 'package:pyramids/features/users/domain/repositories/user_repository.dart';
import 'package:pyramids/features/users/presentation/providers/user_provider.dart';
import 'package:pyramids/features/users/presentation/screens/users_screen.dart';

class MockUserRepository extends Mock implements UserRepository {}

void main() {
  late MockUserRepository mockUserRepository;
  late UserProvider userProvider;

  final testUsers = [
    User(
      id: '1',
      fullName: 'Test User 1',
      username: 'testuser1',
      email: 'test1@example.com',
      role: UserRole.admin,
      status: UserStatus.active,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    User(
      id: '2',
      fullName: 'Test User 2',
      username: 'testuser2',
      email: 'test2@example.com',
      role: UserRole.manager,
      status: UserStatus.active,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  setUp(() {
    mockUserRepository = MockUserRepository();
    userProvider = UserProvider(userRepository: mockUserRepository);
  });

  Widget createTestWidget(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<UserProvider>.value(value: userProvider),
      ],
      child: MaterialApp(
        home: child,
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
      ),
    );
  }

  testWidgets('UsersScreen shows loading indicator when loading', 
    (WidgetTester tester) async {
      // Arrange
      when(mockUserRepository.getUsers()).thenAnswer((_) async => []);
      
      // Act
      await tester.pumpWidget(createTestWidget(const UsersScreen()));
      
      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets('UsersScreen shows error message when there is an error', 
    (WidgetTester tester) async {
      // Arrange
      when(mockUserRepository.getUsers()).thenThrow(Exception('Test error'));
      
      // Act
      await tester.pumpWidget(createTestWidget(const UsersScreen()));
      await tester.pump(); // Wait for the first frame
      
      // Assert
      expect(find.text('حدث خطأ: Exception: Test error'), findsOneWidget);
    },
  );

  testWidgets('UsersScreen shows list of users when loaded successfully', 
    (WidgetTester tester) async {
      // Arrange
      when(mockUserRepository.getUsers()).thenAnswer((_) async => testUsers);
      
      // Act
      await tester.pumpWidget(createTestWidget(const UsersScreen()));
      await tester.pump(); // Wait for the first frame
      
      // Assert
      expect(find.text('Test User 1'), findsOneWidget);
      expect(find.text('Test User 2'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsNWidgets(2));
      expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
    },
  );

  testWidgets('Tapping on add user button shows user form', 
    (WidgetTester tester) async {
      // Arrange
      when(mockUserRepository.getUsers()).thenAnswer((_) async => []);
      
      // Act
      await tester.pumpWidget(createTestWidget(const UsersScreen()));
      await tester.pump(); // Wait for the first frame
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      
      // Assert
      expect(find.text('إضافة مستخدم جديد'), findsOneWidget);
    },
  );
}
