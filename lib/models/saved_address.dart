class SavedAddress {
  const SavedAddress({
    required this.villageId,
    required this.rt,
    required this.rw,
    required this.detail,
    this.villageName,
  });

  final int villageId;
  final String rt;
  final String rw;
  final String detail;
  final String? villageName;

  Map<String, dynamic> toJson() => {
    'id_desa': villageId,
    'rt': rt,
    'rw': rw,
    'alamat_detail': detail,
  };
}
