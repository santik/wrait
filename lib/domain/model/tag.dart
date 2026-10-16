class Tag {
  const Tag({required this.id, required this.name});

  final int id;
  final String name;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is Tag && other.id == id && other.name == name);
  }

  @override
  int get hashCode => Object.hash(id, name);
}
