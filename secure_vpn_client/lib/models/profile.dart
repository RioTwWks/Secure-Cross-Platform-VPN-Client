enum ProfileType { link, subscription }

class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.configLink,
    this.type = ProfileType.link,
  });

  final String id;
  final String name;
  final String configLink;
  final ProfileType type;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'configLink': configLink,
        'type': type.name,
      };

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      name: json['name'] as String,
      configLink: json['configLink'] as String,
      type: ProfileType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => ProfileType.link,
      ),
    );
  }

  Profile copyWith({
    String? id,
    String? name,
    String? configLink,
    ProfileType? type,
  }) {
    return Profile(
      id: id ?? this.id,
      name: name ?? this.name,
      configLink: configLink ?? this.configLink,
      type: type ?? this.type,
    );
  }
}
