import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../design_system/ds.dart';
import '../viewmodel/auth_viewmodel.dart';
import '../viewmodel/auth_state.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authViewModelProvider);
    final vm    = ref.read(authViewModelProvider.notifier);

    return Scaffold(
      backgroundColor: SimtcColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SimtcSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/logo-simtc.png', height: 120),
              const SizedBox(height: SimtcSpacing.xxl),
              TextField(controller: _emailCtrl,    decoration: const InputDecoration(labelText: 'E-mail'), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: SimtcSpacing.md),
              TextField(controller: _passwordCtrl, decoration: const InputDecoration(labelText: 'Senha'), obscureText: true),
              const SizedBox(height: SimtcSpacing.xl),
              if (state is _Error)
                Padding(
                  padding: const EdgeInsets.only(bottom: SimtcSpacing.md),
                  child: Text((state as dynamic).message, style: SimtcTypography.body.copyWith(color: SimtcColors.noteM)),
                ),
              SimtcButton(
                label: 'Entrar',
                onPressed: () => vm.login(_emailCtrl.text.trim(), _passwordCtrl.text),
                isLoading: state is _Loading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
