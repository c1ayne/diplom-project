package com.diplom.service;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.integration.annotation.ServiceActivator;
import org.springframework.integration.mqtt.support.MqttHeaders;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.messaging.Message;
import org.springframework.stereotype.Service;

import java.util.Queue;
import java.util.concurrent.ConcurrentLinkedQueue;

/**
 * Центральный компонент моста: маршрутизирует MQTT-сообщения в топики Kafka.
 *
 * Логика маршрутизации (соответствует ФТ-3):
 * - alerts/#  → kafka-critical   (приоритетный топик, acks=all)
 * - sensors/# → kafka-telemetry  (стандартный топик, acks=all)
 *
 * Отказоустойчивость:
 * - Circuit Breaker (Resilience4j) защищает от каскадных сбоев при недоступности Kafka.
 * - При открытом Circuit Breaker критические сообщения буферизуются в памяти
 *   и повторно отправляются при восстановлении соединения.
 * - Телеметрия при открытом Circuit Breaker отбрасывается (допустимо по условиям задачи).
 *
 * Ограничение: буфер критических сообщений хранится в памяти.
 * При перезапуске сервиса буферизованные сообщения будут потеряны.
 * Для production-среды следует использовать персистентный буфер (Redis, локальный файл).
 */
@Service
public class BridgeService {

    private static final Logger log = LoggerFactory.getLogger(BridgeService.class);

    private static final String KAFKA_TOPIC_CRITICAL  = "kafka-critical";
    private static final String KAFKA_TOPIC_TELEMETRY = "kafka-telemetry";

    // Максимальный размер буфера критических сообщений при открытом Circuit Breaker
    private static final int CRITICAL_BUFFER_MAX_SIZE = 1000;

    private final KafkaTemplate<String, String> kafkaTemplate;

    /**
     * Буфер критических сообщений на время недоступности Kafka.
     * ConcurrentLinkedQueue — потокобезопасная, неблокирующая очередь.
     */
    private final Queue<Message<String>> criticalMessageBuffer = new ConcurrentLinkedQueue<>();

    public BridgeService(KafkaTemplate<String, String> kafkaTemplate) {
        this.kafkaTemplate = kafkaTemplate;
    }

    /**
     * Основной обработчик входящих MQTT-сообщений.
     * Вызывается Spring Integration для каждого сообщения из mqttInputChannel.
     * Circuit Breaker перехватывает исключения Kafka и при превышении порога ошибок
     * перенаправляет вызов в fallback-метод.
     */
    @ServiceActivator(inputChannel = "mqttInputChannel")
    @CircuitBreaker(name = "kafkaBreaker", fallbackMethod = "kafkaFallback")
    public void routeMessage(Message<String> message) {
        // Попытка повторной отправки буферизованных критических сообщений
        drainCriticalBuffer();

        String payload   = message.getPayload();
        String mqttTopic = (String) message.getHeaders().get(MqttHeaders.RECEIVED_TOPIC);

        if (mqttTopic == null) {
            log.error("Получено сообщение без заголовка топика, пропуск");
            return;
        }

        String kafkaTopic;
        if (mqttTopic.startsWith("alerts/")) {
            kafkaTopic = KAFKA_TOPIC_CRITICAL;
            log.warn("[CRITICAL] Маршрутизация: {} -> {}", mqttTopic, kafkaTopic);
        } else {
            kafkaTopic = KAFKA_TOPIC_TELEMETRY;
            log.info("[Telemetry] Маршрутизация: {} -> {}", mqttTopic, kafkaTopic);
        }

        // Ключ сообщения = исходный MQTT-топик: обеспечивает упорядоченность
        // сообщений от одного устройства в рамках одной партиции Kafka
        kafkaTemplate.send(kafkaTopic, mqttTopic, payload);
    }

    /**
     * Fallback-метод при открытом Circuit Breaker (Kafka недоступна).
     *
     * Стратегия дифференцирована по критичности:
     * - Критические сообщения (alerts/#): буферизуются в памяти для повторной отправки.
     * - Телеметрия (sensors/#): отбрасывается — допустимая потеря при кратковременном сбое.
     */
    public void kafkaFallback(Message<String> message, Throwable t) {
        String mqttTopic = (String) message.getHeaders().get(MqttHeaders.RECEIVED_TOPIC);

        if (mqttTopic != null && mqttTopic.startsWith("alerts/")) {
            if (criticalMessageBuffer.size() < CRITICAL_BUFFER_MAX_SIZE) {
                criticalMessageBuffer.offer(message);
                log.error("[CIRCUIT OPEN] Критическое сообщение буферизовано (буфер: {}/{}): {}",
                        criticalMessageBuffer.size(), CRITICAL_BUFFER_MAX_SIZE, mqttTopic);
            } else {
                log.error("[CIRCUIT OPEN] Буфер критических сообщений переполнен! Сообщение отброшено: {}", mqttTopic);
            }
        } else {
            log.warn("[CIRCUIT OPEN] Телеметрия отброшена: {}", mqttTopic);
        }
    }

    /**
     * Повторная отправка буферизованных критических сообщений.
     * Вызывается в начале каждого успешного вызова routeMessage,
     * когда Circuit Breaker находится в состоянии CLOSED или HALF_OPEN.
     */
    private void drainCriticalBuffer() {
        if (criticalMessageBuffer.isEmpty()) return;

        log.info("Повторная отправка буферизованных критических сообщений: {} шт.", criticalMessageBuffer.size());

        Message<String> buffered;
        while ((buffered = criticalMessageBuffer.poll()) != null) {
            String mqttTopic = (String) buffered.getHeaders().get(MqttHeaders.RECEIVED_TOPIC);
            kafkaTemplate.send(KAFKA_TOPIC_CRITICAL, mqttTopic, buffered.getPayload());
            log.info("[BUFFER DRAIN] Повторно отправлено: {}", mqttTopic);
        }
    }
}