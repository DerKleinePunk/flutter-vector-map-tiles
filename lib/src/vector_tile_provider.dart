import 'dart:typed_data';

import '../vector_map_tiles.dart';

enum TileProviderType {
  vector,
  raster,

  /// corresponds to type `raster-dem`
  /// providers of this type should return DEM tiles in PNG format
// ignore: constant_identifier_names
  raster_dem
}

abstract class VectorTileProvider {
  /// provides a tile as a `pbf` or `mvt` format for [type] of [TileProviderType.vector]
  /// or `png` for [TileProviderType.raster]
  Future<Uint8List> provide(TileIdentity tile);

  /// the maximum zoom supported by this provider
  int get maximumZoom;

  /// the minimum zoom supported by this provider
  int get minimumZoom;

  /// the offset to use with this tile provider, can be used to reduce data
  /// overhead of specific providers in a theme. This value is combined with
  /// [VectorTileLayer.tileOffset].
  TileOffset get tileOffset;

  TileProviderType get type => TileProviderType.vector;

  /// whether tiles from this provider go through the file cache. Providers
  /// that read from local storage (a folder, an MBTiles file) should return
  /// false: reading the tile again is as cheap as reading the cached copy,
  /// and the cache has to list its whole folder to keep within its size
  /// limit. Such providers also count as local for loads that must not go to
  /// the network.
  bool get cacheable => true;
}
