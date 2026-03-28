import 'package:isar/isar.dart';
import 'notebook.dart';
import 'tag.dart';

part 'note.g.dart';

@collection
class Note {
  Id id = Isar.autoIncrement;

  /// 기기 간 노트를 식별하는 전역 UUID
  @Index(unique: true, replace: true)
  String? syncId;

  late String title;

  late String body;

  bool isFavorite = false;

  DateTime createdAt = DateTime.now();

  DateTime updatedAt = DateTime.now();

  final notebook = IsarLink<Notebook>();

  final tags = IsarLinks<Tag>();
}
