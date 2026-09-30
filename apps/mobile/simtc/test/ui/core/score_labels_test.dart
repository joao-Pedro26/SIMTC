import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/score_labels.dart';

void main() {
  test('percentLabel usa uma casa e vírgula decimal', () {
    expect(percentLabel(86.6666), '86,7%');
    expect(percentLabel(100), '100,0%');
    expect(percentLabel(0), '0,0%');
  });
}
