import 'package:flutter/material.dart';

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

class AppNetworkImage extends StatelessWidget {
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

  Widget _buildPlaceholder() {
    return placeholder ?? GrayscaleLogoPlaceholder(
      width: width,
      height: height,
      fit: BoxFit.contain,
      backgroundColor: backgroundColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    if (url.isEmpty) {
      return _buildPlaceholder();
    }

    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _buildPlaceholder();
      },
      errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
    );
  }
}
