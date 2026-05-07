package ru.diplom.loadtester;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.FileWriter;
import java.io.IOException;
import java.io.PrintWriter;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

/**
 * Запись результатов нагрузочного теста в CSV-файл.
 *
 * Формат файла:
 * scenario,timestamp,elapsed_sec,messages_sent,errors,rate_per_sec,avg_latency_ms,max_latency_ms
 *
 * Файл создаётся при первом вызове writeHeader() и дополняется
 * строками при каждом вызове writeSnapshot().
 * Один CSV-файл содержит результаты всех сценариев одного запуска.
 */
public class CsvReporter implements AutoCloseable {

    private static final Logger log = LoggerFactory.getLogger(CsvReporter.class);
    private static final DateTimeFormatter DT_FMT =
            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    private final PrintWriter writer;
    private final String filePath;

    public CsvReporter(String outputDir) throws IOException {
        String timestamp = LocalDateTime.now()
                .format(DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss"));
        this.filePath = outputDir + "/load_test_" + timestamp + ".csv";

        this.writer = new PrintWriter(new FileWriter(filePath, true));
        writeHeader();

        log.info("CSV-отчёт будет записан в: {}", filePath);
    }

    private void writeHeader() {
        writer.println(
                "scenario,timestamp,elapsed_sec,messages_sent,errors," +
                        "rate_per_sec,avg_latency_ms,max_latency_ms"
        );
        writer.flush();
    }

    /**
     * Записывает одну строку метрик в CSV.
     *
     * @param scenarioName название сценария
     * @param snapshot     снимок метрик
     */
    public void writeSnapshot(String scenarioName, MetricsCollector.Snapshot snapshot) {
        writer.printf("%s,%s,%.1f,%d,%d,%.2f,%.2f,%d%n",
                scenarioName,
                LocalDateTime.now().format(DT_FMT),
                snapshot.elapsedMs() / 1000.0,
                snapshot.messagesSent(),
                snapshot.errors(),
                snapshot.actualRatePerSec(),
                snapshot.avgLatencyMs(),
                snapshot.maxLatencyMs()
        );
        writer.flush();
    }

    /**
     * Записывает итоговую строку по завершении сценария.
     */
    public void writeSummary(String scenarioName, MetricsCollector.Snapshot snapshot) {
        log.info("=== Итог сценария '{}' ===", scenarioName);
        log.info("  Отправлено сообщений : {}", snapshot.messagesSent());
        log.info("  Ошибок               : {}", snapshot.errors());
        log.info("  Факт. пропускная сп. : {:.1f} msg/s",
                String.format("%.1f", snapshot.actualRatePerSec()));
        log.info("  Средняя задержка     : {:.2f} ms",
                String.format("%.2f", snapshot.avgLatencyMs()));
        log.info("  Максимальная задержка: {} ms", snapshot.maxLatencyMs());
        log.info("  Результаты в файле   : {}", filePath);

        // Итоговая строка помечается суффиксом _SUMMARY
        writeSnapshot(scenarioName + "_SUMMARY", snapshot);
    }

    public String getFilePath() { return filePath; }

    @Override
    public void close() {
        if (writer != null) {
            writer.close();
        }
    }
}