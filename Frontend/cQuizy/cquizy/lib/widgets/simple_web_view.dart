import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class SimpleWebViewPage extends StatefulWidget {
  final String url;
  final String title;

  const SimpleWebViewPage({
    super.key,
    required this.url,
    this.title = 'Webnézet',
  });

  @override
  State<SimpleWebViewPage> createState() => _SimpleWebViewPageState();
}

class _SimpleWebViewPageState extends State<SimpleWebViewPage> {
  WebViewController? _controller;
  WebviewController? _windowsController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    if (kIsWeb) return;

    if (Platform.isWindows) {
      _initWindowsController();
      return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) => setState(() => _isLoading = true),
          onPageFinished: (url) => setState(() => _isLoading = false),
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _initWindowsController() async {
    _windowsController = WebviewController();
    try {
      await _windowsController!.initialize();
      await _windowsController!.loadUrl(widget.url);
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Windows WebView error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_controller != null) {
                _controller!.reload();
              } else if (_windowsController != null) {
                _windowsController!.loadUrl(widget.url);
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (kIsWeb)
            const Center(child: Text('Webview not supported on web platform.'))
          else if (Platform.isWindows)
            _windowsController != null && _windowsController!.value.isInitialized
                ? Webview(_windowsController!)
                : const Center(child: CircularProgressIndicator())
          else
            WebViewWidget(controller: _controller!),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
