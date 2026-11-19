import 'package:flutter/material.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

/// Resolves clean website domains and real favicon / brand logo URLs for
/// links, citations, publishers, and market entities.
class SiteLogoResolver {
  const SiteLogoResolver._();

  static const Map<String, String> _tickerDomains = <String, String>{
    'AAPL': 'apple.com',
    'NVDA': 'nvidia.com',
    'MSFT': 'microsoft.com',
    'GOOGL': 'google.com',
    'GOOG': 'google.com',
    'AMZN': 'amazon.com',
    'META': 'meta.com',
    'TSLA': 'tesla.com',
    'AMD': 'amd.com',
    'AVGO': 'broadcom.com',
    'NFLX': 'netflix.com',
    'INTC': 'intel.com',
    'QCOM': 'qualcomm.com',
    'CRM': 'salesforce.com',
    'ORCL': 'oracle.com',
    'ADBE': 'adobe.com',
    'PLTR': 'palantir.com',
    'SNOW': 'snowflake.com',
    'UBER': 'uber.com',
    'COIN': 'coinbase.com',
    'HOOD': 'robinhood.com',
    'PYPL': 'paypal.com',
    'SQ': 'block.xyz',
    'XYZ': 'block.xyz',
    'SHOP': 'shopify.com',
    'SPOT': 'spotify.com',
    'ARM': 'arm.com',
    'TSM': 'tsmc.com',
    'ASML': 'asml.com',
    'MU': 'micron.com',
    'SMCI': 'supermicro.com',
    'MRVL': 'marvell.com',
    'PANW': 'paloaltonetworks.com',
    'CRWD': 'crowdstrike.com',
    'NET': 'cloudflare.com',
    'DDOG': 'datadoghq.com',
    'JPM': 'jpmorganchase.com',
    'GS': 'goldmansachs.com',
    'MS': 'morganstanley.com',
    'BAC': 'bankofamerica.com',
    'V': 'visa.com',
    'MA': 'mastercard.com',
    'BRK.B': 'berkshirehathaway.com',
    'BRK.A': 'berkshirehathaway.com',
    'UNH': 'unitedhealthgroup.com',
    'LLY': 'lilly.com',
    'JNJ': 'jnj.com',
    'WMT': 'walmart.com',
    'COST': 'costco.com',
    'HD': 'homedepot.com',
    'MCD': 'mcdonalds.com',
    'DIS': 'thewaltdisneycompany.com',
    'KO': 'coca-colacompany.com',
    'PEP': 'pepsico.com',
    'XOM': 'exxonmobil.com',
    'CVX': 'chevron.com',
    'BA': 'boeing.com',
    'CAT': 'caterpillar.com',
    'GE': 'ge.com',
    'IBM': 'ibm.com',
    'CSCO': 'cisco.com',
    'TXN': 'ti.com',
    'NOW': 'servicenow.com',
    'INTU': 'intuit.com',
    'ABNB': 'airbnb.com',
    'RBLX': 'roblox.com',
    'SPY': 'ssga.com',
    'QQQ': 'invesco.com',
    'VOO': 'vanguard.com',
    'VTI': 'vanguard.com',
    'IWM': 'ishares.com',
    'DIA': 'ssga.com',
    'ARKK': 'ark-invest.com',
    'BTC': 'bitcoin.org',
    'BTCUSD': 'bitcoin.org',
    'BTCUSDT': 'bitcoin.org',
    'ETH': 'ethereum.org',
    'ETHUSD': 'ethereum.org',
    'SOL': 'solana.com',
    'BNB': 'bnbchain.org',
    'XRP': 'ripple.com',
    'ADA': 'cardano.org',
    'DOGE': 'dogecoin.com',
    'AVAX': 'avax.network',
    'LINK': 'chain.link',
    'RELIANCE': 'ril.com',
    'TCS': 'tcs.com',
    'HDFCBANK': 'hdfcbank.com',
    'INFY': 'infosys.com',
    'ICICIBANK': 'icicibank.com',
    'SBIN': 'sbi.co.in',
    'BHARTIARTL': 'airtel.in',
    'ITC': 'itcportal.com',
    'LT': 'larsentoubro.com',
    'AXISBANK': 'axisbank.com',
    'KOTAKBANK': 'kotak.com',
    'WIPRO': 'wipro.com',
    'TATAMOTORS': 'tatamotors.com',
    'BAJFINANCE': 'bajajfinserv.in',
    'MARUTI': 'marutisuzuki.com',
    'SUNPHARMA': 'sunpharma.com',
    'ZOMATO': 'zomato.com',
    'ETERNAL': 'zomato.com',
    'PAYTM': 'paytm.com',
    'NIFTY': 'nseindia.com',
    'NIFTY50': 'nseindia.com',
    'SENSEX': 'bseindia.com',
  };

  /// Extracts a normalized domain (`reuters.com`) from a URL or bare host.
  static String? extractDomain(String? raw) {
    final String value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    Uri? uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) {
      if (value.contains('.') && !value.contains(' ')) {
        uri = Uri.tryParse('https://$value');
      }
    }
    final String host = (uri?.host ?? '').toLowerCase().trim();
    if (host.isEmpty || !host.contains('.')) return null;
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  /// Resolves the official domain for a ticker symbol when known.
  static String? domainForTicker(String? ticker) {
    final String clean = (ticker ?? '')
        .trim()
        .replaceFirst(r'$', '')
        .replaceFirst(RegExp(r'\.(NS|BO)$', caseSensitive: false), '')
        .toUpperCase();
    if (clean.isEmpty) return null;
    return _tickerDomains[clean];
  }

  /// Resolves the best logo/favicon URL for an entity, link, or source.
  static String? resolveLogoUrl({
    String? explicitLogoUrl,
    String? url,
    String? domain,
    String? ticker,
    int size = 64,
  }) {
    final String explicit = (explicitLogoUrl ?? '').trim();
    if (explicit.startsWith('https://') ||
        explicit.startsWith('http://') ||
        explicit.startsWith('data:image/')) {
      return explicit;
    }
    final String? host =
        extractDomain(url) ?? extractDomain(domain) ?? domainForTicker(ticker);
    if (host == null || host.isEmpty) return null;
    return 'https://www.google.com/s2/favicons?domain=${Uri.encodeComponent(host)}&sz=$size';
  }
}

/// Crisp website favicon / brand logo with graceful monogram fallback.
class AppSiteLogo extends StatelessWidget {
  const AppSiteLogo({
    super.key,
    this.url,
    this.domain,
    this.explicitLogoUrl,
    this.ticker,
    this.label,
    this.size = 18,
    this.circular = false,
  });

  final String? url;
  final String? domain;
  final String? explicitLogoUrl;
  final String? ticker;
  final String? label;
  final double size;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final double dim = context.sz(size);
    final String? resolvedHost =
        SiteLogoResolver.extractDomain(url) ??
        SiteLogoResolver.extractDomain(domain) ??
        SiteLogoResolver.domainForTicker(ticker);
    final String? logoUrl = SiteLogoResolver.resolveLogoUrl(
      explicitLogoUrl: explicitLogoUrl,
      url: url,
      domain: domain,
      ticker: ticker,
      size: size >= 32 ? 128 : 64,
    );

    final String monogramSource = (label ?? resolvedHost ?? ticker ?? '')
        .trim()
        .replaceFirst(r'$', '');
    final String initial = monogramSource.isEmpty
        ? ''
        : monogramSource.substring(0, 1).toUpperCase();

    final Widget fallbackBadge = Container(
      width: dim,
      height: dim,
      color: theme.colors.primary.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: initial.isNotEmpty
          ? Text(
              initial,
              style: context.uiText.caption.copyWith(
                fontSize: (dim * 0.54).clamp(9.0, 16.0),
                fontWeight: FontWeight.w700,
                color: theme.colors.primary,
                height: 1,
              ),
            )
          : Icon(
              Icons.public_rounded,
              size: dim * 0.65,
              color: theme.colors.primary,
            ),
    );

    final BorderRadius radius = circular
        ? BorderRadius.circular(dim / 2)
        : context.radius(dim <= 20 ? 4 : theme.radii.sm);

    return Container(
      width: dim,
      height: dim,
      decoration: BoxDecoration(
        color: logoUrl != null ? Colors.white : theme.colors.surfaceMuted,
        borderRadius: radius,
        border: Border.all(
          color: theme.colors.border,
          width: theme.borders.hairline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: logoUrl == null
          ? fallbackBadge
          : UiRemoteImage(
              url: logoUrl,
              width: dim,
              height: dim,
              fit: BoxFit.contain,
              placeholder: fallbackBadge,
              fallback: fallbackBadge,
            ),
    );
  }
}

/// Clickable link pill showing the site's real favicon/logo and title/domain.
class AppSiteLinkChip extends StatelessWidget {
  const AppSiteLinkChip({
    super.key,
    required this.url,
    this.title,
    this.index,
    this.onTap,
    this.compact = true,
  });

  final String url;
  final String? title;
  final int? index;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String domain = SiteLogoResolver.extractDomain(url) ?? url;
    final String label = (title != null && title!.trim().isNotEmpty)
        ? title!.trim()
        : domain;

    return UiInteractive(
      onTap: onTap,
      tooltip: url,
      borderRadius: context.radius(theme.radii.pill),
      builder: (BuildContext ctx, UiInteractiveState state) => Container(
        padding: EdgeInsets.symmetric(
          horizontal: ctx.sp(compact ? theme.spacing.xs : theme.spacing.sm),
          vertical: ctx.sp(compact ? 4 : theme.spacing.xxs),
        ),
        decoration: BoxDecoration(
          color: state.hovered
              ? theme.colors.surfaceHover
              : theme.colors.surface,
          borderRadius: ctx.radius(theme.radii.pill),
          border: Border.all(
            color: state.hovered
                ? theme.colors.primary.withValues(alpha: 0.45)
                : theme.colors.border,
            width: theme.borders.hairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (index != null) ...<Widget>[
              Text(
                '$index',
                style: ctx.uiText.caption.copyWith(
                  fontSize: ctx.fs(10),
                  fontWeight: FontWeight.w700,
                  color: theme.colors.primary,
                ),
              ),
              UiGap.h(theme.spacing.xxs),
            ],
            AppSiteLogo(url: url, domain: domain, label: label, size: 15),
            UiGap.h(theme.spacing.xs),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: ctx.sz(200)),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ctx.uiText.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colors.foreground,
                ),
              ),
            ),
            if (onTap != null) ...<Widget>[
              UiGap.h(theme.spacing.xxs),
              Icon(
                Icons.north_east_rounded,
                size: ctx.sz(12),
                color: theme.colors.foregroundSubtle,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
