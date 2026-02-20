import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/app_user.dart';
import '../../repositories/user_repository.dart';
import '../../services/auth_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final UserRepository _repo = UserRepository();
  List<AppUser> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final users = await _repo.getAllUsers();
    if (!mounted) return;
    setState(() {
      _users = users;
      _isLoading = false;
    });
  }

  Future<void> _deleteUser(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to delete this user?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _repo.deleteUser(
        id,
        executorId: AuthService.instance.currentUser?.id,
      );
      _loadUsers();
    }
  }

  void _showUserDialog([AppUser? user]) {
    showDialog(
      context: context,
      builder: (context) => _UserDialog(
        user: user,
        onSave: (newUser) async {
          final currentUserId = AuthService.instance.currentUser?.id;
          debugPrint(
            "DEBUG: UserManagementScreen - Executor ID: $currentUserId",
          );
          if (user == null) {
            await _repo.createUser(newUser, executorId: currentUserId);
          } else {
            await _repo.updateUser(newUser, executorId: currentUserId);
          }
          _loadUsers();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("User Management")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                final isMe =
                    user.username == AuthService.instance.currentUser?.username;
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(user.username[0].toUpperCase()),
                  ),
                  title: Text(user.username),
                  subtitle: Text(
                    "${user.role} • ${user.permissions.length} perms",
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showUserDialog(user),
                      ),
                      if (!isMe) // Prevent deleting self
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteUser(user.id),
                        ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUserDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _UserDialog extends StatefulWidget {
  final AppUser? user;
  final Function(AppUser) onSave;

  const _UserDialog({this.user, required this.onSave});

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameCtrl;
  late TextEditingController _passwordCtrl;
  String _role = 'staff';

  // Available permissions
  final Map<String, String> _allPermissions = {
    'orders': 'Manage Orders',
    'products_view': 'View Products',
    'products_edit': 'Edit Products',
    'customers_view': 'View Customers',
    'suppliers_view': 'View Suppliers',
    'reports_view': 'View Reports',
    'backup': 'Backup & Restore',
    'all': 'Full Access (Admin)',
  };

  final Set<String> _selectedPermissions = {};

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: widget.user?.username ?? '');
    _passwordCtrl = TextEditingController(
      text: widget.user?.passwordHash ?? '',
    );
    _role = widget.user?.role ?? 'staff';
    if (widget.user != null) {
      _selectedPermissions.addAll(widget.user!.permissions);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.user == null ? "Add User" : "Edit User"),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _usernameCtrl,
                  decoration: const InputDecoration(labelText: "Username"),
                  validator: (v) => v!.isEmpty ? "Required" : null,
                ),
                TextFormField(
                  controller: _passwordCtrl,
                  decoration: const InputDecoration(labelText: "Password"),
                  validator: (v) => v!.isEmpty ? "Required" : null,
                ),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: "Role"),
                  items: const [
                    DropdownMenuItem(value: 'staff', child: Text("Staff")),
                    DropdownMenuItem(
                      value: 'developer',
                      child: Text("Developer/Admin"),
                    ),
                  ],
                  onChanged: (val) => setState(() => _role = val!),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Permissions",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Divider(),
                ..._allPermissions.entries.map((e) {
                  return CheckboxListTile(
                    title: Text(e.value),
                    value: _selectedPermissions.contains(e.key),
                    dense: true,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedPermissions.add(e.key);
                        } else {
                          _selectedPermissions.remove(e.key);
                        }
                      });
                    },
                  );
                }),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final newUser = AppUser(
                id: widget.user?.id ?? const Uuid().v4(),
                username: _usernameCtrl.text,
                passwordHash: _passwordCtrl.text,
                role: _role,
                permissions: _selectedPermissions.toList(),
                createdAt: widget.user?.createdAt ?? DateTime.now(),
              );
              widget.onSave(newUser);
              Navigator.pop(context);
            }
          },
          child: const Text("Save"),
        ),
      ],
    );
  }
}
