import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

import 'config.dart';

/// A known household member loaded from `assets/known_faces.json`.
class KnownPerson {
  final String id;
  final String name;
  final List<double> embedding;

  const KnownPerson({
    required this.id,
    required this.name,
    required this.embedding,
  });

  factory KnownPerson.fromJson(Map<String, dynamic> json) {
    final raw = (json['embedding'] as List<dynamic>? ?? const []);
    return KnownPerson(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      embedding: raw.map((e) => (e as num).toDouble()).toList(growable: false),
    );
  }
}

/// Result of matching a live face against the known faces database.
class FaceMatchResult {
  final KnownPerson? person;
  final double similarity;

  const FaceMatchResult(this.person, this.similarity);

  bool get isKnown => person != null;
}

const String _knownFacesAsset = 'assets/known_faces.json';

List<KnownPerson>? _cachedKnownPersons;

/// Loads (and caches) known persons from the bundled JSON asset.
/// Returns an empty list if the asset is missing or malformed.
Future<List<KnownPerson>> loadKnownPersons({bool forceReload = false}) async {
  if (_cachedKnownPersons != null && !forceReload) return _cachedKnownPersons!;

  try {
    final jsonStr = await rootBundle.loadString(_knownFacesAsset);
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final list = (data['knownPersons'] as List<dynamic>? ?? const []);
    _cachedKnownPersons = list
        .whereType<Map<String, dynamic>>()
        .map(KnownPerson.fromJson)
        .where((p) => p.embedding.isNotEmpty)
        .toList(growable: false);
  } catch (e) {
    print('Lỗi đọc known_faces.json: $e');
    _cachedKnownPersons = const [];
  }
  return _cachedKnownPersons!;
}

/// Cosine similarity between two vectors. Returns 0.0 when the lengths
/// differ or either vector has zero magnitude (e.g. dummy all-zero data).
double cosineSimilarity(List<double> a, List<double> b) {
  if (a.length != b.length || a.isEmpty) return 0.0;

  double dot = 0, normA = 0, normB = 0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  if (normA == 0 || normB == 0) return 0.0;
  return dot / (sqrt(normA) * sqrt(normB));
}

/// Finds the best-matching known person for [liveEmbedding].
Future<FaceMatchResult> matchFace(
  List<double> liveEmbedding, {
  double threshold = kFaceMatchThreshold,
}) async {
  final persons = await loadKnownPersons();

  KnownPerson? best;
  double bestScore = -1.0;
  for (final p in persons) {
    final score = cosineSimilarity(liveEmbedding, p.embedding);
    if (score > bestScore) {
      bestScore = score;
      best = p;
    }
  }

  return bestScore >= threshold
      ? FaceMatchResult(best, bestScore)
      : FaceMatchResult(null, bestScore);
}

/// Returns `true` for "Người nhà" and `false` for "Người lạ".
Future<bool> isKnownPerson(List<double> liveEmbedding) async {
  final result = await matchFace(liveEmbedding);
  return result.isKnown;
}
