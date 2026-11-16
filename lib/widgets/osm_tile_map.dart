import 'dart:math' as math;

import 'package:flutter/material.dart';

class OsmTileMap extends StatelessWidget {
  const OsmTileMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.marker,
    this.markerOffset = const Offset(0, -18),
    this.showAttribution = true,
  });

  final double latitude;
  final double longitude;
  final Widget? marker;
  final Offset markerOffset;
  final bool showAttribution;

  static const _zoom = 16;
  static const _tileSize = 256.0;

  @override
  Widget build(BuildContext context) {
    final latitudeRadians =
        latitude.clamp(-85.0511, 85.0511).toDouble() * math.pi / 180;
    final normalizedLongitude = longitude.clamp(-180.0, 180.0).toDouble();
    final worldTileCount = 1 << _zoom;
    final centerTileX = (normalizedLongitude + 180) / 360 * worldTileCount;
    final centerTileY =
        (1 -
            math.log(
                  math.tan(latitudeRadians) + 1 / math.cos(latitudeRadians),
                ) /
                math.pi) /
        2 *
        worldTileCount;

    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
            return const ColoredBox(color: Color(0xFFE7ECEF));
          }

          final centerPixelX = centerTileX * _tileSize;
          final centerPixelY = centerTileY * _tileSize;
          final mapLeft = centerPixelX - constraints.maxWidth / 2;
          final mapTop = centerPixelY - constraints.maxHeight / 2;
          final firstTileX = (mapLeft / _tileSize).floor();
          final lastTileX = ((mapLeft + constraints.maxWidth) / _tileSize)
              .floor();
          final firstTileY = (mapTop / _tileSize).floor();
          final lastTileY = ((mapTop + constraints.maxHeight) / _tileSize)
              .floor();
          final tiles = <Widget>[];

          for (var tileX = firstTileX; tileX <= lastTileX; tileX++) {
            for (var tileY = firstTileY; tileY <= lastTileY; tileY++) {
              if (tileY < 0 || tileY >= worldTileCount) continue;
              final wrappedTileX =
                  (tileX % worldTileCount + worldTileCount) % worldTileCount;
              tiles.add(
                Positioned(
                  left: tileX * _tileSize - mapLeft,
                  top: tileY * _tileSize - mapTop,
                  width: _tileSize,
                  height: _tileSize,
                  child: Image.network(
                    Uri.https(
                      'tile.openstreetmap.org',
                      '/$_zoom/$wrappedTileX/$tileY.png',
                    ).toString(),
                    fit: BoxFit.cover,
                    headers: const {'User-Agent': 'PHD-Puskesmas-Mobile/1.0'},
                    errorBuilder: (context, error, stackTrace) =>
                        const ColoredBox(color: Color(0xFFE7ECEF)),
                  ),
                ),
              );
            }
          }

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              const Positioned.fill(
                child: ColoredBox(color: Color(0xFFE7ECEF)),
              ),
              ...tiles,
              if (marker != null)
                Center(
                  child: Transform.translate(
                    offset: markerOffset,
                    child: marker,
                  ),
                ),
              if (showAttribution)
                const Positioned(
                  right: 6,
                  bottom: 5,
                  child: Text(
                    '© OpenStreetMap contributors',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 8,
                      backgroundColor: Colors.white70,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
