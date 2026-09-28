import 'dart:async';
import 'dart:typed_data';

import 'package:executor_lib/executor_lib.dart';
import 'package:flutter_map/flutter_map.dart' show TileCoordinates, TileLayer;
import 'package:test/test.dart';
import 'package:vector_map_tiles/src/cache/byte_storage.dart';
import 'package:vector_map_tiles/src/cache/image_loading_cache.dart';
import 'package:vector_map_tiles/src/cache/storage_cache.dart';
import 'package:vector_map_tiles/src/raster/frame_budget.dart';
import 'package:vector_map_tiles/src/raster/storage_image_cache.dart';
import 'package:vector_map_tiles/src/raster/tile_loader.dart';
import 'package:vector_map_tiles/src/stream/tile_supplier.dart';
import 'package:vector_map_tiles/src/stream/tile_supplier_raster.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' hide TileLayer;

/// A tile is requested from the vector provider before the raster sources
/// are awaited. A cancellation arriving in between must not surface as an
/// "Unhandled Exception: Cancelled" - nobody listened to the vector future
/// yet, and the zone reported it without a stack trace.
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

  TileLoader loaderWith(_SlowRasterTileProvider raster) {
    final storage = StorageCache(_NoStorage(), const Duration(days: 1), 0);
    return TileLoader(
        theme,
        null,
        null,
        _CancellingProvider(),
        raster,
        TileOffset.DEFAULT,
        StorageImageCache(theme, storage, 1.0, enabled: false),
        1,
        1.0,
        FrameBudget(0));
  }

  Future<(Object?, List<Object>)> load(_SlowRasterTileProvider raster) async {
    final uncaught = <Object>[];
    Object? thrown;
    await runZonedGuarded(() async {
      try {
        await loaderWith(raster)
            .loadTile(const TileCoordinates(2, 1, 3), TileLayer(), () => false);
      } catch (e) {
        thrown = e;
      }
      // Give a stray error the chance to reach the zone.
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }, (error, _) => uncaught.add(error));
    return (thrown, uncaught);
  }

  test('a cancellation while raster tiles load reaches the caller', () async {
    final (thrown, uncaught) = await load(_SlowRasterTileProvider());
    expect(thrown, isA<CancellationException>());
    expect(uncaught, isEmpty);
  });

  test('a cancellation stays quiet when the raster tiles fail', () async {
    final (thrown, uncaught) = await load(_SlowRasterTileProvider(fail: true));
    expect(thrown, 'raster failed');
    expect(uncaught, isEmpty);
  });
}

class _CancellingProvider implements TileProvider {
  @override
  int get maximumZoom => 14;

  @override
  Future<TileResponse> provide(TileRequest request) =>
      Future.error(CancellationException());

  @override
  Future<TileResponse> provideLocalCopy(TileRequest request) =>
      provide(request);
}

class _SlowRasterTileProvider extends RasterTileProvider {
  final bool fail;

  _SlowRasterTileProvider({this.fail = false})
      : super(
            providers: const TileProviders({}),
            cache: ImageLoadingCache(
                delegate:
                    StorageCache(_NoStorage(), const Duration(days: 1), 0),
                providers: const TileProviders({})));

  @override
  Future<RasterTileset> retrieve(TileIdentity tile,
      {bool skipMissing = true}) async {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    if (fail) {
      throw 'raster failed';
    }
    return const RasterTileset(tiles: {});
  }
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
