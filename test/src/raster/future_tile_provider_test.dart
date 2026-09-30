import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:test/test.dart';
import 'package:vector_map_tiles/src/raster/future_tile_provider.dart';
import 'package:vector_map_tiles/src/raster/label_rotation.dart';

/// The image cache key must identify a rendering without referencing the tile
/// loader: Flutter's [ImageCache] retains its keys, so a key that reached the
/// loader would keep the whole tile pipeline (and its geometry) alive for as
/// long as any tile image was cached.
void main() {
  Future<ImageInfo> neverLoads(
          TileCoordinates coords, TileLayer options, bool Function() cancelled,
          {bool lowPriority = false}) =>
      Completer<ImageInfo>().future;

  FutureTileProvider providerWith(String themeIdentity) =>
      FutureTileProvider(loader: neverLoads, themeIdentity: themeIdentity);

  ImageProvider imageFor(FutureTileProvider provider, TileCoordinates coords,
          {int tileDimension = 256, String? labelRotation}) =>
      provider.getImage(
          coords,
          TileLayer(
              tileDimension: tileDimension,
              additionalOptions: labelRotation == null
                  ? const {}
                  : {labelRotationOption: labelRotation}));

  Future<Object> keyFor(FutureTileProvider provider, TileCoordinates coords,
          {int tileDimension = 256, String? labelRotation}) =>
      imageFor(provider, coords,
              tileDimension: tileDimension, labelRotation: labelRotation)
          .obtainKey(ImageConfiguration.empty);

  const aTile = TileCoordinates(1, 2, 3);
  const themeV1 = 'a-theme/v1/openmaptiles';
  const themeV2 = 'a-theme/v2/openmaptiles';

  group('cache key does not reference the provider', () {
    test('the key is a distinct object from the image provider', () async {
      final provider = providerWith(themeV1);
      final image = imageFor(provider, aTile);

      final key = await image.obtainKey(ImageConfiguration.empty);

      expect(key, isNot(same(image)),
          reason: 'a key that is the provider retains the tile loader');
      expect(key, isNot(same(provider)));
    });
  });

  group('cache key identity', () {
    test('separate requests for the same tile produce equal keys', () async {
      final provider = providerWith(themeV1);

      final first = await keyFor(provider, aTile);
      final second = await keyFor(provider, aTile);

      expect(first, equals(second));
      expect(first.hashCode, equals(second.hashCode));
    });

    test('distinct provider instances agree when the identity matches',
        () async {
      final first = await keyFor(providerWith(themeV1), aTile);
      final second = await keyFor(providerWith(themeV1), aTile);

      expect(first, equals(second));
    });

    test('a theme version bump produces a different key', () async {
      final first = await keyFor(providerWith(themeV1), aTile);
      final second = await keyFor(providerWith(themeV2), aTile);

      expect(first, isNot(equals(second)));
    });

    test('a different theme produces a different key', () async {
      final first = await keyFor(providerWith(themeV1), aTile);
      final second =
          await keyFor(providerWith('other-theme/v1/openmaptiles'), aTile);

      expect(first, isNot(equals(second)));
    });

    test('different tile sources produce a different key', () async {
      final first = await keyFor(providerWith(themeV1), aTile);
      final second = await keyFor(providerWith('a-theme/v1/hillshade'), aTile);

      expect(first, isNot(equals(second)));
    });

    test('different coordinates produce a different key', () async {
      final provider = providerWith(themeV1);

      final first = await keyFor(provider, aTile);
      final second = await keyFor(provider, const TileCoordinates(9, 2, 3));

      expect(first, isNot(equals(second)));
    });

    test('a different tile dimension produces a different key', () async {
      final provider = providerWith(themeV1);

      final first = await keyFor(provider, aTile, tileDimension: 256);
      final second = await keyFor(provider, aTile, tileDimension: 512);

      expect(first, isNot(equals(second)));
    });
    test('a different label rotation produces a different key', () async {
      final provider = providerWith(themeV1);

      final upright = await keyFor(provider, aTile);
      final turned = await keyFor(provider, aTile, labelRotation: '180.0');

      expect(upright, isNot(equals(turned)));
    });

    test('no label rotation and a rotation of 0 share a key', () async {
      final provider = providerWith(themeV1);

      final none = await keyFor(provider, aTile);
      final zero = await keyFor(provider, aTile, labelRotation: '0.0');

      expect(none, equals(zero));
    });
  });
}
