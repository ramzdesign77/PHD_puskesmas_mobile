class Village {
  const Village({required this.id, required this.name});

  final int id;
  final String name;

  factory Village.fromJson(Map<String, dynamic> json) {
    return Village(
      id: json['id_desa'] as int,
      name: json['nama_desa'] as String? ?? '',
    );
  }
}
