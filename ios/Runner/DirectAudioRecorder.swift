import AVFoundation
import Flutter

class DirectAudioRecorder: NSObject, FlutterStreamHandler {
    private let engine = AVAudioEngine()
    private var isRecording = false
    private var eventSink: FlutterEventSink?
    private let sampleRate: Double = 16000

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            let sr = (call.arguments as? [String: Any])?["sampleRate"] as? Int ?? 16000
            start(sampleRate: Double(sr), result: result)
        case "stop":
            stop()
            result(nil)
        case "isRecording":
            result(isRecording)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    private func start(sampleRate: Double, result: @escaping FlutterResult) {
        guard !isRecording else {
            result(nil)
            return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: [])
            try session.setActive(true)
        } catch {
            result(FlutterError(
                code: "AUDIO_SESSION_ERROR",
                message: "无法配置音频会话: \(error.localizedDescription)",
                details: nil
            ))
            return
        }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            result(FlutterError(
                code: "AUDIO_CONFIG_ERROR",
                message: "无法创建 16kHz 输出格式",
                details: nil
            ))
            return
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            result(FlutterError(
                code: "AUDIO_CONFIG_ERROR",
                message: "无法创建采样率转换器",
                details: nil
            ))
            return
        }

        let bufferSize = AVAudioFrameCount(sampleRate / 5)

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self, self.isRecording, let sink = self.eventSink else { return }

            guard let convertedBuffer = self.convertBuffer(
                buffer: buffer,
                converter: converter,
                outputFormat: outputFormat
            ) else { return }

            let channelData = convertedBuffer.int16ChannelData!.pointee
            let frameLength = Int(convertedBuffer.frameLength)
            let data = Data(bytes: channelData, count: frameLength * 2)
            DispatchQueue.main.async {
                sink(FlutterStandardTypedData(bytes: data))
            }
        }

        do {
            try engine.start()
            isRecording = true
            result(nil)
        } catch {
            engine.stop()
            inputNode.removeTap(onBus: 0)
            result(FlutterError(
                code: "AUDIO_START_ERROR",
                message: "录音启动失败: \(error.localizedDescription)",
                details: nil
            ))
        }
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
    }

    private func convertBuffer(
        buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        outputFormat: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let frameCapacity = AVAudioFrameCount(
            Double(buffer.frameLength) * (outputFormat.sampleRate / buffer.format.sampleRate)
        )
        guard let output = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: frameCapacity
        ) else { return nil }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        var allDataReceived = false
        _ = converter.convert(to: output, error: &error) { _, outStatus in
            if allDataReceived {
                outStatus.pointee = .noDataNow
                return nil
            }
            allDataReceived = true
            outStatus.pointee = .haveData
            return buffer
        }

        _ = converter.convert(to: output, error: &error, withInputFrom: inputBlock)

        if let error = error {
            print("[DirectAudioRecorder] 转换失败: \(error.localizedDescription)")
            return nil
        }

        return output
    }
}
