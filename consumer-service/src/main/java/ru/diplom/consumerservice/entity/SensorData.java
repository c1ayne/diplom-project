package ru.diplom.consumerservice.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDateTime;

@Entity
@Table(name = "telemetry", indexes = {
        @Index(name = "idx_device_id", columnList = "deviceId"),
        @Index(name = "idx_timestamp", columnList = "timestamp")
})
@Getter @Setter
public class SensorData {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String deviceId;

    private String type;

    private Double value;

    private Long timestamp;

    private LocalDateTime createdAt;

    @PrePersist
    public void prePersist() {
        this.createdAt = LocalDateTime.now();
    }
}
