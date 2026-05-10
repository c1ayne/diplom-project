package ru.diplom.consumerservice.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDateTime;

/**
 * Сущность для хранения телеметрических данных и критических событий от IoT-устройств.
 */
@Entity
@Table(name = "telemetry", indexes = {
        @Index(name = "idx_device_id", columnList = "deviceId"),
        @Index(name = "idx_timestamp", columnList = "timestamp"),
        @Index(name = "idx_message_id", columnList = "messageId")
})
@Getter @Setter
public class SensorData {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /**
     * Уникальный идентификатор сообщения: topic-partition-offset.
     * Используется для предотвращения повторной обработки дубликатов (идемпотентность).
     */
    @Column(nullable = false, unique = true, length = 128)
    private String messageId;

    @Column(nullable = false)
    private String deviceId;

    private String type;

    private Double value;

    /**
     * Unix-timestamp в миллисекундах — момент генерации события на устройстве.
     */
    private Long timestamp;

    /**
     * Момент сохранения записи в БД — устанавливается автоматически перед persist.
     */
    private LocalDateTime createdAt;

    @PrePersist
    public void prePersist() {
        this.createdAt = LocalDateTime.now();
    }
}