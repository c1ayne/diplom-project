package ru.diplom;

import org.eclipse.paho.client.mqttv3.MqttClient;
import org.eclipse.paho.client.mqttv3.MqttConnectOptions;
import org.eclipse.paho.client.mqttv3.MqttException;
import org.eclipse.paho.client.mqttv3.persist.MqttDefaultFilePersistence;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.UUID;

/**
 * Фабрика MQTT-клиентов с поддержкой персистентных сессий.
 *
 * Ключевые параметры надёжности:
 * - CleanSession=false: брокер сохраняет состояние сессии между переподключениями,
 *   гарантируя доставку неподтверждённых сообщений QoS 1/2 после обрыва связи.
 * - MqttDefaultFilePersistence: исходящие сообщения сохраняются на диск,
 *   что предотвращает их потерю при аварийном завершении процесса.
 * - AutomaticReconnect=true: клиент автоматически восстанавливает соединение
 *   без вмешательства прикладного кода.
 */
public class MqttManager {

    private static final Logger log = LoggerFactory.getLogger(MqttManager.class);

    // Директория для хранения персистентного состояния исходящих сообщений
    private static final String PERSISTENCE_DIR = "/tmp/mqtt-persistence";

    // Параметры retry при первоначальном подключении
    private static final int MAX_CONNECT_RETRIES = 5;
    private static final long RETRY_INTERVAL_MS = 3000L;

    /**
     * Создаёт и подключает MQTT-клиент с персистентной сессией.
     * При недоступности брокера выполняет повторные попытки с фиксированным интервалом.
     *
     * @return подключённый MqttClient
     * @throws MqttException если все попытки подключения исчерпаны
     * @throws InterruptedException если поток был прерван во время ожидания между попытками
     */
    public static MqttClient createClient() throws MqttException, InterruptedException {
        String brokerUrl = System.getenv().getOrDefault("MQTT_BROKER_URL", "tcp://localhost:1883");
        String publisherId = "generator-" + UUID.randomUUID();

        // Файловая персистентность гарантирует сохранность неотправленных сообщений
        // при аварийном завершении процесса (в отличие от MemoryPersistence)
        MqttDefaultFilePersistence persistence = new MqttDefaultFilePersistence(PERSISTENCE_DIR);

        MqttClient client = new MqttClient(brokerUrl, publisherId, persistence);

        MqttConnectOptions options = new MqttConnectOptions();
        options.setAutomaticReconnect(true);
        // CleanSession=false: брокер сохраняет состояние сессии и буферизует
        // неподтверждённые QoS 1/2 сообщения на время отсутствия клиента
        options.setCleanSession(false);
        options.setConnectionTimeout(10);

        log.info("Подключение к MQTT-брокеру: {} как {}", brokerUrl, publisherId);

        // Retry-цикл: брокер может быть ещё не готов при старте контейнера
        MqttException lastException = null;
        for (int attempt = 1; attempt <= MAX_CONNECT_RETRIES; attempt++) {
            try {
                client.connect(options);
                log.info("Подключение установлено успешно (попытка {}/{})", attempt, MAX_CONNECT_RETRIES);
                return client;
            } catch (MqttException e) {
                lastException = e;
                log.warn("Попытка подключения {}/{} неудачна: {}. Повтор через {} мс...",
                        attempt, MAX_CONNECT_RETRIES, e.getMessage(), RETRY_INTERVAL_MS);
                if (attempt < MAX_CONNECT_RETRIES) {
                    Thread.sleep(RETRY_INTERVAL_MS);
                }
            }
        }

        throw new MqttException(lastException.getReasonCode());
    }
}