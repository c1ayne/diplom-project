package ru.diplom.loadtester;

/**
 * Параметры одного сценария нагрузочного тестирования.
 * Заполняется из аргументов командной строки в LoadTesterApp.
 */
public class LoadScenario {

    /** Адрес MQTT-брокера */
    private final String brokerUrl;

    /** Целевая интенсивность публикации (сообщений в секунду) */
    private final int targetRate;

    /** Длительность теста в секундах */
    private final int durationSeconds;

    /** Доля критических сообщений (alerts) от 0.0 до 1.0 */
    private final double criticalRatio;

    /** Название сценария для CSV-отчёта */
    private final String scenarioName;

    public LoadScenario(String brokerUrl, int targetRate, int durationSeconds,
                        double criticalRatio, String scenarioName) {
        this.brokerUrl       = brokerUrl;
        this.targetRate      = targetRate;
        this.durationSeconds = durationSeconds;
        this.criticalRatio   = criticalRatio;
        this.scenarioName    = scenarioName;
    }

    public String getBrokerUrl()       { return brokerUrl; }
    public int getTargetRate()         { return targetRate; }
    public int getDurationSeconds()    { return durationSeconds; }
    public double getCriticalRatio()   { return criticalRatio; }
    public String getScenarioName()    { return scenarioName; }

    /**
     * Интервал между публикациями в микросекундах.
     * Используется для точного контроля rate через Thread.sleep.
     */
    public long getIntervalMicros() {
        return 1_000_000L / targetRate;
    }

    @Override
    public String toString() {
        return String.format(
                "Сценарий='%s' rate=%d msg/s duration=%ds criticalRatio=%.0f%% broker=%s",
                scenarioName, targetRate, durationSeconds,
                criticalRatio * 100, brokerUrl
        );
    }
}