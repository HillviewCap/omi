import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Local database service for storing conversations offline
/// Uses JSON file storage for simplicity (can be upgraded to SQLite later)
class LocalDbService {
  static final LocalDbService _instance = LocalDbService._internal();
  static LocalDbService get instance => _instance;

  LocalDbService._internal();

  static const String _conversationsFileName = 'local_conversations.json';
  static const String _transcriptSegmentsFileName = 'local_transcript_segments.json';
  static const String _actionItemsFileName = 'local_action_items.json';

  File? _conversationsFile;
  File? _segmentsFile;
  File? _actionItemsFile;

  List<LocalConversation> _conversationsCache = [];
  bool _initialized = false;

  /// Initialize the local database
  Future<void> init() async {
    if (_initialized) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      _conversationsFile = File('${directory.path}/$_conversationsFileName');
      _segmentsFile = File('${directory.path}/$_transcriptSegmentsFileName');
      _actionItemsFile = File('${directory.path}/$_actionItemsFileName');

      // Load existing data
      await _loadConversations();
      _initialized = true;
      debugPrint('[LocalDb] Initialized with ${_conversationsCache.length} conversations');
    } catch (e) {
      debugPrint('[LocalDb] Init error: $e');
    }
  }

  /// Load conversations from disk
  Future<void> _loadConversations() async {
    try {
      if (_conversationsFile != null && await _conversationsFile!.exists()) {
        final contents = await _conversationsFile!.readAsString();
        final List<dynamic> jsonList = jsonDecode(contents);
        _conversationsCache = jsonList.map((e) => LocalConversation.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('[LocalDb] Load conversations error: $e');
      _conversationsCache = [];
    }
  }

  /// Save conversations to disk
  Future<void> _saveConversations() async {
    try {
      if (_conversationsFile != null) {
        final jsonList = _conversationsCache.map((e) => e.toJson()).toList();
        await _conversationsFile!.writeAsString(jsonEncode(jsonList));
      }
    } catch (e) {
      debugPrint('[LocalDb] Save conversations error: $e');
    }
  }

  /// Get all conversations, sorted by created_at descending
  List<LocalConversation> getConversations() {
    final sorted = List<LocalConversation>.from(_conversationsCache);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  /// Get a conversation by ID
  LocalConversation? getConversation(String id) {
    try {
      return _conversationsCache.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Save or update a conversation
  Future<void> saveConversation(LocalConversation conversation) async {
    final existingIndex = _conversationsCache.indexWhere((c) => c.id == conversation.id);
    if (existingIndex >= 0) {
      _conversationsCache[existingIndex] = conversation;
    } else {
      _conversationsCache.add(conversation);
    }
    await _saveConversations();
    debugPrint('[LocalDb] Saved conversation: ${conversation.id}');
  }

  /// Delete a conversation
  Future<void> deleteConversation(String id) async {
    _conversationsCache.removeWhere((c) => c.id == id);
    await _saveConversations();
    debugPrint('[LocalDb] Deleted conversation: $id');
  }

  /// Clear all conversations
  Future<void> clearAll() async {
    _conversationsCache = [];
    await _saveConversations();
    debugPrint('[LocalDb] Cleared all conversations');
  }

  /// Get unsynced conversations (for future cloud sync)
  List<LocalConversation> getUnsyncedConversations() {
    return _conversationsCache.where((c) => !c.synced).toList();
  }

  /// Mark conversation as synced
  Future<void> markSynced(String id) async {
    final conv = getConversation(id);
    if (conv != null) {
      conv.synced = true;
      await _saveConversations();
    }
  }
}

/// Local conversation model matching the SQLite schema from the plan
class LocalConversation {
  final String id;
  final DateTime createdAt;
  DateTime? finishedAt;
  String transcript;
  String? summary;
  List<LocalActionItem> actionItems;
  LocalStructuredData? structured;
  String language;
  bool synced;
  List<LocalTranscriptSegment> segments;

  LocalConversation({
    required this.id,
    required this.createdAt,
    this.finishedAt,
    this.transcript = '',
    this.summary,
    this.actionItems = const [],
    this.structured,
    this.language = 'en',
    this.synced = false,
    this.segments = const [],
  });

  factory LocalConversation.fromJson(Map<String, dynamic> json) {
    return LocalConversation(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      finishedAt: json['finished_at'] != null ? DateTime.parse(json['finished_at'] as String) : null,
      transcript: json['transcript'] as String? ?? '',
      summary: json['summary'] as String?,
      actionItems: (json['action_items'] as List<dynamic>?)
              ?.map((e) => LocalActionItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      structured: json['structured'] != null
          ? LocalStructuredData.fromJson(json['structured'] as Map<String, dynamic>)
          : null,
      language: json['language'] as String? ?? 'en',
      synced: json['synced'] as bool? ?? false,
      segments: (json['segments'] as List<dynamic>?)
              ?.map((e) => LocalTranscriptSegment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'finished_at': finishedAt?.toIso8601String(),
      'transcript': transcript,
      'summary': summary,
      'action_items': actionItems.map((e) => e.toJson()).toList(),
      'structured': structured?.toJson(),
      'language': language,
      'synced': synced,
      'segments': segments.map((e) => e.toJson()).toList(),
    };
  }

  /// Create from PAI-Bridge WebSocket conversation_created event
  factory LocalConversation.fromWebSocketEvent(Map<String, dynamic> event) {
    final conv = event['conversation'] as Map<String, dynamic>;
    return LocalConversation(
      id: conv['id'] as String,
      createdAt: DateTime.parse(conv['created_at'] as String),
      finishedAt: conv['finished_at'] != null ? DateTime.parse(conv['finished_at'] as String) : null,
      transcript: conv['transcript'] as String? ?? '',
      summary: conv['summary'] as String? ?? '',
      actionItems: (conv['action_items'] as List<dynamic>?)
              ?.map((e) => LocalActionItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      structured: conv['structured'] != null
          ? LocalStructuredData.fromJson(conv['structured'] as Map<String, dynamic>)
          : null,
      segments: (conv['transcript_segments'] as List<dynamic>?)
              ?.map((e) => LocalTranscriptSegment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Transcript segment model
class LocalTranscriptSegment {
  final String text;
  final String? speaker;
  final int? speakerId;
  final double? startTime;
  final double? endTime;
  final bool isUser;

  LocalTranscriptSegment({
    required this.text,
    this.speaker,
    this.speakerId,
    this.startTime,
    this.endTime,
    this.isUser = false,
  });

  factory LocalTranscriptSegment.fromJson(Map<String, dynamic> json) {
    return LocalTranscriptSegment(
      text: json['text'] as String? ?? '',
      speaker: json['speaker'] as String?,
      speakerId: json['speaker_id'] as int?,
      startTime: (json['start'] as num?)?.toDouble() ?? (json['start_time'] as num?)?.toDouble(),
      endTime: (json['end'] as num?)?.toDouble() ?? (json['end_time'] as num?)?.toDouble(),
      isUser: json['is_user'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'speaker': speaker,
      'speaker_id': speakerId,
      'start_time': startTime,
      'end_time': endTime,
      'is_user': isUser,
    };
  }
}

/// Action item model
class LocalActionItem {
  final String description;
  bool completed;
  final DateTime createdAt;

  LocalActionItem({
    required this.description,
    this.completed = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory LocalActionItem.fromJson(Map<String, dynamic> json) {
    return LocalActionItem(
      description: json['description'] as String? ?? '',
      completed: json['completed'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'completed': completed,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Structured conversation data (title, overview, category, key points)
class LocalStructuredData {
  final String title;
  final String overview;
  final String category;
  final List<String> keyPoints;

  LocalStructuredData({
    required this.title,
    this.overview = '',
    this.category = 'other',
    this.keyPoints = const [],
  });

  factory LocalStructuredData.fromJson(Map<String, dynamic> json) {
    return LocalStructuredData(
      title: json['title'] as String? ?? 'Untitled',
      overview: json['overview'] as String? ?? '',
      category: json['category'] as String? ?? 'other',
      keyPoints: (json['key_points'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'overview': overview,
      'category': category,
      'key_points': keyPoints,
    };
  }
}
