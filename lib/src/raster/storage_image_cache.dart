import 'dart:typed_data';
import 'dart:ui';

import 'images.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';

import '../../vector_map_tiles.dart';
import '../cache/storage_cache.dart';

class StorageImageCache {
  late final String themeKey;
  final StorageCache delegate;

  /// Part of the key: an image rendered at one scale must not be served
  /// for another, it would be drawn at the wrong size.
  final double scale;

  /// Off when all sources are local: rendering the tile again is cheaper
  /// than encoding it as PNG and keeping the cache folder within its limit.
  final bool enabled;

  StorageImageCache(Theme theme, this.delegate, this.scale,
      {this.enabled = true}) {
    themeKey = '${theme.id}-v${theme.version}-s$scale'
        .replaceAll(RegExp(r'[^a-zA-Z0-9.-]'), '-');
  }

  Future<Image?> retrieve(TileIdentity tile, {double labelRotation = 0}) async {
    if (!enabled) {
      return null;
    }
    String key = keyOf(tile, labelRotation: labelRotation);
    final cached = await delegate.retrieve(key);
    if (cached != null) {
      final bytes = Uint8List.fromList(cached);
      try {
        return await imageFrom(bytes: bytes);
      } catch (error, stack) {
        // in case the byte data is invalid, discard and remove the cached value
        // ignore: avoid_print
        print(error);
        // ignore: avoid_print
        print(stack);
        await _removeQuietly(key);
      }
    }
    return null;
  }

  Future<void> put(TileIdentity tile, Image image,
      {double labelRotation = 0}) async {
    if (!enabled) {
      return;
    }
    final bytes = await image.toByteData(format: ImageByteFormat.png);
    if (bytes != null) {
      await delegate.put(keyOf(tile, labelRotation: labelRotation),
          bytes.buffer.asUint8List());
    }
  }

  /// The file name of [tile]. Tiles rendered for a label rotation get their
  /// own name; upright ones keep the name they had before rotations existed.
  String keyOf(TileIdentity tile, {double labelRotation = 0}) {
    final rotation =
        labelRotation == 0 ? '' : '-r${labelRotation.toStringAsFixed(1)}';
    return '$themeKey-${tile.z}-${tile.x}-${tile.y}$rotation.png';
  }

  Future _removeQuietly(String key) async {
    try {
      delegate.remove(key);
    } catch (_) {}
  }
}
