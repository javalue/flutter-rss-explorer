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
  late Future<RssFeed?> _rssFeed;
  final String rssUrl = 'https://sspai.com/feed';

  @override
  void initState() {
    super.initState();
    _rssFeed = fetchRssFeed(rssUrl);
  }

  Future<RssFeed?> fetchRssFeed(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return RssFeed.parse(response.body);
    } else {
      return null;
    }
  }

  void _openWebview(BuildContext context, String url, String title) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WebViewPage(url: url, title: title),
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
                _rssFeed = fetchRssFeed(rssUrl);
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<RssFeed?>(
        future: _rssFeed,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            final errorMsg = snapshot.error.toString();
            return Center(child: Text('错误: $errorMsg'));
          } else if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('暂无数据'));
          } else {
            final feed = snapshot.data!;
            return ListView.builder(
              itemCount: feed.items?.length ?? 0,
              itemBuilder: (context, index) {
                final item = feed.items![index];
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
                          Text(
                            item.title ?? '无标题',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.description
                                    ?.replaceAll(RegExp(r'<[^>]*>'), '') ??
                                '无描述',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
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
          onWebViewCreated: (controller) {
            _webViewController = controller;
          },
        ),
      ),
    );
  }
}
