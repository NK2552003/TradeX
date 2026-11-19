import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

import 'market_instrument_data.dart';
import 'market_instrument_links.dart';
import 'market_instrument_map.dart';

class InstrumentContact extends StatelessWidget {
  const InstrumentContact({super.key, required this.summary});

  static const fields = {'address', 'city', 'country', 'phone', 'website'};

  final InstrumentRow summary;

  @override
  Widget build(BuildContext context) {
    final street = instrumentText(summary['address']);
    final address = {
      ?street,
      ?instrumentText(summary['city']),
      ?instrumentText(summary['country']),
    }.join(', ');
    final phone = instrumentText(summary['phone']);
    final dialNumber = phone?.replaceAll(RegExp(r'[\s().-]'), '');
    final dialUri =
        dialNumber != null && RegExp(r'^\+?[0-9]{5,15}$').hasMatch(dialNumber)
        ? Uri(scheme: 'tel', path: dialNumber)
        : null;
    final website = instrumentText(summary['website']);
    final websiteUri = _websiteUri(website);

    return UiCardGrid(
      minTileWidth: context.sz(255),
      largeColumns: 3,
      equalHeight: true,
      children: [
        if (address.isNotEmpty)
          UiCard(
            title: street == null ? 'Company location' : 'Company address',
            subtitle: address,
            leading: const Icon(Icons.location_on_outlined),
            child: UiButton(
              label: 'Preview map',
              icon: Icons.map_outlined,
              variant: UiVariant.outline,
              size: UiSize.sm,
              onPressed: () => InstrumentMapPreview.show(
                context,
                address: address,
                hasStreet: street != null,
              ),
            ),
          ),
        if (phone != null)
          UiCard(
            title: 'Company phone',
            subtitle: phone,
            leading: const Icon(Icons.phone_outlined),
            child: dialUri == null
                ? const SizedBox.shrink()
                : UiButton(
                    label: 'Call company',
                    variant: UiVariant.outline,
                    size: UiSize.sm,
                    onPressed: () => openInstrumentLink(
                      context,
                      dialUri,
                      failureTitle: 'Could not open your phone app',
                    ),
                  ),
          ),
        if (website != null)
          UiCard(
            title: 'Company website',
            subtitle: websiteUri?.host ?? website,
            leading: const Icon(Icons.language_outlined),
            child: websiteUri == null
                ? const SizedBox.shrink()
                : UiButton(
                    label: 'Open website',
                    tooltip: websiteUri.toString(),
                    trailingIcon: Icons.open_in_new,
                    variant: UiVariant.outline,
                    size: UiSize.sm,
                    onPressed: () => openInstrumentLink(
                      context,
                      websiteUri,
                      failureTitle: 'Could not open the company website',
                    ),
                  ),
          ),
      ],
    );
  }

  static Uri? _websiteUri(String? website) {
    if (website == null || RegExp(r'[\s\\]').hasMatch(website)) return null;
    final parsed = Uri.tryParse(website);
    if (parsed == null) return null;
    final uri = parsed.hasScheme ? parsed : Uri.tryParse('https://$website');
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri;
  }
}
