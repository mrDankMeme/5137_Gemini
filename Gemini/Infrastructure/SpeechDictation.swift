import AVFoundation
import Foundation
import Speech

/// Диктовка: запись с микрофона и распознавание **средствами системы**.
///
/// Распознаёт `SFSpeechRecognizer` из фреймворка Speech — своего сервиса
/// распознавания у приложения нет и не будет: отправлять голос на сторонний
/// сервер ради текста, который система умеет собрать сама, значит без нужды
/// вывозить с устройства запись голоса пользователя.
///
/// `SpeechAnalyzer`/`SpeechTranscriber` (iOS 26) сюда добавятся, когда поднимем
/// минимальную версию: сейчас у проекта iOS 18, и второй путь пришлось бы держать
/// непроверяемым на большей части парка устройств.
///
/// Экземпляр одноразовый по смыслу: `start` → `finish`/`cancel` → снова `start`.
@MainActor
final class SpeechDictation {
    /// Почему диктовка не началась. Каждый случай ведёт к своему тексту и действию:
    /// отказ в правах чинится только в настройках iOS, а недоступность языка —
    /// вообще не чинится пользователем.
    enum Failure: Error, Equatable {
        case microphoneDenied
        case recognitionDenied
        case recognizerUnavailable
        case audioEngineFailed
    }

    /// Что диктовка отдаёт наружу на каждом обновлении.
    struct Update: Equatable {
        /// Распознанное на текущий момент. Пока говорят — предварительный результат.
        let transcript: String
        /// Громкость последнего куска, 0…1 — из неё рисуется дорожка звука.
        let level: CGFloat
    }

    private let engine = AVAudioEngine()
    private let recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var transcript = ""

    /// Язык распознавания — системный. Приложение своей настройки языка не имеет,
    /// а `SFSpeechRecognizer()` без локали и так берёт язык устройства.
    init(locale: Locale = .current) {
        recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer()
    }

    // MARK: Разрешения

    /// Спрашивает оба разрешения: микрофон и распознавание речи.
    ///
    /// Именно два: запись без распознавания даёт звук без текста, а распознавание
    /// без записи — нечего распознавать. Отказ в любом останавливает диктовку.
    func requestAuthorization() async -> Failure? {
        guard await AVAudioApplication.requestRecordPermission() else {
            return .microphoneDenied
        }

        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard status == .authorized else { return .recognitionDenied }

        guard let recognizer, recognizer.isAvailable else { return .recognizerUnavailable }
        return nil
    }

    // MARK: Диктовка

    /// Начинает запись и распознавание. Обновления приходят на главном акторе.
    func start(onChange: @escaping @MainActor (Update) -> Void) throws {
        guard let recognizer, recognizer.isAvailable else { throw Failure.recognizerUnavailable }

        // Прошлая диктовка могла не закрыться — вторая сессия на том же движке
        // роняет CoreAudio.
        reset()
        transcript = ""

        let request = SFSpeechAudioBufferRecognitionRequest()
        // Промежуточный результат нужен, чтобы текст набегал прямо во время речи,
        // а не появлялся целиком в конце.
        request.shouldReportPartialResults = true
        // На устройстве, где это умеет система, запись не уходит с телефона вовсе.
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw Failure.audioEngineFailed
        }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        // Нулевая частота дискретизации — это «микрофон недоступен» (так ведёт себя
        // симулятор без входа). Ставить на такой формат tap нельзя, приложение упадёт.
        guard format.sampleRate > 0, format.channelCount > 0 else { throw Failure.audioEngineFailed }

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            request.append(buffer)
            let level = Self.level(of: buffer)
            Task { @MainActor [weak self] in
                guard let self else { return }
                onChange(Update(transcript: transcript, level: level))
            }
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            reset()
            throw Failure.audioEngineFailed
        }

        // Результат приходит с очереди распознавателя, а не с главной, поэтому
        // текст сначала вынимается из него, и только потом идёт переход на главный
        // актор: состояние диктовки живёт там же, где и экран.
        task = recognizer.recognitionTask(with: request) { [weak self] result, _ in
            guard let text = result?.bestTranscription.formattedString else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                transcript = text
                onChange(Update(transcript: text, level: 0))
            }
        }
    }

    /// Останавливает запись и отдаёт распознанное.
    ///
    /// Микрофон глушится сразу, а задача распознавания доживает сама: последние
    /// слова приходят уже после остановки записи, и обрывать её здесь — терять их.
    func finish() -> String {
        stopAudio()
        request?.endAudio()
        return transcript
    }

    /// Полная отмена: ни текста, ни задачи.
    func cancel() {
        reset()
        transcript = ""
    }

    // MARK: Служебное

    private func reset() {
        stopAudio()
        task?.cancel()
        task = nil
        request = nil
    }

    private func stopAudio() {
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Громкость куска как RMS, приведённая к 0…1.
    ///
    /// Шкала логарифмическая: линейный RMS у речи держится около нуля, и дорожка
    /// выглядела бы почти плоской.
    private static func level(of buffer: AVAudioPCMBuffer) -> CGFloat {
        guard let channel = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }

        let frames = Int(buffer.frameLength)
        var sum: Float = 0
        for index in 0 ..< frames {
            let sample = channel[index]
            sum += sample * sample
        }

        let rms = (sum / Float(frames)).squareRoot()
        guard rms > 0 else { return 0 }

        let decibels = 20 * log10(rms)
        // −50 дБ и тише считаем тишиной: ниже начинается собственный шум микрофона.
        let normalized = (decibels + 50) / 50
        return CGFloat(min(max(normalized, 0), 1))
    }
}
