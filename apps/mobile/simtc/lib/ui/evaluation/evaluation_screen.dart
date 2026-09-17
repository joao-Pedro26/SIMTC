import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../data/models/evaluation_model.dart';
import '../../utils/app_colors.dart';
import '../core/widgets/custom_button.dart';
import '../core/widgets/custom_text_field.dart';
import 'evaluation_viewmodel.dart';

class EvaluationScreen extends StatefulWidget {
  final EvaluationModel? evaluation;

  const EvaluationScreen({super.key, this.evaluation});

  @override
  State<EvaluationScreen> createState() => _EvaluationScreenState();
}

class _EvaluationScreenState extends State<EvaluationScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final vm = context.read<EvaluationViewModel>();
    vm.initFromModel(widget.evaluation);
    _titleController.text = vm.title;
    _descController.text = vm.description;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<EvaluationViewModel>();
    final isEditing = widget.evaluation != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Detalhes da Avaliação' : 'Nova Avaliação'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomTextField(
              label: 'Título do Treinamento',
              hint: 'Ex: Operação Prática de Veículos',
              controller: _titleController,
              onChanged: viewModel.setTitle,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Descrição / Observações',
              hint: 'Descreva os aspectos avaliados e feedback...',
              maxLines: 4,
              controller: _descController,
              onChanged: viewModel.setDescription,
            ),
            const SizedBox(height: 24),
            Text(
              'Nota do Treinamento: ${viewModel.score.toStringAsFixed(1)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Slider(
              value: viewModel.score,
              min: 0.0,
              max: 10.0,
              divisions: 20,
              activeColor: AppColors.primary,
              inactiveColor: AppColors.border,
              label: viewModel.score.toStringAsFixed(1),
              onChanged: viewModel.setScore,
            ),
            if (viewModel.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                viewModel.errorMessage!,
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 32),
            CustomButton(
              label: isEditing ? 'Voltar' : 'Salvar Avaliação',
              isLoading: viewModel.isSaving,
              onPressed: () async {
                if (isEditing) {
                  context.pop();
                  return;
                }
                final success = await viewModel.saveEvaluation();
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Avaliação salva com sucesso!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  context.pop();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
