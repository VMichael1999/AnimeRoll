class EpisodeModel {
  final String title;
  final String url;
  final String? thumbnail;
  final int? number;
  final String? duration;

  const EpisodeModel({
    required this.title,
    required this.url,
    this.thumbnail,
    this.number,
    this.duration,
  });

  factory EpisodeModel.fromJson(Map<String, dynamic> json) => EpisodeModel(
    title: json['title'] as String? ?? '',
    url: json['url'] as String? ?? '',
    thumbnail:
        json['thumbnail'] as String? ??
        json['image'] as String? ??
        json['cover'] as String?,
    number: (json['number'] as num?)?.toInt(),
    duration: json['duration'] as String?,
  );
}

class VideoServerModel {
  final String name;
  final String url;
  final String? quality;
  final bool isHls;

  const VideoServerModel({
    required this.name,
    required this.url,
    this.quality,
    this.isHls = false,
  });

  factory VideoServerModel.fromJson(Map<String, dynamic> json) =>
      VideoServerModel(
        name: json['server'] as String? ?? json['name'] as String? ?? '',
        url: json['url'] as String? ?? '',
        quality: json['quality'] as String?,
        isHls:
            json['isHls'] as bool? ??
            (json['url'] as String? ?? '').contains('.m3u8'),
      );
}
