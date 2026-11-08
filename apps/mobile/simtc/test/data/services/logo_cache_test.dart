import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/data/services/device_data_service.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('logo_cache_test');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  LogoCache cacheEm(Directory pasta) =>
      LogoCache(temporaryDirectory: () async => pasta);

  test('sem a subpasta, são 0 bytes', () async {
    expect(await cacheEm(temp).sizeInBytes(), 0);
  });

  test('soma os arquivos, inclusive os das subpastas, e ignora as pastas',
      () async {
    final pasta = Directory('${temp.path}/${DefaultCacheManager.key}');
    await pasta.create(recursive: true);
    await File('${pasta.path}/a.bin').writeAsBytes(List.filled(3, 0));
    await File('${pasta.path}/b.bin').writeAsBytes(List.filled(5, 0));
    final sub = Directory('${pasta.path}/sub');
    await sub.create();
    await File('${sub.path}/c.bin').writeAsBytes(List.filled(7, 0));

    expect(await cacheEm(temp).sizeInBytes(), 15);
  });
}
