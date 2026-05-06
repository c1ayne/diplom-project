package ru.diplom;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.eclipse.paho.client.mqttv3.MqttClient;
import org.eclipse.paho.client.mqttv3.MqttException;
import org.eclipse.paho.client.mqttv3.MqttMessage;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Random;
import java.util.concurrent.TimeUnit;

/**
 * Генератор телеметрических данных IoT-устройств.
 *
 * Симулирует поведение парка промышленных датчиков и насосов:
 * - С вероятностью ~90% публикует штатные показания температуры (топик sensors/#, QoS 1)
 * - С вероятностью ~10% публикует критическое событие перегрева (топик alerts/#, QoS 2)
 *
 * Выбор уровней QoS соответствует теоретическому обоснованию в дипломной работе:
 * - QoS 1 (at-least-once) для телеметрии: допустимы редкие дубликаты, важна скорость
 * - QoS 2 (exactly-once) для алертов: критична однократная гарантированная доставка
 */
public class App {

    private static final Logger log = LoggerFactory.getLogger(App.class);

    private static final String TOPIC_SENSOR_TEMPLATE = "sensors/factory/%s/telemetry";
    private static final String TOPIC_ALERT_TEMPLATE  = "alerts/factory/%s/alarm";

    // Интервал между публикациями в миллисекундах
    private static final long PUBLISH_INTERVAL_MS = 500L;

    public static void main(String[] args) {
        log.info("Запуск генератора IoT-данных");

        MqttClient client;
        try {
            client = MqttManager.createClient();
        } catch (MqttException e) {
            log.error("Не удалось подключиться к MQTT-брокеру после всех попыток: {}", e.getMessage(), e);
            System.exit(1);
            return;
        } catch (InterruptedException e) {
            log.warn("Запуск прерван во время ожидания подключения к брокеру");
            Thread.currentThread().interrupt();
            return;
        }

        ObjectMapper mapper = new ObjectMapper();
        Random random = new Random();

        String[] deviceIds = {"sensor-01", "sensor-02", "sensor-03", "pump-A", "pump-B"};

        log.info("Генератор запущен. Публикация с интервалом {} мс", PUBLISH_INTERVAL_MS);

        while (!Thread.currentThread().isInterrupted()) {
            try {
                String deviceId = deviceIds[random.nextInt(deviceIds.length)];

                SensorData data = new SensorData();
                data.setDeviceId(deviceId);
                data.setTimestamp(System.currentTimeMillis());

                boolean isCritical = random.nextInt(10) == 0;

                String topic;
                int qos;

                if (isCritical) {
                    // Критическое событие: QoS 2 (exactly-once) — однократная гарантированная доставка
                    data.setType("CRITICAL_OVERHEAT");
                    data.setValue(80.0 + random.nextDouble() * 20);
                    topic = String.format(TOPIC_ALERT_TEMPLATE, deviceId);
                    qos = 2;
                } else {
                    // Телеметрия: QoS 1 (at-least-once) — допустимы редкие дубликаты
                    data.setType("TEMPERATURE");
                    data.setValue(20.0 + random.nextDouble() * 10);
                    topic = String.format(TOPIC_SENSOR_TEMPLATE, deviceId);
                    qos = 1;
                }

                String jsonPayload = mapper.writeValueAsString(data);

                MqttMessage message = new MqttMessage(jsonPayload.getBytes());
                message.setQos(qos);

                client.publish(topic, message);

                log.info("Опубликовано [QoS {}] -> {}: {}", qos, topic, jsonPayload);

                TimeUnit.MILLISECONDS.sleep(PUBLISH_INTERVAL_MS);

            } catch (InterruptedException e) {
                // Корректная обработка сигнала остановки: восстанавливаем флаг и завершаем цикл
                log.info("Генератор получил сигнал остановки, завершение работы...");
                Thread.currentThread().interrupt();
                break;
            } catch (MqttException e) {
                log.error("Ошибка публикации MQTT: {}", e.getMessage(), e);
                // AutomaticReconnect=true обрабатывает переподключение,
                // небольшая пауза предотвращает busy-loop при длительном сбое
                try {
                    TimeUnit.SECONDS.sleep(1);
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    break;
                }
            } catch (Exception e) {
                log.error("Неожиданная ошибка в цикле генерации: {}", e.getMessage(), e);
            }
        }

        log.info("Генератор завершил работу");
    }
}