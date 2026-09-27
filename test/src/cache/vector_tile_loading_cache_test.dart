import 'dart:typed_data';

import 'package:executor_lib/executor_lib.dart';
import 'package:test/test.dart';
import 'package:vector_map_tiles/src/cache/byte_storage.dart';
import 'package:vector_map_tiles/src/cache/memory_cache.dart';
import 'package:vector_map_tiles/src/cache/storage_cache.dart';
import 'package:vector_map_tiles/src/cache/vector_tile_loading_cache.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';

void main() {
  final theme = ThemeReader().read({
    'version': 8,
    'sources': {
      'openmaptiles': {'type': 'vector'}
    },
    'layers': [
      {
        'id': 'water',
        'type': 'fill',
        'source': 'openmaptiles',
        'source-layer': 'water',
      }
    ],
  });
  final tile = TileIdentity(3, 4, 2);

  Future<(_CountingStorage, _FakeProvider)> load(
      {required bool cacheable, required bool cachedOnly}) async {
    final storage = _CountingStorage();
    final provider = _FakeProvider(cacheable: cacheable);
    final cache = VectorTileLoadingCache(
        StorageCache(storage, const Duration(days: 1), 1 << 20),
        MemoryCache(maxSizeBytes: 1 << 20),
        MemoryTileDataCache(maxSize: 10),
        TileProviders({'openmaptiles': provider}),
        ImmediateExecutor(),
        theme);
    final data = await cache.retrieve('openmaptiles', tile,
        cancelled: () => false, cachedOnly: cachedOnly);
    if (!cachedOnly || !cacheable) {
      expect(data, isNotNull);
    }
    return (storage, provider);
  }

  test('a cacheable provider goes through the file cache', () async {
    final (storage, provider) = await load(cacheable: true, cachedOnly: false);
    expect(storage.reads, 1);
    expect(storage.writes, 1);
    expect(provider.provided, 1);
  });

  test('a local provider bypasses the file cache', () async {
    final (storage, provider) = await load(cacheable: false, cachedOnly: false);
    expect(storage.reads, 0);
    expect(storage.writes, 0);
    expect(provider.provided, 1);
  });

  test('a local provider counts as local for cached-only loads', () async {
    final (storage, provider) = await load(cacheable: false, cachedOnly: true);
    expect(storage.reads, 0);
    expect(storage.writes, 0);
    expect(provider.provided, 1);
  });

  test('a cacheable provider is not asked for cached-only loads', () async {
    final (storage, provider) = await load(cacheable: true, cachedOnly: true);
    expect(storage.reads, 1);
    expect(provider.provided, 0);
  });
}

class _FakeProvider extends VectorTileProvider {
  _FakeProvider({required this.cacheable});

  @override
  final bool cacheable;

  int provided = 0;

  @override
  Future<Uint8List> provide(TileIdentity tile) async {
    provided++;
    // An empty protobuf message is a vector tile without layers.
    return Uint8List(0);
  }

  @override
  int get maximumZoom => 14;

  @override
  int get minimumZoom => 0;

  @override
  TileOffset get tileOffset => TileOffset.DEFAULT;
}

class _CountingStorage extends ByteStorage {
  final _entries = <String, Uint8List>{};
  int reads = 0;
  int writes = 0;

  @override
  Future<Uint8List?> read(String key) async {
    reads++;
    return _entries[key];
  }

  @override
  Future<void> write(String key, Uint8List bytes) async {
    writes++;
    _entries[key] = bytes;
  }

  @override
  Future<bool> exists(String key) async => _entries.containsKey(key);

  @override
  Future<void> delete(String key) async => _entries.remove(key);

  @override
  Future<List<ByteStorageEntry>> list() async => [];
}
