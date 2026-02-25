import 'dart:io';

import 'package:flutter/material.dart';

BoxFit _fitForAspect(double width, double height) {
  return width >= height ? BoxFit.fitWidth : BoxFit.fitHeight;
}

class AppFileImage extends StatefulWidget {
  const AppFileImage({
    super.key,
    required this.file,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final File file;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  State<AppFileImage> createState() => _AppFileImageState();
}

class _AppFileImageState extends State<AppFileImage> {
  ImageStream? _imageStream;
  ImageStreamListener? _listener;
  BoxFit? _adaptiveFit;
  String? _resolvedPath;

  String get _currentPath => widget.file.path;

  BoxFit get _effectiveFit {
    if (widget.fit != BoxFit.cover) return widget.fit;
    return _adaptiveFit ?? BoxFit.contain;
  }

  void _resolveAdaptiveFit() {
    if (_resolvedPath == _currentPath) return;
    _removeImageListener();
    _resolvedPath = _currentPath;

    final provider = FileImage(widget.file);
    final stream = provider.resolve(const ImageConfiguration());
    _imageStream = stream;
    _listener = ImageStreamListener((imageInfo, _) {
      if (!mounted) return;
      final nextFit = _fitForAspect(
        imageInfo.image.width.toDouble(),
        imageInfo.image.height.toDouble(),
      );
      if (_adaptiveFit != nextFit) {
        setState(() => _adaptiveFit = nextFit);
      }
    });
    stream.addListener(_listener!);
  }

  void _syncAdaptiveResolution() {
    if (widget.fit != BoxFit.cover) {
      _removeImageListener();
      _adaptiveFit = null;
      return;
    }

    _resolveAdaptiveFit();
  }

  void _removeImageListener() {
    if (_imageStream != null && _listener != null) {
      _imageStream!.removeListener(_listener!);
    }
    _imageStream = null;
    _listener = null;
    _resolvedPath = null;
  }

  @override
  void dispose() {
    _removeImageListener();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _syncAdaptiveResolution();
  }

  @override
  void didUpdateWidget(covariant AppFileImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fit != widget.fit || oldWidget.file.path != widget.file.path) {
      _syncAdaptiveResolution();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Image.file(
      widget.file,
      width: widget.width,
      height: widget.height,
      fit: _effectiveFit,
    );
  }
}

class GrayscaleLogoPlaceholder extends StatelessWidget {
  const GrayscaleLogoPlaceholder({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.backgroundColor,
    this.padding = const EdgeInsets.all(14),
  });

  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? backgroundColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: backgroundColor ?? Colors.transparent,
      padding: padding,
      child: Image.asset(
        'assets/images/logo_bg.png',
        fit: fit,
      ),
    );
  }
}

class AppNetworkImage extends StatefulWidget {
  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.backgroundColor,
    this.placeholder,
  });

  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? backgroundColor;
  final Widget? placeholder;

  @override
  State<AppNetworkImage> createState() => _AppNetworkImageState();
}

class _AppNetworkImageState extends State<AppNetworkImage> {
  ImageStream? _imageStream;
  ImageStreamListener? _listener;
  BoxFit? _adaptiveFit;
  String? _resolvedUrl;

  String get _currentUrl => widget.imageUrl?.trim() ?? '';

  BoxFit get _effectiveFit {
    if (widget.fit != BoxFit.cover) return widget.fit;
    return _adaptiveFit ?? BoxFit.contain;
  }

  void _resolveAdaptiveFit(String url) {
    if (_resolvedUrl == url) return;
    _removeImageListener();
    _resolvedUrl = url;

    final provider = NetworkImage(url);
    final stream = provider.resolve(const ImageConfiguration());
    _imageStream = stream;
    _listener = ImageStreamListener((imageInfo, _) {
      if (!mounted) return;
      final nextFit = _fitForAspect(
        imageInfo.image.width.toDouble(),
        imageInfo.image.height.toDouble(),
      );
      if (_adaptiveFit != nextFit) {
        setState(() => _adaptiveFit = nextFit);
      }
    });
    stream.addListener(_listener!);
  }

  void _syncAdaptiveResolution() {
    if (widget.fit != BoxFit.cover || _currentUrl.isEmpty) {
      _removeImageListener();
      _adaptiveFit = null;
      return;
    }

    _resolveAdaptiveFit(_currentUrl);
  }

  void _removeImageListener() {
    if (_imageStream != null && _listener != null) {
      _imageStream!.removeListener(_listener!);
    }
    _imageStream = null;
    _listener = null;
    _resolvedUrl = null;
  }

  @override
  void dispose() {
    _removeImageListener();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _syncAdaptiveResolution();
  }

  @override
  void didUpdateWidget(covariant AppNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fit != widget.fit || oldWidget.imageUrl != widget.imageUrl) {
      _syncAdaptiveResolution();
    }
  }

  Widget _buildPlaceholder() {
    return widget.placeholder ?? GrayscaleLogoPlaceholder(
      width: widget.width,
      height: widget.height,
      fit: BoxFit.contain,
      backgroundColor: widget.backgroundColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = _currentUrl;
    if (url.isEmpty) {
      return _buildPlaceholder();
    }

    return Image.network(
      url,
      width: widget.width,
      height: widget.height,
      fit: _effectiveFit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _buildPlaceholder();
      },
      errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
    );
  }
}
