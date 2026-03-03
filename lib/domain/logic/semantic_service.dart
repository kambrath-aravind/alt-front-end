import 'dart:math';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Semantic similarity service using TFLite embeddings.
class SemanticService {
  Interpreter? _interpreter;
  Map<String, int>? _vocab;
  bool _isInitialized = false;
  String? _initError;

  // BERT Embedder typically uses 512, but we detect from model
  int _embeddingDim = 512;
  int _maxSeqLength = 512;

  bool get isInitialized => _isInitialized;
  String? get initializationError => _initError;

  Future<void> init() async {
    _initError = null;
    try {
      // 1. Load Model
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset(
          'assets/models/bert_embedder.tflite',
          options: options);

      // 2. Detect dimensions
      final inputTensors = _interpreter!.getInputTensors();
      final outputTensors = _interpreter!.getOutputTensors();

      if (inputTensors.isNotEmpty && inputTensors[0].shape.length > 1) {
        _maxSeqLength = inputTensors[0].shape[1];
      }

      if (outputTensors.isNotEmpty) {
        final outShape = outputTensors.first.shape;
        if (outShape.length > 1) {
          _embeddingDim = outShape.last;
        }
      }

      // 3. Load Vocab
      await _loadVocab();

      _isInitialized = true;
      print(
          '[SemanticService] Initialized. Dim: $_embeddingDim, Seq: $_maxSeqLength');
    } catch (e) {
      _initError = 'Failed to init SemanticService: $e';
      print('[SemanticService] $_initError');
      _isInitialized = false;
    }
  }

  Future<void> _loadVocab() async {
    try {
      final vocabString =
          await rootBundle.loadString('assets/models/vocab.txt');
      final lines = vocabString.split('\n');
      _vocab = {};
      for (int i = 0; i < lines.length; i++) {
        final token = lines[i].trim();
        if (token.isNotEmpty) {
          _vocab![token] = i;
        }
      }
    } catch (e) {
      print('[SemanticService] Error loading vocab: $e');
    }
  }

  /// Get embedding vector for the given text.
  List<double> getEmbedding(String text) {
    if (!_isInitialized || _interpreter == null || _vocab == null) {
      return [];
    }

    try {
      // 1. Tokenize
      final tokens = _tokenize(text);

      // 2. Prepare inputs
      final inputIds = List<int>.filled(_maxSeqLength, 0);
      final inputMask = List<int>.filled(_maxSeqLength, 0);
      final segmentIds = List<int>.filled(_maxSeqLength, 0);

      int idx = 0;
      // [CLS]
      inputIds[idx] = _vocab!['[CLS]'] ?? 101;
      inputMask[idx] = 1;
      idx++;

      // Tokens
      for (int id in tokens) {
        if (idx >= _maxSeqLength - 1) break; // Reserve for [SEP]
        inputIds[idx] = id;
        inputMask[idx] = 1;
        idx++;
      }

      // [SEP]
      inputIds[idx] = _vocab!['[SEP]'] ?? 102;
      inputMask[idx] = 1;

      // 3. Run Inference
      // Input Order for MediaPipe/MobileBERT Embedder: [ids, mask, segments] OR [ids, segments, mask]
      // Our previous investigation showed:
      // Input [0] input_ids
      // Input [1] input_mask
      // Input [2] segment_ids

      var output =
          List.filled(1 * _embeddingDim, 0.0).reshape([1, _embeddingDim]);

      _interpreter!.runForMultipleInputs([
        [inputIds], // Index 0
        [inputMask], // Index 1
        [segmentIds] // Index 2
      ], {
        0: output
      });

      return (output[0] as List).cast<double>();
    } catch (e) {
      print('[SemanticService] Inference failed: $e');
      return [];
    }
  }

  /// WordPiece tokenization
  List<int> _tokenize(String text) {
    if (_vocab == null) return [];
    final ids = <int>[];
    final words = text.toLowerCase().split(RegExp(r'\s+'));

    for (var word in words) {
      if (word.isEmpty) continue;
      word = word.replaceAll(RegExp(r'^[^\w]+|[^\w]+$'), '');
      if (word.isEmpty) continue;

      var start = 0;
      while (start < word.length) {
        var end = word.length;
        String? subToken;
        while (end > start) {
          var substr = word.substring(start, end);
          if (start > 0) substr = "##$substr";
          if (_vocab!.containsKey(substr)) {
            subToken = substr;
            break;
          }
          end--;
        }
        if (subToken != null) {
          ids.add(_vocab![subToken] ?? 100);
          start = end;
        } else {
          ids.add(_vocab!['[UNK]'] ?? 100);
          start++;
        }
      }
    }
    return ids;
  }

  double cosineSimilarity(List<double> v1, List<double> v2) {
    if (v1.length != v2.length || v1.isEmpty) return 0.0;
    double dot = 0.0, mag1 = 0.0, mag2 = 0.0;
    for (var i = 0; i < v1.length; i++) {
      dot += v1[i] * v2[i];
      mag1 += v1[i] * v1[i];
      mag2 += v2[i] * v2[i];
    }
    return mag1 == 0 || mag2 == 0 ? 0.0 : dot / (sqrt(mag1) * sqrt(mag2));
  }

  void dispose() {
    _interpreter?.close();
    _isInitialized = false;
  }
}
