import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

import 'market_instrument_data.dart';
import 'market_instrument_links.dart';

class InstrumentMapPreview extends StatelessWidget {
  const InstrumentMapPreview._({
    required this.address,
    required this.hasStreet,
    required this._lookup,
  });

  final String address;
  final bool hasStreet;
  final Future<_MapMatch?> _lookup;

  static Future<void> show(
    BuildContext context, {
    required String address,
    required bool hasStreet,
  }) {
    final lookup = _MapMatch.lookup(address);
    return UiDialog.show<void>(
      context,
      maxWidth: 640,
      child: InstrumentMapPreview._(
        address: address,
        hasStreet: hasStreet,
        lookup: lookup,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchUri = Uri.https('www.openstreetmap.org', '/search', {
      'query': address,
    });
    return UiDialog(
      title: 'Company location',
      description: address,
      icon: Icons.location_on_outlined,
      content: FutureBuilder<_MapMatch?>(
        future: _lookup,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Semantics(
              liveRegion: true,
              label: 'Finding the company address',
              child: const UiSkeleton(width: double.infinity, height: 252),
            );
          }
          final match = snapshot.data;
          if (match == null) {
            return const UiCallout(
              title: 'Map preview unavailable',
              message: 'You can search the reported address on OpenStreetMap.',
            );
          }
          return _AddressMap(match: match, hasStreet: hasStreet);
        },
      ),
      actions: [
        UiButton(
          label: 'Open in OpenStreetMap',
          trailingIcon: Icons.open_in_new,
          size: UiSize.sm,
          onPressed: () => openInstrumentLink(
            context,
            searchUri,
            failureTitle: 'Could not open OpenStreetMap',
          ),
        ),
      ],
    );
  }
}

class _AddressMap extends StatelessWidget {
  const _AddressMap({required this.match, required this.hasStreet});

  static const _tiles = String.fromEnvironment(
    'MARKET_MAP_TILES_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  final _MapMatch match;
  final bool hasStreet;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (match.label.isNotEmpty) ...[
          Text('Map match · ${match.label}', style: context.uiText.caption),
          UiGap.v(theme.spacing.xs),
        ],
        SizedBox(
          height: context.sz(252),
          width: double.infinity,
          child: ClipRRect(
            borderRadius: context.radius(theme.radii.md),
            child: FlutterMap(
              options: MapOptions(
                initialCenter: match.point,
                initialZoom: hasStreet && match.isStreetLevel ? 16 : 11,
                maxZoom: 19,
                backgroundColor: theme.colors.surfaceMuted,
                interactionOptions: const InteractionOptions(
                  flags:
                      InteractiveFlag.drag |
                      InteractiveFlag.pinchZoom |
                      InteractiveFlag.doubleTapZoom,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: _tiles,
                  userAgentPackageName: 'in.alphajournal.market',
                  panBuffer: 0,
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: match.point,
                      child: Icon(
                        Icons.location_on,
                        color: theme.colors.danger,
                        size: context.sz(30),
                        semanticLabel: 'Matched company location',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        UiButton(
          label: '© OpenStreetMap contributors',
          size: UiSize.xs,
          variant: UiVariant.link,
          onPressed: () => openInstrumentLink(
            context,
            Uri.https('www.openstreetmap.org', '/copyright'),
            failureTitle: 'Could not open map attribution',
          ),
        ),
      ],
    );
  }
}

class _MapMatch {
  const _MapMatch(this.point, this.label, {required this.isStreetLevel});

  static const _endpoint = String.fromEnvironment(
    'MARKET_GEOCODER_URL',
    defaultValue: 'https://photon.komoot.io/api/',
  );
  static final _lookups = <String, Future<_MapMatch?>>{};

  final LatLng point;
  final String label;
  final bool isStreetLevel;

  static Future<_MapMatch?> lookup(String address) {
    if (_lookups[address] case final cached?) return cached;
    if (_lookups.length >= 32) _lookups.remove(_lookups.keys.first);
    final lookup = _fetch(address);
    _lookups[address] = lookup;
    return lookup;
  }

  static Future<_MapMatch?> _fetch(String address) async {
    try {
      final uri = Uri.parse(
        _endpoint,
      ).replace(queryParameters: {'q': address, 'limit': '1'});
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final features = instrumentRows(
          instrumentMap(
            jsonDecode(utf8.decode(response.bodyBytes)),
          )['features'],
        );
        if (features.firstOrNull case final feature?) {
          return _fromFeature(feature);
        }
        return null;
      }
    } on Exception {
      // The dialog keeps the address link available if the lookup fails.
    }
    _lookups.remove(address);
    return null;
  }

  static _MapMatch? _fromFeature(InstrumentRow feature) {
    final geometry = instrumentMap(feature['geometry']);
    final coordinates = geometry['coordinates'];
    if (geometry['type'] != 'Point' ||
        coordinates is! List ||
        coordinates.length < 2) {
      return null;
    }
    final lng = instrumentNumber(coordinates[0]);
    final lat = instrumentNumber(coordinates[1]);
    if (lat == null || lng == null || lat.abs() > 85.051 || lng.abs() > 180) {
      return null;
    }
    final properties = instrumentMap(feature['properties']);
    return _MapMatch(
      LatLng(lat, lng),
      {
        for (final field in ['name', 'city', 'country'])
          ?instrumentText(properties[field]),
      }.join(', '),
      isStreetLevel: const {'house', 'street'}.contains(properties['type']),
    );
  }
}
