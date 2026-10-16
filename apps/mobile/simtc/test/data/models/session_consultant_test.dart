import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/data/models/session_consultant.dart';

void main() {
  Map<String, dynamic> link(String id, String name, {Object? email}) {
    return {
      'trainingSessionId': 'sess-1',
      'consultantId': id,
      'consultant': {'id': id, 'name': name, 'email': email},
    };
  }

  group('SessionConsultant.listFromJson', () {
    test('lê os consultores de consultants[].consultant, na ordem em que vêm',
        () {
      final list = SessionConsultant.listFromJson({
        'responsibleConsultantId': 'c-1',
        'consultants': [
          link('c-2', 'Rafael Lima', email: 'rafael@sim.com'),
          link('c-1', 'Carla Mendes', email: 'carla@sim.com'),
        ],
      });

      expect(list, const [
        SessionConsultant(id: 'c-2', name: 'Rafael Lima', email: 'rafael@sim.com'),
        SessionConsultant(id: 'c-1', name: 'Carla Mendes', email: 'carla@sim.com'),
      ]);
    });

    test('sem a lista de consultores, devolve nulo — e não uma lista vazia', () {
      expect(SessionConsultant.listFromJson({'id': 'sess-1'}), isNull);
      expect(
        SessionConsultant.listFromJson({'consultants': 'quebrado'}),
        isNull,
      );
      expect(SessionConsultant.listFromJson({'consultants': <dynamic>[]}), isEmpty);
    });

    test('o responsável entra mesmo sem o vínculo dele na lista', () {
      final list = SessionConsultant.listFromJson({
        'responsibleConsultantId': 'c-1',
        'responsibleConsultant': {
          'id': 'c-1',
          'name': 'Carla Mendes',
          'email': 'carla@sim.com',
        },
        'consultants': [link('c-2', 'Rafael Lima')],
      });

      expect(list!.map((c) => c.id), ['c-2', 'c-1']);
    });

    test('o responsável que já está na lista não entra duas vezes', () {
      final list = SessionConsultant.listFromJson({
        'responsibleConsultant': {'id': 'c-1', 'name': 'Carla Mendes'},
        'consultants': [
          link('c-1', 'Carla Mendes', email: 'carla@sim.com'),
          link('c-1', 'Carla Mendes', email: 'carla@sim.com'),
        ],
      });

      expect(list, const [
        SessionConsultant(id: 'c-1', name: 'Carla Mendes', email: 'carla@sim.com'),
      ]);
    });

    test('ignora o que vier sem id ou sem nome; e-mail em branco vira nulo', () {
      final list = SessionConsultant.listFromJson({
        'consultants': [
          link('', 'Sem Id'),
          link('c-3', '   '),
          {'consultantId': 'c-4'},
          'lixo',
          link('c-5', '  Tatiane Souza ', email: '   '),
          link('c-6', 'Diego Barbosa', email: 42),
        ],
      });

      expect(list, const [
        SessionConsultant(id: 'c-5', name: 'Tatiane Souza'),
        SessionConsultant(id: 'c-6', name: 'Diego Barbosa'),
      ]);
    });
  });
}
