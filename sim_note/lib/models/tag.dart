import 'package:isar/isar.dart';
import 'note.dart';

part 'tag.g.dart';

@collection
class Tag {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String name;

  @Backlink(to: 'tags')
  final notes = IsarLinks<Note>();
}
