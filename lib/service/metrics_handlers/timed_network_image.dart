// import 'package:flutter/material.dart';
// import 'package:perform_test/data/model/photo.dart';
// import 'package:perform_test/presentation/profile/widgets/photo_list_item.dart';
// import 'package:perform_test/service/metrics_handlers/agregator.dart';

// class TimedNetworkImage extends StatefulWidget {
//   final String url;
//   final double aspectRatio;
//   final int? cacheWidth;
//   final int? cacheHeight;
//   final void Function(int renderTimeMs, int sizeBytes)? onImageInfo;
//   final bool isLogged;

//   const TimedNetworkImage({
//     super.key,
//     required this.url,
//     required this.aspectRatio,
//     this.cacheWidth,
//     this.cacheHeight,
//     this.onImageInfo,
//     this.isLogged = false,
//   });

//   @override
//   State<TimedNetworkImage> createState() => _TimedNetworkImageState();
// }

// class _TimedNetworkImageState extends State<TimedNetworkImage> {
//   @override
//   Widget build(BuildContext context) {
//     final image = Image.network(
//       widget.url,
//       cacheWidth: widget.cacheWidth,
//       cacheHeight: widget.cacheHeight,
//       fit: BoxFit.cover,
//     );

//     final stream = image.image.resolve(const ImageConfiguration());
//     stream.addListener(
//       ImageStreamListener((info, _) async {
//         if (widget.isLogged) {
//           final decodeDone = DateTime.now();

//           await WidgetsBinding.instance.endOfFrame;
//           final renderDone = DateTime.now();

//           final renderMs = renderDone.difference(decodeDone).inMilliseconds;
//           debugPrint(
//             "Image sizy bytes ${info.sizeBytes} \n"
//             "decoded(${info.image.width}x${info.image.height}) \n"
//             "rendered after ${renderMs}ms \n",
//           );

//           widget.onImageInfo?.call(renderMs, info.sizeBytes);
//         }
//       }),
//     );

//     return AspectRatio(aspectRatio: widget.aspectRatio, child: image);
//   }
// }

// final metrics = ImageMetricsAggregator(targetCount: 50);

// class MetricListItem extends StatelessWidget {
//   final Photo photo;
//   final int index;

//   MetricListItem({super.key, required this.photo, required this.index});

//   final _buildStart = DateTime.now();

//   @override
//   Widget build(BuildContext context) {
//     return PhotoListItem(
//       photo: photo,
//       onImageInfo: (renderTimeMs, sizeBytes) {
//         final visibleAfterMs = DateTime.now()
//             .difference(_buildStart)
//             .inMilliseconds;

//         metrics.add(
//           visibleAfterMs: visibleAfterMs,
//           renderTimeMs: renderTimeMs,
//           sizeBytes: sizeBytes,
//         );
//       },
//     );
//   }
// }
