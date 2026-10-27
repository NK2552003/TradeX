# alphajournal App Scaffold

This folder contains a more complete Flutter starter structure for the TraderHub concept, based on the repository documentation.

## Structure

- lib/core for shared infrastructure: config, router, theme, widgets, network, and utilities
- lib/features for feature slices such as auth, journal, strategies, watchlists, portfolio, community, messages, insights, notifications, subscriptions, and enterprise
- lib/main.dart as the app entry point
- test/ with core and feature-level test folders mirroring the app layout
- assets/ for future images and fonts

## Current MVP modules

- Journal
- Watchlists
- Portfolio

## Additional scaffolded areas

- Auth
- Strategies
- Community
- Messages
- Insights
- Notifications
- Subscriptions
- Enterprise

## Run

```bash
cd ~/TradeX
pub get
flutter run
```
