import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vector_map_tiles/src/cache/byte_storage.dart';
import 'package:vector_map_tiles/src/cache/storage_cache.dart';
import 'package:vector_map_tiles/src/raster/storage_image_cache.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';

void main() {
  final theme = ThemeReader().read({
    'version': 8,
    'id': 'a-theme',
    'sources': {
      'openmaptiles': {'type': 'vector'}
    },
    'layers': [],
  });
  final cache = StorageImageCache(
      theme, StorageCache(_NoStorage(), const Duration(days: 1), 0), 2.0);
  final tile = TileIdentity(14, 8612, 5543);

  test('upright tiles keep the file name they always had', () {
    expect(cache.keyOf(tile), '${cache.themeKey}-14-8612-5543.png');
    expect(cache.keyOf(tile, labelRotation: 0),
        '${cache.themeKey}-14-8612-5543.png');
  });

  test('each label rotation gets its own file', () {
    final turned = cache.keyOf(tile, labelRotation: 180);

    expect(turned, '${cache.themeKey}-14-8612-5543-r180.0.png');
    expect(turned, isNot(cache.keyOf(tile, labelRotation: 135)));
    expect(turned, isNot(cache.keyOf(tile)));
  });
}

class _NoStorage extends ByteStorage {
  @override
  Future<Uint8List?> read(String key) async => null;

  @override
  Future<void> write(String key, Uint8List bytes) async {}

  @override
  Future<bool> exists(String key) async => false;

  @override
  Future<void> delete(String key) async {}

  @override
  Future<List<ByteStorageEntry>> list() async => [];
}
