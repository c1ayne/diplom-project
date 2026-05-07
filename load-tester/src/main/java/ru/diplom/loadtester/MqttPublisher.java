package ru.diplom.loadtester;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.eclipse.paho.client.mqttv3.*;
import org.eclipse.paho.client.mqttv3.persist.MemoryPersistence;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Random;
import java.util.UUID;

/**
 * MQTT-клиент для нагрузочного тестирования.
 *
 * Отличия от MqttManager в generator:
 * - Использует MemoryPersistence (не нужна персистентность между запусками теста)
 * - CleanSession=true (каждый запуск теста — новая сессия)
 * - QoS задаётся сценарием, а не хардкодится
 */
public class MqttPublisher implements AutoCloseable {

    private static final Logger log = LoggerFactory.getLogger(MqttPublisher.class);

    private static final String TOPIC_SENSOR  = "sensors/factory/%s/telemetry";
    private static final String TOPIC_ALERT   = "alerts/factory/%s/alarm";

    private static final String[] DEVICE_IDS = {
            "sensor-01", "sensor-02", "sensor-03",
            "sensor-04", "sensor-05", "pump-A", "pump-B"
    };

    private final MqttClient client;
    private final ObjectMapper mapper;
    private final Random random;

    public MqttPublisher(String brokerUrl) throws MqttException {
        String clientId = "load-tester-" + UUID.randomUUID();
        this.client = new MqttClient(brokerUrl, clientId, new MemoryPersistence());
        this.mapper = new ObjectMapper();
        this.random = new Random();

        MqttConnectOptions options = new MqttConnectOptions();
        options.setCleanSession(true);
        options.setConnectionTimeout(10);
        options.setAutomaticReconnect(true);

        log.info("Подключение к MQTT-брокеру: {}", brokerUrl);
        client.connect(options);
        log.info("Подключение установлено");
    }

    /**
     * Публикует одно сообщение и возвращает задержку публикации в мс.
     *
     * @param criticalRatio вероятность генерации критического сообщения (0.0 — 1.0)
     * @return задержка публикации в миллисекундах
     * @throws Exception при ошибке сериализации или публикации
     */
    public long publishOne(double criticalRatio) throws Exception {
        String deviceId = DEVICE_IDS[random.nextInt(DEVICE_IDS.length)];
        boolean isCritical = random.nextDouble() < criticalRatio;

        SensorData data = new SensorData();
        data.setDeviceId(deviceId);
        data.setTimestamp(System.currentTimeMillis());

        String topic;
        int qos;

        if (isCritical) {
            data.setType("CRITICAL_OVERHEAT");
            data.setValue(80.0 + random.nextDouble() * 20);
            topic = String.format(TOPIC_ALERT, deviceId);
            qos = 2;
        } else {
            data.setType("TEMPERATURE");
            data.setValue(20.0 + random.nextDouble() * 10);
            topic = String.format(TOPIC_SENSOR, deviceId);
            qos = 1;
        }

        byte[] payload = mapper.writeValueAsBytes(data);
        MqttMessage message = new MqttMessage(payload);
        message.setQos(qos);

        long start = System.currentTimeMillis();
        client.publish(topic, message);
        return System.currentTimeMillis() - start;
    }

    public boolean isConnected() {
        return client != null && client.isConnected();
    }

    @Override
    public void close() {
        try {
            if (client != null && client.isConnected()) {
                client.disconnect();
                log.info("MQTT-соединение закрыто");
            }
        } catch (MqttException e) {
            log.warn("Ошибка при закрытии MQTT-соединения: {}", e.getMessage());
        }
    }
}