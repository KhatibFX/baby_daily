import 'dart:io';
import 'package:flutter/material.dart';

class PhotoView extends StatelessWidget {
  final String photoPath;
  final String? title;
  final double previewHeight;
  final BoxFit previewFit;

  const PhotoView({
    required this.photoPath,
    this.title,
    this.previewHeight = 200,
    this.previewFit = BoxFit.cover,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: File(photoPath).exists(),
      builder: (context, snapshot) {
        if (snapshot.data == true) {
          return Column(
            children: [
              SizedBox(height: 8),
              if (title != null && title!.isNotEmpty)
                Text(
                  title!,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => _FullScreenPhoto(photoPath: photoPath),
                      fullscreenDialog: true,
                    ),
                  );
                },
                child: Hero(
                  tag: photoPath,
                  child: Image.file(
                    File(photoPath),
                    height: previewHeight,
                    width: double.infinity,
                    fit: previewFit,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: previewHeight,
                        width: double.infinity,
                        color: Colors.grey[300],
                        child: Center(child: Text('Failed to load image')),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        }
        return SizedBox.shrink();
      },
    );
  }
}

class _FullScreenPhoto extends StatelessWidget {
  final String photoPath;

  const _FullScreenPhoto({
    required this.photoPath,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Hero(
                      tag: photoPath,
                      child: Image.file(
                        File(photoPath),
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Text(
                              'Failed to load image',
                              style: TextStyle(color: Colors.white),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 8, // Reduced top padding since we're in SafeArea now
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
