import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_map/flutter_map.dart' show TileCoordinates, TileLayer;
import 'package:test/test.dart';
import 'package:vector_map_tiles/src/cache/byte_storage.dart';
import 'package:vector_map_tiles/src/cache/image_loading_cache.dart';
import 'package:vector_map_tiles/src/cache/storage_cache.dart';
import 'package:vector_map_tiles/src/raster/frame_budget.dart';
import 'package:vector_map_tiles/src/raster/label_rotation.dart';
import 'package:vector_map_tiles/src/raster/storage_image_cache.dart';
import 'package:vector_map_tiles/src/raster/tile_loader.dart';
import 'package:vector_map_tiles/src/stream/tile_supplier.dart';
import 'package:vector_map_tiles/src/stream/tile_supplier_raster.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' hide TileLayer;
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr
    show TileLayer;

/// A point label anchored at its top sits below the point on an upright tile.
/// Rendered for a map rotated by 180° it has to be turned back, and then sits
/// above the point: on the rotated map it reads upright, below the point.
/// (The renderer knows the anchors center, top and bottom only.)
void main() {
  final theme = ThemeReader().read({
    'version': 8,
    'sources': {
      'openmaptiles': {'type': 'vector'}
    },
    'layers': [
      {
        'id': 'place',
        'type': 'symbol',
        'source': 'openmaptiles',
        'source-layer': 'place',
        'layout': {
          'text-field': '{name}',
          'text-anchor': 'top',
          'text-size': 24,
        },
        'paint': {'text-color': '#000000'},
      }
    ],
  });

  TileLoader loader() {
    final storage = StorageCache(_NoStorage(), const Duration(days: 1), 0);
    return TileLoader(
        theme,
        null,
        null,
        _OnePlaceProvider(),
        _NoRasterTileProvider(),
        TileOffset.DEFAULT,
        StorageImageCache(theme, storage, 1.0, enabled: false),
        1,
        1.0,
        FrameBudget(0));
  }

  /// The mean y of all painted pixels, relative to the tile centre where the
  /// point lies; positive is below.
  Future<double> labelOffsetY({required double labelRotation}) async {
    final info = await loader().loadTile(
        const TileCoordinates(0, 0, 1),
        TileLayer(
            additionalOptions: labelRotation == 0
                ? const {}
                : {labelRotationOption: labelRotation.toString()}),
        () => false);
    final image = info.image;
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    var sum = 0.0;
    var count = 0;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final alpha = bytes.getUint8((y * image.width + x) * 4 + 3);
        if (alpha > 128) {
          sum += y;
          count++;
        }
      }
    }
    expect(count, greaterThan(50), reason: 'no label was painted');
    return sum / count - image.height / 2;
  }

  test('upright tiles have the label below the point', () async {
    expect(await labelOffsetY(labelRotation: 0), greaterThan(8));
  });

  test('tiles for a map rotated by 180° have it turned back', () async {
    expect(await labelOffsetY(labelRotation: 180), lessThan(-8));
  });

  test('tiles for 90° have it beside the point, not above or below', () async {
    expect((await labelOffsetY(labelRotation: 90)).abs(), lessThan(4));
  });
}

class _OnePlaceProvider implements TileProvider {
  @override
  int get maximumZoom => 14;

  @override
  Future<TileResponse> provide(TileRequest request) async {
    final feature = TileFeature(
        type: TileFeatureType.point,
        properties: {'name': 'MITTE'},
        points: [const Point(2048.0, 2048.0)],
        lines: null,
        polygons: null);
    final tile = Tile(layers: [
      vtr.TileLayer(name: 'place', extent: 4096, features: [feature])
    ]);
    return TileResponse(
        identity: request.tileId, tileset: Tileset({'openmaptiles': tile}));
  }

  @override
  Future<TileResponse> provideLocalCopy(TileRequest request) =>
      provide(request);
}

class _NoRasterTileProvider extends RasterTileProvider {
  _NoRasterTileProvider()
      : super(
            providers: const TileProviders({}),
            cache: ImageLoadingCache(
                delegate:
                    StorageCache(_NoStorage(), const Duration(days: 1), 0),
                providers: const TileProviders({})));

  @override
  Future<RasterTileset> retrieve(TileIdentity tile,
          {bool skipMissing = true}) async =>
      const RasterTileset(tiles: {});
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
