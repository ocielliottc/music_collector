import 'package:elite_orm/elite_orm.dart';

class Album extends Entity<Album> {
  Album([artist = "", name = "", DateTime? release, Duration? length])
      : super(Album.new) {
    // The composite primary key is artist and name.
    members.add(DBMember<String>("artist", artist, true));
    members.add(DBMember<String>("name", name, true));
    members.add(DateTimeDBMember("release", release ?? DateTime.now()));
    members.add(DurationDBMember("length", length ?? const Duration()));
  }

  // Accessors.
  String get artist => members[0].value;
  String get name => members[1].value;
  DateTime get release => members[2].value;
  Duration get length => members[3].value;
}
