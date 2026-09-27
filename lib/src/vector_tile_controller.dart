import 'package:flutter_map/flutter_map.dart' show TileCoordinates;

import 'cache/caches.dart';

/// A controller for programmatic access to [VectorTileLayer] cache operations.
///
/// Create an instance and pass it to [VectorTileLayer.controller].
/// Use [clearMemoryCaches] to clear all in-memory caches on demand.
abstract class VectorTileController {
  /// Creates a [VectorTileController].
  factory VectorTileController() = _VectorTileControllerImpl;

  /// Clears all in-memory caches without adjusting their max sizes.
  ///
  /// If the controller is not attached to a widget, this is a no-op.
  void clearMemoryCaches();

  /// Renders [tiles] ahead of time into the caches a visible request will
  /// hit, with low priority: prefetched tiles only get rasterization slots
  /// that a frame left unused (see `VectorTileLayer.rasterTilesPerFrame`).
  ///
  /// Only the raster layer mode supports this; otherwise, or when the
  /// controller is not attached to a widget, this is a no-op. Callers are
  /// expected to keep the list small - every tile costs memory in the image
  /// cache and work on the raster thread.
  void prefetch(Iterable<TileCoordinates> tiles);
}

class _VectorTileControllerImpl implements VectorTileController {
  Caches? _caches;
  void Function(TileCoordinates)? _prefetcher;

  @override
  void clearMemoryCaches() {
    _caches?.clearMemoryCaches();
  }

  @override
  void prefetch(Iterable<TileCoordinates> tiles) {
    final prefetcher = _prefetcher;
    if (prefetcher == null) return;
    for (final tile in tiles) {
      prefetcher(tile);
    }
  }

  void attach(Caches caches) {
    assert(_caches == null, 'VectorTileController is already attached');
    _caches = caches;
  }

  void attachPrefetcher(void Function(TileCoordinates) prefetcher) {
    _prefetcher = prefetcher;
  }

  void detach() {
    _caches = null;
    _prefetcher = null;
  }
}

/// Attaches the [controller] to the given [caches].
///
/// This is package-internal and not exported from the library barrel file.
void attachController(VectorTileController? controller, Caches caches) {
  (controller as _VectorTileControllerImpl?)?.attach(caches);
}

/// Detaches the [controller] from its caches.
///
/// This is package-internal and not exported from the library barrel file.
void detachController(VectorTileController? controller) {
  (controller as _VectorTileControllerImpl?)?.detach();
}

/// Wires the raster-mode prefetch path into the [controller].
///
/// This is package-internal and not exported from the library barrel file.
void attachPrefetcher(VectorTileController? controller,
    void Function(TileCoordinates) prefetcher) {
  (controller as _VectorTileControllerImpl?)?.attachPrefetcher(prefetcher);
}
