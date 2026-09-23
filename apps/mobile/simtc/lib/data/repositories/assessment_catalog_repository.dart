import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../utils/result.dart';
import '../models/assessment_catalog.dart';
import '../services/api/api_client.dart';
import '../services/api/api_exception.dart';
import '../services/local/app_database.dart';

/// Catálogo de categorias, infrações e notas, guardado no aparelho.
///
/// O checklist da Fase 4 precisa funcionar sem sinal, então o catálogo tem de
/// estar no aparelho antes de o consultor chegar ao pátio. Ele desce junto com
/// cada atualização da Home (decisão de 23/09/2026) — uma chamada pequena, que
/// também traz para o app qualquer edição feita pelo admin no painel web.
class AssessmentCatalogRepository {
  AssessmentCatalogRepository({
    required ApiClient apiClient,
    required AppDatabase database,
    void Function(String message)? log,
  })  : _api = apiClient,
        _db = database,
        _log = log ?? _debugLog;

  final ApiClient _api;
  final AppDatabase _db;

  /// Não há tela do catálogo nesta fase — o log de debug é como se confere, no
  /// console do `flutter run`, que ele ficou no aparelho (inclusive offline).
  final void Function(String message) _log;

  static const String _path = '/assessment-categories';
  static const String _failed = 'Não foi possível atualizar o catálogo.';

  static void _debugLog(String message) {
    if (kDebugMode) debugPrint(message);
  }

  /// Baixa o catálogo inteiro e troca o do aparelho numa transação só.
  /// Devolve quantas categorias ficaram.
  Future<Result<int>> sync() async {
    try {
      final response = await _api.get<List<dynamic>>(_path);
      final data = response.data;
      final categories = data is List
          ? data
              .whereType<Map<String, dynamic>>()
              .map(CatalogCategory.fromJson)
              .toList(growable: false)
          : const <CatalogCategory>[];

      // Catálogo vazio não substitui o que está no aparelho: sem categorias
      // não há checklist, e uma resposta vazia é muito mais provável de ser
      // defeito (proxy, mudança de contrato) do que o admin ter apagado tudo.
      if (categories.isEmpty) {
        await _logSummary('Catálogo não atualizado (resposta vazia)');
        return Failure(Exception('catálogo vazio ou fora do formato'), _failed);
      }

      await _replace(categories);
      await _logSummary('Catálogo sincronizado');
      return Success(categories.length);
    } on ApiException catch (error) {
      await _logSummary('Catálogo não atualizado (${error.message})');
      return Failure(error, _failed);
    } catch (error) {
      await _logSummary('Catálogo não atualizado ($error)');
      return Failure(Exception('$error'), _failed);
    }
  }

  Future<void> _replace(List<CatalogCategory> categories) {
    return _db.transaction(() async {
      // Notas → infrações → categorias: as chaves estrangeiras apontam nessa
      // direção, e apagar na ordem inversa derrubaria a transação.
      await _db.delete(_db.infractionNotes).go();
      await _db.delete(_db.infractions).go();
      await _db.delete(_db.assessmentCategories).go();

      await _db.batch((batch) {
        for (final category in categories) {
          batch.insert(
            _db.assessmentCategories,
            AssessmentCategoriesCompanion.insert(
              id: category.id,
              code: category.code,
              name: category.name,
              description: Value(category.description),
              order: category.order,
            ),
          );
          for (final infraction in category.infractions) {
            batch.insert(
              _db.infractions,
              InfractionsCompanion.insert(
                id: infraction.id,
                categoryId: category.id,
                description: infraction.description,
                order: infraction.order,
              ),
            );
            for (final note in infraction.notes) {
              batch.insert(
                _db.infractionNotes,
                InfractionNotesCompanion.insert(
                  id: note.id,
                  infractionId: infraction.id,
                  noteType: note.noteType,
                  comment: Value(note.comment),
                  deduction: note.deduction,
                ),
              );
            }
          }
        }
      });
    });
  }

  /// O catálogo do aparelho, na ordem da ficha oficial — o que o checklist da
  /// Fase 4 percorre.
  Future<List<CatalogCategory>> loadCatalog() async {
    final categories = await (_db.select(_db.assessmentCategories)
          ..orderBy([(t) => OrderingTerm(expression: t.order)]))
        .get();
    final infractions = await (_db.select(_db.infractions)
          ..orderBy([(t) => OrderingTerm(expression: t.order)]))
        .get();
    final notes = await _db.select(_db.infractionNotes).get();

    return [
      for (final category in categories)
        CatalogCategory(
          id: category.id,
          code: category.code,
          name: category.name,
          description: category.description,
          order: category.order,
          infractions: [
            for (final infraction
                in infractions.where((i) => i.categoryId == category.id))
              CatalogInfraction(
                id: infraction.id,
                categoryId: category.id,
                description: infraction.description,
                order: infraction.order,
                notes: [
                  for (final note
                      in notes.where((n) => n.infractionId == infraction.id))
                    CatalogNote(
                      id: note.id,
                      infractionId: infraction.id,
                      noteType: note.noteType,
                      comment: note.comment,
                      deduction: note.deduction,
                    ),
                ],
              ),
          ],
        ),
    ];
  }

  Future<void> _logSummary(String prefix) async {
    try {
      final categories = await _db.assessmentCategories.count().getSingle();
      final infractions = await _db.infractions.count().getSingle();
      final notes = await _db.infractionNotes.count().getSingle();
      _log('$prefix. No aparelho: $categories categorias, '
          '$infractions infrações, $notes notas.');
    } catch (_) {
      // Log de conferência — nunca pode derrubar o sync.
    }
  }
}
