import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:webfeed/webfeed.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RSS 阅读器',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const RssFeedScreen(),
    );
  }
}

class RssFeedScreen extends StatefulWidget {
  const RssFeedScreen({Key? key}) : super(key: key);

  @override
  State<RssFeedScreen> createState() => _RssFeedScreenState();
}

class _RssFeedScreenState extends State<RssFeedScreen> {
  late Future<List<FeedEntry>> _feedEntries;
  final String rssUrl = 'https://sspai.com/feed';
  static const Map<String, String> _htmlRequestHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    'Referer': 'https://sspai.com/',
  };
  static const Map<String, String> _imageRequestHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36',
    'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
    'Referer': 'https://sspai.com/',
  };

  @override
  void initState() {
    super.initState();
    _feedEntries = fetchFeedEntries(rssUrl);
  }

  Future<RssFeed?> fetchRssFeed(String url) async {
    final response =
        await http.get(Uri.parse(url), headers: _htmlRequestHeaders);
    if (response.statusCode == 200) {
      return RssFeed.parse(response.body);
    } else {
      return null;
    }
  }

  Future<List<FeedEntry>> fetchFeedEntries(String url) async {
    final feed = await fetchRssFeed(url);
    if (feed == null || feed.items == null) {
      return [];
    }

    final items = feed.items!;
    final futures = items.map((item) async {
      final thumb = await _resolveThumbnail(item);
      return FeedEntry(item: item, thumbnailUrl: thumb);
    }).toList();
    return Future.wait(futures);
  }

  Future<String?> _resolveThumbnail(RssItem item) async {
    // 优先使用 enclosure 中的资源
    final enclosureUrl = item.enclosure?.url;
    if (enclosureUrl != null && enclosureUrl.isNotEmpty) {
      return enclosureUrl;
    }

    final link = item.link;
    if (link == null || link.isEmpty) {
      return null;
    }

    try {
      final response =
          await http.get(Uri.parse(link), headers: _htmlRequestHeaders);
      if (response.statusCode == 200) {
        final body = response.body;
        final metaMatch = RegExp(
          "<meta[^>]+(?:property|name)=[\"']og:image[\"'][^>]*>",
          caseSensitive: false,
        ).firstMatch(body);

        if (metaMatch != null) {
          final contentMatch = RegExp(
            "content=[\"']([^\"']+)[\"']",
            caseSensitive: false,
          ).firstMatch(metaMatch.group(0)!);
          if (contentMatch != null) {
            return contentMatch.group(1);
          }
        }

        final twitterMatch = RegExp(
          "<meta[^>]+(?:property|name)=[\"']twitter:image[\"'][^>]*>",
          caseSensitive: false,
        ).firstMatch(body);

        if (twitterMatch != null) {
          final contentMatch = RegExp(
            "content=[\"']([^\"']+)[\"']",
            caseSensitive: false,
          ).firstMatch(twitterMatch.group(0)!);
          if (contentMatch != null) {
            return contentMatch.group(1);
          }
        }
      }
    } catch (_) {
      // 忽略抓取失败，继续返回空结果
    }

    return null;
  }

  void _openWebview(BuildContext context, String url, String title) {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => WebViewPage(url: url, title: title),
      transitionDuration: const Duration(milliseconds: 0),
      reverseTransitionDuration: const Duration(milliseconds: 0),
      transitionsBuilder: (_, __, ___, child) => child,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('少数派 RSS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () {
              setState(() {
                _feedEntries = fetchFeedEntries(rssUrl);
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<List<FeedEntry>>(
        future: _feedEntries,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            final errorMsg = snapshot.error.toString();
            return Center(child: Text('错误: $errorMsg'));
          } else if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('暂无数据'));
          } else {
            final items = snapshot.data!;
            if (items.isEmpty) {
              return const Center(child: Text('暂无数据'));
            }
            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final entry = items[index];
                final item = entry.item;
                return Card(
                  margin:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  child: InkWell(
                    onTap: item.link != null
                        ? () =>
                            _openWebview(context, item.link!, item.title ?? '')
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (entry.thumbnailUrl != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 96,
                                    height: 96,
                                    child: Image.network(
                                      entry.thumbnailUrl!,
                                      headers: _imageRequestHeaders,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.black12,
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.image_not_supported,
                                        ),
                                      ),
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                        if (loadingProgress == null) {
                                          return child;
                                        }
                                        return Container(
                                          color: Colors.black12,
                                          alignment: Alignment.center,
                                          child: const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              if (entry.thumbnailUrl != null)
                                const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title ?? '无标题',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item.description?.replaceAll(
                                              RegExp(r'<[^>]*>'), '') ??
                                          '无描述',
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '作者: ${item.author ?? item.dc?.creator ?? '未知'}',
                                  style: const TextStyle(
                                      color: Colors.black54, fontSize: 13),
                                ),
                              ),
                              Text(
                                item.pubDate?.toString() ?? '无时间',
                                style: const TextStyle(
                                    color: Colors.black54, fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}

class FeedEntry {
  final RssItem item;
  final String? thumbnailUrl;

  FeedEntry({required this.item, this.thumbnailUrl});
}

class WebViewPage extends StatefulWidget {
  final String url;
  final String title;

  const WebViewPage({super.key, required this.url, required this.title});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  InAppWebViewController? _webViewController;

  Future<bool> _onWillPop() async {
    if (_webViewController != null && await _webViewController!.canGoBack()) {
      await _webViewController!.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (_webViewController != null &&
                  await _webViewController!.canGoBack()) {
                await _webViewController!.goBack();
              } else {
                if (mounted) Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(widget.url)),
          initialOptions: InAppWebViewGroupOptions(
            android: AndroidInAppWebViewOptions(
              useHybridComposition: true,
            ),
          ),
          onWebViewCreated: (controller) {
            _webViewController = controller;
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _webViewController = null;
    super.dispose();
  }
}
