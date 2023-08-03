import 'dart:convert';

import 'package:dart_triage_updater/update_type.dart';
import 'package:github/github.dart';
import 'package:http/http.dart' as http;

final firebaseUrl =
    'https://dart-pr-dashboard-default-rtdb.europe-west1.firebasedatabase.app/';

final firebaseApiKey = 'AIzaSyDWQNcIH4Rdur4HNvGolFvWUBymNqT5RAY';

class AuthRequest {
  final String email;
  final String password;
  final bool returnSecureToken;
  AuthRequest({
    required this.email,
    required this.password,
    required this.returnSecureToken,
  });

  AuthRequest copyWith({
    String? email,
    String? password,
    bool? returnSecureToken,
  }) {
    return AuthRequest(
      email: email ?? this.email,
      password: password ?? this.password,
      returnSecureToken: returnSecureToken ?? this.returnSecureToken,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'password': password,
      'returnSecureToken': returnSecureToken,
    };
  }

  factory AuthRequest.fromMap(Map<String, dynamic> map) {
    return AuthRequest(
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      returnSecureToken: map['returnSecureToken'] ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory AuthRequest.fromJson(String source) =>
      AuthRequest.fromMap(json.decode(source));

  @override
  String toString() =>
      'AuthRequest(email: $email, password: $password, returnSecureToken: $returnSecureToken)';
}

class AuthResponse {
  String idToken;
  String email;
  String refreshToken;
  String expiresIn;
  String localId;
  bool registered;
  final _receivedAt = DateTime.now();

  DateTime get _expiresAt =>
      _receivedAt.add(Duration(seconds: int.parse(expiresIn)));

  bool get willExpireSoon =>
      DateTime.now().add(Duration(seconds: 30)).isAfter(_expiresAt);

  AuthResponse({
    required this.idToken,
    required this.email,
    required this.refreshToken,
    required this.expiresIn,
    required this.localId,
    required this.registered,
  });
  Map<String, dynamic> toMap() {
    return {
      'idToken': idToken,
      'email': email,
      'refreshToken': refreshToken,
      'expiresIn': expiresIn,
      'localId': localId,
      'registered': registered,
    };
  }

  factory AuthResponse.fromMap(Map<String, dynamic> map) {
    return AuthResponse(
      idToken: map['idToken'] ?? '',
      email: map['email'] ?? '',
      refreshToken: map['refreshToken'] ?? '',
      expiresIn: map['expiresIn'] ?? '',
      localId: map['localId'] ?? '',
      registered: map['registered'] ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory AuthResponse.fromJson(String source) =>
      AuthResponse.fromMap(json.decode(source));

  @override
  String toString() {
    return 'AuthResponse(idToken: $idToken, email: $email, refreshToken: $refreshToken, expiresIn: $expiresIn, localId: $localId, registered: $registered)';
  }
}

class DatabaseReference {
  final AuthRequest? authRequest;
  AuthResponse? authResponse;

  String? id;

  DatabaseReference([this.authRequest]);

  Future<void> signIn() async {
    if (authRequest != null) {
      final uri = Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword');
      final response = await http.post(
        uri,
        body: <String, String>{
          'key': firebaseApiKey,
          ...authRequest!.toMap().map((k, v) => MapEntry(k, v.toString()))
        },
      );
      if (response.statusCode != 200) {
        throw Exception('Error in signin: ${response.body}');
      }
      authResponse = AuthResponse.fromJson(response.body);
    }
  }

  Future<void> addData<S, T>(UpdateType<S, T> type, S element, T data) async {
    await sendRequest(
      (uri, d) async => await http.patch(uri, body: d),
      Uri.parse('$firebaseUrl${type.url}.json'),
      jsonEncode({type.key(element): type.encode(data)}),
    );
  }

  Future<void> saveGooglers(List googlers) async {
    await sendRequest(
      (uri, data) async => await http.patch(uri, body: data),
      Uri.parse('$firebaseUrl.json'),
      jsonEncode({'googlers': googlers}),
    );
  }

  Future<void> setLastUpdated(RepositorySlug slug) async {
    final uri = Uri.parse('${firebaseUrl}last_updated.json');
    final lastUpdated =
        DateTime.now().subtract(Duration(hours: 1)).millisecondsSinceEpoch;
    await sendRequest(
      (uri, data) async => await http.patch(uri, body: data),
      uri,
      jsonEncode({slug.toUrl(): lastUpdated}),
    );
  }

  Future<Map<RepositorySlug, DateTime?>> getLastUpdated() async {
    final uri = Uri.parse('${firebaseUrl}last_updated.json');
    final response =
        await sendRequest((url, _) async => await http.get(url), uri);
    final map = (jsonDecode(response.body) ?? <String, dynamic>{})
        as Map<String, dynamic>;
    return map.map((key, value) => MapEntry(
        RepositorySlugExtension.fromUrl(key),
        DateTime.fromMillisecondsSinceEpoch(value)));
  }

  Future<List<TimelineEvent>> getTimeline(UpdateType type, int id) async {
    final uri = Uri.parse('$firebaseUrl${type.name}/timeline/$id.json');
    final response =
        await sendRequest((url, _) async => await http.get(url), uri);
    final list = (jsonDecode(response.body) ?? []) as List;
    return list.map((e) => TimelineEvent.fromJson(e)).toList();
  }

  Future<http.Response> sendRequest(
    Future<http.Response> Function(Uri, Object?) request,
    Uri uri, [
    String? data,
  ]) async {
    http.Response response;
    if (authRequest != null) {
      if (authResponse == null || authResponse!.willExpireSoon) {
        await signIn();
      }
      final uriWithAuth =
          uri.replace(queryParameters: {'auth': authResponse!.idToken});
      response = await request(uriWithAuth, data);
    } else {
      response = await request(uri, data);
    }

    if (response.statusCode != 200) {
      throw Exception('Error ${response.statusCode} - ${response.body}');
    }
    return response;
  }

  static List<T> extractDataFrom<S, T>(
    Map<String, dynamic> idsToData,
    UpdateType<S, T> fromJson,
  ) {
    final list = <T>[];
    for (final idToData in idsToData.entries) {
      // ignore: unused_local_variable
      final id = idToData.key;
      final data = fromJson.decode(idToData.value);
      list.add(data);
    }
    return list;
  }

  Future<List<T>> getCreatedBetween<S, T>({
    required UpdateType<S, T> type,
    required DateTime from,
    required DateTime to,
  }) async {
    final list = <T>[];
    final uri =
        Uri.parse('$firebaseUrl${type.url}.json').replace(queryParameters: {
      'orderBy': 'createdAt',
      'startAt': from.millisecondsSinceEpoch,
      'endAt': to.millisecondsSinceEpoch,
    });
    final response =
        await sendRequest((p0, _) async => await http.get(uri), uri);
    print(response.body);
    return list;
  }
}

extension RepositorySlugExtension on RepositorySlug {
  String toUrl() {
    final ownerClean = owner.replaceAll(r'.', r',');
    final nameClean = name.replaceAll(r'.', r',');
    return '$ownerClean:$nameClean';
  }

  static RepositorySlug fromUrl(String url) {
    final split = url.split(':');
    final owner = split[0];
    final name = split[1];
    return RepositorySlug(
        owner.replaceAll(r',', r'.'), name.replaceAll(r',', r'.'));
  }
}