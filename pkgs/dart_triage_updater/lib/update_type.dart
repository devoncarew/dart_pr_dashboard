import 'dart:convert';

import 'package:dart_triage_updater/pull_request_utils.dart';
import 'package:github/github.dart';

sealed class UpdateType<S, T> {
  const UpdateType();

  Object encode(T data);
  T decode(Object decoded);
  String get url;
  String get name;
  String key(S data);
}

final class IssueType extends UpdateType<Issue, Issue> {
  const IssueType();

  @override
  Issue decode(Object decoded) => _decodeIssue(decoded as Map<String, dynamic>);

  @override
  Map<String, dynamic> encode(Issue data) => _encodeIssue(data);

  @override
  String get name => 'issues';

  @override
  String get url => '$name/data';

  @override
  String key(Issue data) => data.id.toString();
}

final class PullRequestType extends UpdateType<PullRequest, PullRequest> {
  const PullRequestType();

  @override
  PullRequest decode(Object decoded) =>
      _decodePR(decoded as Map<String, dynamic>);

  @override
  Map<String, dynamic> encode(PullRequest data) => _encodePR(data);

  @override
  String get name => 'pullrequests';

  @override
  String get url => '$name/data';

  @override
  String key(PullRequest data) => data.id.toString();
}

final class TimelineType<S, T> extends UpdateType<S, List<TimelineEvent>> {
  final UpdateType<S, T> parent;

  const TimelineType(this.parent);

  @override
  List<TimelineEvent> decode(Object decoded) =>
      _decodeTimeline(decoded as List);

  @override
  List encode(List<TimelineEvent> data) => _encodeTimeline(data);

  @override
  String get name => 'timeline';

  @override
  String get url {
    return '${parent.name}/timeline';
  }

  @override
  String key(S data) => parent.key(data);
}

final class IssueTestType extends IssueType {
  const IssueTestType();

  @override
  Issue decode(Object decoded) => _decodeIssue(decoded as Map<String, dynamic>);

  @override
  Map<String, dynamic> encode(Issue data) => _encodeIssue(data);

  @override
  String get name => 'testType';

  @override
  String get url => '$name/data';

  @override
  String key(Issue data) => data.id.toString();
}

final class PullRequestTestType extends PullRequestType {
  const PullRequestTestType();

  @override
  PullRequest decode(Object decoded) =>
      _decodePR(decoded as Map<String, dynamic>);

  @override
  Map<String, dynamic> encode(PullRequest data) => _encodePR(data);

  @override
  String get name => 'testTypePR';

  @override
  String get url => '$name/data';

  @override
  String key(PullRequest data) => data.id.toString();
}

Map<String, dynamic> _encodePR(PullRequest pr) {
  final map = jsonDecode(jsonEncode(pr)) as Map<String, dynamic>;
  map['reviewers'] = pr.reviewers;
  if (map['base']?['repo']?['url'] != null) {
    map['base']?['repo'] = {'url': map['base']?['repo']?['url']};
  }
  if (map['head']?['repo']?['url'] != null) {
    map['head']?['repo'] = {'url': map['head']?['repo']?['url']};
  }
  map.remove('body');

  if (map['head']?['user']?['login'] != null) {
    map['head']?['user'] = {'login': map['head']?['user']?['login']};
  }
  if (map['base']?['user']?['login'] != null) {
    map['base']?['user'] = {'login': map['base']?['user']?['login']};
  }
  if (map['user']?['login'] != null) {
    map['user'] = {'login': map['user']?['login']};
  }
  if (map['merged_by']?['login'] != null) {
    map['merged_by'] = {'login': map['merged_by']?['login']};
  }
  if (map['reviewers'] != null) {
    map['reviewers'] = (map['reviewers'] as List).map((e) {
      e as User;
      if (e.login != null) {
        return {'login': e.login};
      } else {
        return e;
      }
    }).toList();
  }
  if (map['labels'] != null) {
    map['labels'] = (map['labels'] as List)
        .map((e) => {'name': (e as Map)['name'] ?? ''})
        .toList();
  }

  return map;
}

PullRequest _decodePR(Map<String, dynamic> decoded) {
  final decodedReviewers = decoded['reviewers'] as List?;
  final pr = PullRequest.fromJson(decoded);
  pr.reviewers = decodedReviewers?.map((e) => User.fromJson(e)).toList() ?? [];
  pr.requestedReviewers?.removeWhere((requestedReviewer) => pr.reviewers
      .any((reviewer) => reviewer.login == requestedReviewer.login));
  return pr;
}

List _encodeTimeline(List<TimelineEvent> timelineEvent) {
  return timelineEvent.map((e) {
    final map = jsonDecode(jsonEncode(e)) as Map<String, dynamic>;
    map['created_at'] = e.createdAt?.millisecondsSinceEpoch;
    map.remove('body');
    if (map['actor']?['login'] != null) {
      map['actor'] = {'login': map['actor']?['login']};
    }
    if (map['assignee']?['login'] != null) {
      map['assignee'] = {'login': map['assignee']?['login']};
    }
    if (map['user']?['login'] != null) {
      map['user'] = {'login': map['user']?['login']};
    }
    return map;
  }).toList();
}

List<TimelineEvent> _decodeTimeline(List decoded) {
  return decoded.map((e) {
    final map = e as Map<String, dynamic>;
    if (map['created_at'] != null) {
      map['created_at'] = DateTime.fromMillisecondsSinceEpoch(map['created_at'])
          .toIso8601String();
    }
    return TimelineEvent.fromJson(map);
  }).toList();
}

Issue _decodeIssue(Map<String, dynamic> decoded) {
  setField(decoded, 'created_at',
      (int v) => DateTime.fromMillisecondsSinceEpoch(v).toIso8601String());
  setField(decoded, 'closed_at',
      (int v) => DateTime.fromMillisecondsSinceEpoch(v).toIso8601String());
  setField(decoded, 'updated_at',
      (int v) => DateTime.fromMillisecondsSinceEpoch(v).toIso8601String());
  setField(decoded, 'user', (String v) => jsonEncode(User(login: v)));
  return Issue.fromJson(decoded);
}

void setField<T>(
    Map<String, dynamic> decoded, String key, Object Function(T v) value) {
  if (decoded[key] != null) {
    decoded[key] = value(decoded[key]);
  }
}

Map<String, dynamic> _encodeIssue(Issue issue) {
  final map = jsonDecode(jsonEncode(issue)) as Map<String, dynamic>;
  map['created_at'] = issue.createdAt?.millisecondsSinceEpoch;
  map['closed_at'] = issue.closedAt?.millisecondsSinceEpoch;
  map['updated_at'] = issue.updatedAt?.millisecondsSinceEpoch;
  map['user'] = {'login': issue.user?.login};
  map.remove('body');
  return map;
}
