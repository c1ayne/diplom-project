package ru.diplom.consumerservice.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Service;
import ru.diplom.consumerservice.entity.SensorData;
import ru.diplom.consumerservice.repository.SensorDataRepository;

@Service
public class KafkaListenerService {

    private static final Logger log = LoggerFactory.getLogger(KafkaListenerService.class);

    private final SensorDataRepository repository;
    private final ObjectMapper objectMapper;

    public KafkaListenerService(SensorDataRepository repository, ObjectMapper objectMapper) {
        this.repository = repository;
        this.objectMapper = objectMapper;
    }

    /**
     * Обработчик телеметрических данных из топика kafka-telemetry.
     * Идемпотентность обеспечивается уникальным ограничением на уровне БД
     * по полю message_id (topic + partition + offset).
     */
    @KafkaListener(topics = "kafka-telemetry", groupId = "telemetry_group")
    public void listenTelemetry(ConsumerRecord<String, String> record) {
        log.info("[Telemetry] Получено сообщение: topic={}, partition={}, offset={}, key={}",
                record.topic(), record.partition(), record.offset(), record.key());

        processAndSave(record);
    }

    /**
     * Обработчик критических событий из топика kafka-critical.
     * Приоритетная обработка: логируется на уровне WARN для выделения в мониторинге.
     */
    @KafkaListener(topics = "kafka-critical", groupId = "alert_group")
    public void listenCritical(ConsumerRecord<String, String> record) {
        log.warn("[CRITICAL] Получено критическое событие: topic={}, partition={}, offset={}, source={}",
                record.topic(), record.partition(), record.offset(), record.key());

        processAndSave(record);
    }

    /**
     * Общий метод парсинга и сохранения сообщения в БД.
     * Уникальный messageId формируется из координат записи в Kafka (topic-partition-offset),
     * что обеспечивает идемпотентность на уровне персистентного хранилища:
     * повторная запись с тем же messageId будет отклонена ограничением уникальности БД.
     *
     * @param record запись из Kafka с метаданными и payload
     */
    private void processAndSave(ConsumerRecord<String, String> record) {
        // Симуляция "отравленного" сообщения для тестирования DLQ
        if (record.value().contains("poison")) {
            throw new RuntimeException("Симуляция Poison Pill: сообщение направляется в DLQ");
        }

        String messageId = generateMessageId(record);

        // Проверка дубликата через БД — идемпотентность переживает перезапуск сервиса
        if (repository.existsByMessageId(messageId)) {
            log.warn("Дубликат обнаружен, пропуск: messageId={}", messageId);
            return;
        }

        try {
            JsonNode json = objectMapper.readTree(record.value());

            SensorData data = new SensorData();
            data.setMessageId(messageId);
            data.setDeviceId(json.get("deviceId").asText());
            data.setType(json.get("type").asText());
            data.setValue(json.get("value").asDouble());
            data.setTimestamp(json.get("timestamp").asLong());

            repository.save(data);

            log.info("[DB] Сохранено: messageId={}, deviceId={}", messageId, data.getDeviceId());

        } catch (Exception e) {
            log.error("[DB] Ошибка сохранения: messageId={}, причина={}", messageId, e.getMessage(), e);
            // Перебрасываем исключение, чтобы сработал DefaultErrorHandler → DLQ
            throw new RuntimeException("Ошибка обработки сообщения: " + messageId, e);
        }
    }

    /**
     * Формирует уникальный идентификатор сообщения на основе координат записи в Kafka.
     * Комбинация topic + partition + offset гарантированно уникальна в рамках кластера.
     */
    private String generateMessageId(ConsumerRecord<?, ?> record) {
        return record.topic() + "-" + record.partition() + "-" + record.offset();
    }
}