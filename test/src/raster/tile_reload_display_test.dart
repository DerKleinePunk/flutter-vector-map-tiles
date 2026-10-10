import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/src/raster/label_rotation.dart';

/// Hands out the same image under a key that changes with the layer's
/// `additionalOptions`, like the raster tile provider does with the label
/// rotation.
class _KeyedTileProvider extends TileProvider {
  _KeyedTileProvider(this.image);

  final ui.Image image;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _KeyedImage(image, '$coordinates ${options.additionalOptions}');
}

class _KeyedImage extends ImageProvider<String> {
  _KeyedImage(this.image, this.key);

  final ui.Image image;
  final String key;

  @override
  Future<String> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(key);

  @override
  ImageStreamCompleter loadImage(String key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(
          SynchronousFuture(ImageInfo(image: image.clone())));
}

Widget _map(TileProvider provider, TileDisplay display, String rotation) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: FlutterMap(
        options:
            const MapOptions(initialCenter: LatLng(50.9, 9.4), initialZoom: 12),
        children: [
          TileLayer(
            tileProvider: provider,
            tileDisplay: display,
            additionalOptions: {labelRotationOption: rotation},
          ),
        ],
      ),
    );

/// The lowest opacity of all tiles on screen.
double _minOpacity(WidgetTester tester) => tester
    .widgetList<RawImage>(find.byType(RawImage))
    .map((w) => w.opacity?.value ?? 1.0)
    .reduce((a, b) => a < b ? a : b);

/// Shows the tiles at one rotation, then at another, then back, and returns
/// the lowest tile opacity in the frame after each change.
Future<List<double>> _reload(WidgetTester tester, TileDisplay display) async {
  final image =
      await tester.runAsync(() => createTestImage(width: 4, height: 4));
  final provider = _KeyedTileProvider(image!);
  await tester.pumpWidget(_map(provider, display, '0.0'));
  await tester.pumpAndSettle();
  expect(find.byType(RawImage), findsWidgets);
  final result = <double>[];
  for (final rotation in ['45.0', '0.0']) {
    await tester.pumpWidget(_map(provider, display, rotation));
    await tester.pump();
    result.add(_minOpacity(tester));
    await tester.pumpAndSettle();
  }
  return result;
}

void main() {
  testWidgets('reloaded tiles keep full opacity, no blank frame', (
    tester,
  ) async {
    expect(await _reload(tester, rasterTileDisplay), [1.0, 1.0]);
  });

  testWidgets('flutter_map default blanks reloaded tiles (counter check)', (
    tester,
  ) async {
    final opacities = await _reload(tester, const TileDisplay.fadeIn());
    expect(opacities, everyElement(lessThan(0.5)));
  });
}
