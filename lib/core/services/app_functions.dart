import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

/// Calls a Firebase callable Cloud Function, working around `cloud_functions`
/// having no Windows platform plugin. On every other platform this just
/// delegates to `FirebaseFunctions.instanceFor(region).httpsCallable(name)`.
/// On Windows it POSTs to the callable's HTTPS endpoint directly, following
/// the documented callable wire protocol (`{"data": ...}` request body,
/// `{"result": ...}` response body, bearer ID token for auth).
///
/// Only usable against functions with `enforceAppCheck: false` — Windows has
/// no App Check plugin either, so an App Check header can't be attached.
class AppFunctions {
  AppFunctions._();

  static Future<dynamic> call(
    String name, {
    Map<String, dynamic>? data,
    String region = 'northamerica-northeast1',
  }) async {
    // Platform.isWindows throws on web — kIsWeb must short-circuit first.
    if (kIsWeb || !Platform.isWindows) {
      final result = await FirebaseFunctions.instanceFor(region: region)
          .httpsCallable(name)
          .call(data);
      return result.data;
    }
    return _callHttp(name, region: region, data: data);
  }

  static Future<dynamic> _callHttp(
    String name, {
    required String region,
    Map<String, dynamic>? data,
  }) async {
    final projectId = Firebase.app().options.projectId;
    final uri =
        Uri.parse('https://$region-$projectId.cloudfunctions.net/$name');
    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (idToken != null) 'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'data': data ?? <String, dynamic>{}}),
    );

    final decoded = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      String? message;
      if (decoded is Map && decoded['error'] is Map) {
        message = (decoded['error'] as Map)['message'] as String?;
      }
      throw FirebaseFunctionsException(
        code: 'internal',
        message: message ?? 'Function call failed (${response.statusCode})',
      );
    }
    return decoded is Map ? decoded['result'] : null;
  }
}
