import 'package:flutter_test/flutter_test.dart';
import 'package:yao_ji_qing/services/gemini/model_downloader.dart';

void main() {
  group('ModelDownloader Tests', () {
    late ModelDownloader downloader;

    setUp(() {
      downloader = ModelDownloader();
      downloader.clearDownloadSnapshot();
    });

    test('Initial state should be inactive', () {
      final snapshot = downloader.downloadSnapshot;
      expect(snapshot.isActive, isFalse);
      expect(snapshot.progress, 0.0);
    });

    test('setDownloadStage updates snapshot', () {
      downloader.setDownloadStage('gemma', 0.5, 'Downloading');
      
      final snapshot = downloader.downloadSnapshot;
      expect(snapshot.isActive, isTrue);
      expect(snapshot.type, 'gemma');
      expect(snapshot.progress, 0.5);
      expect(snapshot.status, 'Downloading');
    });

    test('clearDownloadSnapshot resets to inactive', () {
      downloader.setDownloadStage('gemma', 0.5, 'Downloading');
      downloader.clearDownloadSnapshot();
      
      final snapshot = downloader.downloadSnapshot;
      expect(snapshot.isActive, isFalse);
      expect(snapshot.progress, 0.0);
    });
  });
}
