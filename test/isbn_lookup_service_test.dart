import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bookie_bookie/services/isbn_lookup_service.dart';

void main() {
  test('parses a successful Open Library response', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'openlibrary.org');
      return http.Response(
        jsonEncode({
          'ISBN:9780141439518': {
            'title': 'Pride and Prejudice',
            'authors': [
              {'name': 'Jane Austen'},
            ],
            'cover': {'medium': 'https://covers.openlibrary.org/b/id/1.jpg'},
          },
        }),
        200,
      );
    });

    final service = IsbnLookupService(client: client);
    final result = await service.lookup('9780141439518');

    expect(result, isNotNull);
    expect(result!.title, 'Pride and Prejudice');
    expect(result.author, 'Jane Austen');
    expect(result.coverUrl, 'https://covers.openlibrary.org/b/id/1.jpg');
  });

  test('falls back to Google Books when Open Library has nothing', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'openlibrary.org') {
        return http.Response(jsonEncode({}), 200);
      }
      return http.Response(
        jsonEncode({
          'items': [
            {
              'volumeInfo': {
                'title': 'Fallback Title',
                'authors': ['Some Author'],
                'imageLinks': {'thumbnail': 'https://example.com/cover.jpg'},
              },
            },
          ],
        }),
        200,
      );
    });

    final service = IsbnLookupService(client: client);
    final result = await service.lookup('9780141439518');

    expect(result, isNotNull);
    expect(result!.title, 'Fallback Title');
    expect(result.author, 'Some Author');
  });

  test('returns null when neither source has data', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'openlibrary.org') {
        return http.Response(jsonEncode({}), 200);
      }
      return http.Response(jsonEncode({'totalItems': 0}), 200);
    });

    final service = IsbnLookupService(client: client);
    final result = await service.lookup('9780141439518');

    expect(result, isNull);
  });

  test('skips the lookup entirely for a Sri Lankan (955) ISBN', () async {
    var called = false;
    final client = MockClient((request) async {
      called = true;
      return http.Response('', 500);
    });

    final service = IsbnLookupService(client: client);
    final result = await service.lookup('978-955-20-1234-5');

    expect(result, isNull);
    expect(called, isFalse);
  });

  test('treats a request error as no data rather than throwing', () async {
    final client = MockClient((request) async {
      throw Exception('boom');
    });

    final service = IsbnLookupService(client: client);
    final result = await service.lookup('9780141439518');

    expect(result, isNull);
  });
}
