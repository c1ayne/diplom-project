package ru.diplom.loadtester;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.File;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

/**
 * Точка входа нагрузочного тестировщика MQTT-Kafka пайплайна.
 *
 * Использование:
 *   java -jar load-tester.jar [параметры]
 *
 * Параметры:
 *   --broker=<url>        Адрес MQTT-брокера (по умолчанию: tcp://localhost:1883)
 *   --rate=<n>            Целевая интенсивность в сообщений/сек (по умолчанию: 10)
 *   --duration=<n>        Длительность теста в секундах (по умолчанию: 60)
 *   --critical=<0.0-1.0>  Доля критических сообщений (по умолчанию: 0.1)
 *   --scenario=<name>     Название сценария для CSV (по умолчанию: test)
 *   --output=<dir>        Директория для CSV-отчёта (по умолчанию: ./results)
 *
 * Примеры:
 *   java -jar load-tester.jar --rate=10 --duration=300 --scenario=baseline
 *   java -jar load-tester.jar --rate=100 --duration=300 --scenario=medium
 *   java -jar load-tester.jar --rate=500 --duration=300 --scenario=peak
 */
public class LoadTesterApp {

    private static final Logger log = LoggerFactory.getLogger(LoadTesterApp.class);

    public static void main(String[] args) throws Exception {


        String brokerUrl     = parseArg(args, "--broker",   "tcp://localhost:1883");
        int    targetRate    = Integer.parseInt(parseArg(args, "--rate",     "10"));
        int    duration      = Integer.parseInt(parseArg(args, "--duration", "60"));
        double criticalRatio = Double.parseDouble(parseArg(args, "--critical", "0.1"));
        String scenarioName  = parseArg(args, "--scenario", "test");
        String outputDir     = parseArg(args, "--output",   "./results");

        new File(outputDir).mkdirs();

        LoadScenario scenario = new LoadScenario(
                brokerUrl, targetRate, duration, criticalRatio, scenarioName
        );

        log.info("=== Нагрузочный тест запущен ===");
        log.info("{}", scenario);
        log.info("Результаты будут записаны в: {}", outputDir);
        log.info("Для доступа к MQTT-брокеру в kind выполни:");
        log.info("  kubectl port-forward svc/my-emqx 1883:1883 -n iot-system");

        runScenario(scenario, outputDir);
    }

    /**
     * Выполняет один сценарий нагрузочного теста.
     * Основной цикл публикует сообщения с заданным rate,
     * параллельный поток каждые 5 секунд логирует прогресс и пишет в CSV.
     */
    private static void runScenario(LoadScenario scenario, String outputDir) throws Exception {

        MetricsCollector metrics = new MetricsCollector();

        try (MqttPublisher publisher = new MqttPublisher(scenario.getBrokerUrl());
             CsvReporter reporter = new CsvReporter(outputDir)) {

            ScheduledExecutorService scheduler = Executors.newSingleThreadScheduledExecutor();
            scheduler.scheduleAtFixedRate(() -> {
                MetricsCollector.Snapshot snap = metrics.snapshot();
                log.info("[{}] {}", scenario.getScenarioName(), snap.toLogString());
                reporter.writeSnapshot(scenario.getScenarioName(), snap);
            }, 5, 5, TimeUnit.SECONDS);

            long endTime = System.currentTimeMillis() + scenario.getDurationSeconds() * 1000L;
            long intervalMicros = scenario.getIntervalMicros();

            log.info("Старт публикации: {} msg/s в течение {} сек...",
                    scenario.getTargetRate(), scenario.getDurationSeconds());

            while (System.currentTimeMillis() < endTime) {
                long cycleStart = System.nanoTime();

                try {
                    long latency = publisher.publishOne(scenario.getCriticalRatio());
                    metrics.recordSuccess(latency);
                } catch (Exception e) {
                    metrics.recordError();
                    log.warn("Ошибка публикации: {}", e.getMessage());
                }

                long elapsed = (System.nanoTime() - cycleStart) / 1000;
                long sleepMicros = intervalMicros - elapsed;
                if (sleepMicros > 1000) {
                    TimeUnit.MICROSECONDS.sleep(sleepMicros);
                }
            }

            scheduler.shutdown();
            scheduler.awaitTermination(10, TimeUnit.SECONDS);

            MetricsCollector.Snapshot finalSnapshot = metrics.snapshot();
            reporter.writeSummary(scenario.getScenarioName(), finalSnapshot);

            log.info("=== Тест завершён. CSV: {} ===", reporter.getFilePath());
        }
    }

    /**
     * Разбирает именованный аргумент вида --key=value из массива args.
     *
     * @param args         массив аргументов командной строки
     * @param name         имя аргумента (например, "--rate")
     * @param defaultValue значение по умолчанию если аргумент не найден
     * @return значение аргумента или defaultValue
     */
    private static String parseArg(String[] args, String name, String defaultValue) {
        String prefix = name + "=";
        for (String arg : args) {
            if (arg.startsWith(prefix)) {
                return arg.substring(prefix.length());
            }
        }
        return defaultValue;
    }
}