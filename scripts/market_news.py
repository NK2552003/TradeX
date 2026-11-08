"""Normalize publisher metadata without invented timestamps or stock photos."""

import html
import ipaddress
import re
import socket
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
from html.parser import HTMLParser


# These six images were inserted by the previous pipeline as generic stand-ins.
LEGACY_PHOTO_IDS = (
    'photo-1621416894569-0f39ed31d247', 'photo-1618005182384-a83a8bd57fbe',
    'photo-1541354329998-f4d9a9f9297f', 'photo-1576091160399-112ba8d25d1d',
    'photo-1473341304170-971dccb5ac1e', 'photo-1611974789855-9c2a0a7236a3',
)


def legacy_image(url):
    return any(f'images.unsplash.com/{photo}' in (url or '') for photo in LEGACY_PHOTO_IDS)


def web_url(value, base=""):
    if not isinstance(value, str) or not value.strip():
        return None
    url = urllib.parse.urljoin(base, html.unescape(value.strip()))
    parts = urllib.parse.urlsplit(url)
    if parts.scheme not in ("https", "http") or not parts.hostname or parts.username:
        return None
    return url


def published_iso(value):
    try:
        if isinstance(value, (int, float)):
            dt = datetime.fromtimestamp(value, timezone.utc)
        else:
            try:
                dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
            except (ValueError, AttributeError):
                dt = parsedate_to_datetime(value)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(timezone.utc).isoformat()
    except (ValueError, TypeError, OverflowError, AttributeError):
        return None


def plain_text(value):
    return re.sub(r"\s+", " ", re.sub(r"<[^>]*>", " ", html.unescape(value or ""))).strip()


def yahoo_article(item):
    data = item.get("content") or item
    link = web_url(data.get("link") or (data.get("canonicalUrl") or {}).get("url")
                   or (data.get("clickThroughUrl") or {}).get("url"))
    title = plain_text(data.get("title"))
    published = published_iso(data.get("pubDate") or data.get("providerPublishTime"))
    if not link or not title or not published:
        return None
    thumb = data.get("thumbnail") or {}
    images = sorted(thumb.get("resolutions") or [], key=lambda r: (
        r.get("tag") == "original", (r.get("width") or 0) * (r.get("height") or 0)), reverse=True)
    image = next((web_url(r.get("url")) for r in images if web_url(r.get("url"))), None)
    image = image or web_url(thumb.get("originalUrl")) or web_url(thumb.get("url"))
    related = data.get("relatedTickers") or item.get("relatedTickers") or []
    return {
        "title": title, "link": link,
        "summary": plain_text(data.get("summary") or data.get("description")) or None,
        "publisher": data.get("publisher") or (data.get("provider") or {}).get("displayName"),
        "thumbnail_url": image,
        "content_type": data.get("contentType") or data.get("type") or "STORY",
        "published_at": published,
        "_related_tickers": [t for t in related if isinstance(t, str)],
    }


class ArticleMetadata(HTMLParser):
    def __init__(self):
        super().__init__()
        self.meta = {}
        self.images = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "meta":
            name = (attrs.get("property") or attrs.get("name") or "").lower()
            if attrs.get("content"):
                self.meta.setdefault(name, attrs["content"])
        elif tag == "img" and attrs.get("src"):
            self.images.append(attrs["src"])


def rss_articles(payload, publisher):
    root = ET.fromstring(payload)
    articles = []
    for item in root.findall(".//item")[:30]:
        title = plain_text(item.findtext("title"))
        link = web_url(item.findtext("link"))
        published = published_iso(item.findtext("pubDate"))
        if not title or not link or not published:
            continue
        description = item.findtext("description") or ""
        parser = ArticleMetadata()
        parser.feed(html.unescape(description))
        candidates = [e.get("url") for e in item.iter()
                      if e.tag.rsplit("}", 1)[-1] in ("thumbnail", "content", "enclosure")
                      and (e.get("medium") == "image" or (e.get("type") or "").startswith("image/")
                           or e.tag.endswith("thumbnail"))]
        candidates += parser.images
        image = next((web_url(c, link) for c in candidates if web_url(c, link)), None)
        articles.append({
            "title": title, "link": link, "summary": plain_text(description) or None,
            "publisher": publisher, "thumbnail_url": image, "content_type": "STORY",
            "published_at": published, "_related_tickers": [],
        })
    return articles


def merge_articles(articles):
    merged = {}
    for article in articles:
        link = article["link"]
        previous = merged.get(link, {})
        related = sorted(set(previous.get("_related_tickers", []) + article.get("_related_tickers", [])))
        merged[link] = {**previous, **{k: v for k, v in article.items() if v not in (None, "", [])},
                        "_related_tickers": related}
    return list(merged.values())


def _public_url(url):
    url = web_url(url)
    if not url:
        raise ValueError("Invalid publisher URL")
    parts = urllib.parse.urlsplit(url)
    if parts.port not in (None, 80, 443):
        raise ValueError("Invalid publisher port")
    addresses = socket.getaddrinfo(parts.hostname, parts.port or 443, type=socket.SOCK_STREAM)
    if not addresses or any(not ipaddress.ip_address(a[4][0]).is_global for a in addresses):
        raise ValueError("Publisher address is not public")
    return url


class PublicRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return super().redirect_request(req, fp, code, msg, headers, _public_url(newurl))


def enrich_article(article):
    """Read only public publisher HTML; limit redirects, bytes and timeout."""
    result = dict(article)
    if result.get("thumbnail_url") and result.get("summary"):
        return result
    try:
        url = _public_url(result["link"])
        request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0", "Accept": "text/html"})
        with urllib.request.build_opener(PublicRedirect()).open(request, timeout=8) as response:
            if "text/html" not in response.headers.get("Content-Type", ""):
                return result
            parser = ArticleMetadata()
            parser.feed(response.read(512_000).decode("utf-8", errors="replace"))
            final_url = response.geturl()
        image = next((web_url(parser.meta.get(key), final_url)
                      for key in ("og:image:secure_url", "og:image", "twitter:image", "twitter:image:src")
                      if web_url(parser.meta.get(key), final_url)), None)
        if not result.get("thumbnail_url") and image:
            result["thumbnail_url"] = image
        if not result.get("summary"):
            result["summary"] = plain_text(parser.meta.get("og:description") or parser.meta.get("description")) or None
    except (OSError, ValueError):
        pass  # A publisher can decline scraping; keep its headline and real metadata.
    return result
