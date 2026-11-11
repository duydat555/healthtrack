import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../widgets/app_form.dart';
import 'auth_controller.dart';

/// Khung chung của màn đăng nhập và đăng ký.
class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.favorite, color: c.brand, size: 44),
                    const SizedBox(height: 16),
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: c.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 16, color: c.inkSoft),
                    ),
                    const SizedBox(height: 28),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).login(_email.text, _password.text);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Đăng nhập',
      subtitle: 'Theo dõi sức khỏe mỗi ngày cùng HealthTrack.',
      children: [
        Form(
          key: _form,
          child: Column(
            children: [
              AppTextField(
                controller: _email,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                validator: validateEmail,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _password,
                label: 'Mật khẩu',
                obscure: true,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Nhập mật khẩu' : null,
              ),
            ],
          ),
        ),
        ErrorText(_error),
        const SizedBox(height: 20),
        PrimaryButton(label: 'Đăng nhập', loading: _busy, onPressed: _submit),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _busy ? null : () => context.go('/register'),
          child: Text(
            'Chưa có tài khoản? Đăng ký',
            style: TextStyle(color: context.colors.brand, fontSize: 15),
          ),
        ),
      ],
    );
  }
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authProvider.notifier)
          .register(
            email: _email.text,
            password: _password.text,
            fullName: _name.text,
          );
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Tạo tài khoản',
      subtitle: 'Chỉ mất một phút để bắt đầu.',
      children: [
        Form(
          key: _form,
          child: Column(
            children: [
              AppTextField(
                controller: _name,
                label: 'Họ và tên',
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nhập họ và tên' : null,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _email,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                validator: validateEmail,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _password,
                label: 'Mật khẩu (từ 8 ký tự)',
                obscure: true,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                validator: (v) => (v == null || v.length < 8)
                    ? 'Mật khẩu tối thiểu 8 ký tự'
                    : null,
              ),
            ],
          ),
        ),
        ErrorText(_error),
        const SizedBox(height: 20),
        PrimaryButton(label: 'Đăng ký', loading: _busy, onPressed: _submit),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _busy ? null : () => context.go('/login'),
          child: Text(
            'Đã có tài khoản? Đăng nhập',
            style: TextStyle(color: context.colors.brand, fontSize: 15),
          ),
        ),
      ],
    );
  }
}

/// Màn chờ khi đang khôi phục phiên đăng nhập lúc mở app.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.background,
    body: Center(child: CircularProgressIndicator(color: context.colors.brand)),
  );
}
