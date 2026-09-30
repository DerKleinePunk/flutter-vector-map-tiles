import 'dart:async';
import 'dart:ui' as ui;

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

  group('tiles rendered again for a new label rotation', () {
    late List<(TileCoordinates, bool)> loads;

    Future<ImageInfo> recording(
        TileCoordinates coords, TileLayer options, bool Function() cancelled,
        {bool lowPriority = false}) {
      loads.add((coords, lowPriority));
      return Completer<ImageInfo>().future;
    }

    setUp(() => loads = []);

    /// Asks [provider] for [coords] at [rotation] and returns whether the
    /// loader was told low priority.
    Future<bool> lowPriorityOf(FutureTileProvider provider,
        TileCoordinates coords, String rotation) async {
      final image = imageFor(provider, coords, labelRotation: rotation);
      final key = await image.obtainKey(ImageConfiguration.empty);
      // ignore: invalid_use_of_protected_member
      (image as dynamic).loadImage(
          key,
          (ui.ImmutableBuffer buffer,
                  {ui.TargetImageSizeCallback? getTargetSize}) =>
              throw UnimplementedError());
      return loads.last.$2;
    }

    const other = TileCoordinates(2, 2, 3);

    test('the first request at a rotation is regular', () async {
      final provider =
          FutureTileProvider(loader: recording, themeIdentity: themeV1);

      expect(await lowPriorityOf(provider, aTile, '0.0'), isFalse);
      expect(await lowPriorityOf(provider, aTile, '0.0'), isFalse);
    });

    test('a tile shown at the previous rotation goes behind', () async {
      final provider =
          FutureTileProvider(loader: recording, themeIdentity: themeV1);
      await lowPriorityOf(provider, aTile, '0.0');

      expect(await lowPriorityOf(provider, aTile, '45.0'), isTrue);
    });

    test('a tile new on screen after the change stays regular', () async {
      final provider =
          FutureTileProvider(loader: recording, themeIdentity: themeV1);
      await lowPriorityOf(provider, aTile, '0.0');

      expect(await lowPriorityOf(provider, other, '45.0'), isFalse);
    });

    test('only the rotation right before counts', () async {
      final provider =
          FutureTileProvider(loader: recording, themeIdentity: themeV1);
      await lowPriorityOf(provider, aTile, '0.0');
      await lowPriorityOf(provider, other, '45.0');

      expect(await lowPriorityOf(provider, aTile, '90.0'), isFalse,
          reason: 'aTile was last asked for two rotations ago');
      expect(await lowPriorityOf(provider, other, '135.0'), isFalse,
          reason: 'at 90 other was not asked for');
    });

    test('without rotated labels nothing goes behind', () async {
      final provider =
          FutureTileProvider(loader: recording, themeIdentity: themeV1);
      for (var i = 0; i < 3; i++) {
        final image = provider.getImage(aTile, TileLayer());
        final key = await image.obtainKey(ImageConfiguration.empty);
        // ignore: invalid_use_of_protected_member
        (image as dynamic).loadImage(
            key,
            (ui.ImmutableBuffer buffer,
                    {ui.TargetImageSizeCallback? getTargetSize}) =>
                throw UnimplementedError());
        expect(loads.last.$2, isFalse);
      }
    });
  });
}
