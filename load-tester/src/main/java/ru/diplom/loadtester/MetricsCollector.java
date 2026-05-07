package ru.diplom.loadtester;

import java.util.concurrent.atomic.AtomicLong;

/**
 * Потокобезопасный сборщик метрик нагрузочного теста.
 * Использует AtomicLong для корректной работы в многопоточной среде.
 *
 * Собираемые метрики:
 * - Количество отправленных сообщений
 * - Количество ошибок
 * - Суммарная и максимальная задержка публикации
 */
public class MetricsCollector {

    private final AtomicLong messagesSent    = new AtomicLong(0);
    private final AtomicLong errors          = new AtomicLong(0);
    private final AtomicLong totalLatencyMs  = new AtomicLong(0);
    private final AtomicLong maxLatencyMs    = new AtomicLong(0);

    private final long startTimeMs;

    public MetricsCollector() {
        this.startTimeMs = System.currentTimeMillis();
    }

    /**
     * Фиксирует успешную отправку сообщения с измеренной задержкой.
     *
     * @param latencyMs задержка публикации в миллисекундах
     */
    public void recordSuccess(long latencyMs) {
        messagesSent.incrementAndGet();
        totalLatencyMs.addAndGet(latencyMs);

        // Атомарное обновление максимума без локов
        long currentMax;
        do {
            currentMax = maxLatencyMs.get();
        } while (latencyMs > currentMax && !maxLatencyMs.compareAndSet(currentMax, latencyMs));
    }

    /**
     * Фиксирует ошибку публикации.
     */
    public void recordError() {
        errors.incrementAndGet();
    }

    /**
     * Возвращает снимок текущих метрик для периодического логирования.
     */
    public Snapshot snapshot() {
        long sent    = messagesSent.get();
        long err     = errors.get();
        long elapsed = System.currentTimeMillis() - startTimeMs;
        double actualRate = elapsed > 0 ? (sent * 1000.0 / elapsed) : 0;
        double avgLatency = sent > 0 ? (totalLatencyMs.get() / (double) sent) : 0;

        return new Snapshot(sent, err, actualRate, avgLatency, maxLatencyMs.get(), elapsed);
    }

    public long getMessagesSent()   { return messagesSent.get(); }
    public long getErrors()         { return errors.get(); }
    public long getElapsedMs()      { return System.currentTimeMillis() - startTimeMs; }

    /**
     * Неизменяемый снимок метрик в конкретный момент времени.
     */
    public record Snapshot(
            long   messagesSent,
            long   errors,
            double actualRatePerSec,
            double avgLatencyMs,
            long   maxLatencyMs,
            long   elapsedMs
    ) {
        public String toLogString() {
            return String.format(
                    "Отправлено: %d | Ошибок: %d | Факт. rate: %.1f msg/s | " +
                            "Avg latency: %.2f ms | Max latency: %d ms | Прошло: %.1f s",
                    messagesSent, errors, actualRatePerSec,
                    avgLatencyMs, maxLatencyMs, elapsedMs / 1000.0
            );
        }
    }
}