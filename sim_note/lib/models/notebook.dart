import 'package:isar/isar.dart';
import 'note.dart';

part 'notebook.g.dart';

@collection
class Notebook {
  Id id = Isar.autoIncrement;

  late String name;

  DateTime createdAt = DateTime.now();

  @Backlink(to: 'notebook')
  final notes = IsarLinks<Note>();
}
