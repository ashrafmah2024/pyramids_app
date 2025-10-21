import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pyramids/features/users/presentation/providers/user_provider.dart';

class TestUsersScreen extends StatefulWidget {
  const TestUsersScreen({super.key});

  @override
  State<TestUsersScreen> createState() => _TestUsersScreenState();
}

class _TestUsersScreenState extends State<TestUsersScreen> {
  @override
  void initState() {
    super.initState();
    // Load users when the screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().loadUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختبار اتصال قاعدة البيانات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => userProvider.loadUsers(),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: userProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : userProvider.error != null
                        ? Center(
                            child: Text(
                              'حدث خطأ: ${userProvider.error}',
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            itemCount: userProvider.users.length,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              final user = userProvider.users[index];
                              return ListTile(
                                title: Text(user.fullName),
                                subtitle: Text(user.email),
                                trailing: Text(user.role.toString().split('.').last),
                              );
                            },
                          ),
              ),
            );
          },
        ),
      ),
    );
  }

}
