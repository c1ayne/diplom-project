package com.diplom;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Точка входа MQTT-Kafka Bridge.
 * Конфигурация Kafka-продюсера вынесена в KafkaConfiguration,
 * конфигурация MQTT-подписчика — в MqttConfiguration.
 */
@SpringBootApplication
public class BridgeApplication {

    public static void main(String[] args) {
        SpringApplication.run(BridgeApplication.class, args);
    }
}