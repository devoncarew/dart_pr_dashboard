import 'package:github/github.dart';

final noTime = DateTime.fromMillisecondsSinceEpoch(0);
const gWithCircle = '\u24BC';

String daysSince(DateTime? dt) {
  if (dt == null) return '';
  final d = DateTime.now().difference(dt);
  return d.inDays.toString();
}

String formatUsername(User? user, List<User> googlers) {
  final googlerMark = googlers.any((googler) => googler.login == user?.login)
      ? gWithCircle
      : '';
  final userName = user?.login ?? '';
  return userName + googlerMark;
}
