package com.diplom.service;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import org.springframework.integration.annotation.ServiceActivator;
import org.springframework.integration.mqtt.support.MqttHeaders;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.messaging.Message;
import org.springframework.stereotype.Service;

@Service
public class BridgeService {

    private final KafkaTemplate<String, String> kafkaTemplate;

    public BridgeService(KafkaTemplate<String, String> kafkaTemplate) {
        this.kafkaTemplate = kafkaTemplate;
    }

    @ServiceActivator(inputChannel = "mqttInputChannel")
    @CircuitBreaker(name = "kafkaBreaker", fallbackMethod = "kafkaFallback")
    public void routeMessage(Message<String> message) {

        String payload = message.getPayload();
        String mqttTopic = (String) message.getHeaders().get(MqttHeaders.RECEIVED_TOPIC);

        if (mqttTopic == null) {
            System.err.println("Received message without topic header!");
            return;
        }

        String kafkaTopic;

        if (mqttTopic.startsWith("alerts/")) {
            kafkaTopic = "kafka-critical";
            System.out.println("  [CRITICAL] " + mqttTopic + " -> " + kafkaTopic);
        } else {
            kafkaTopic = "kafka-telemetry";
            System.out.println("  [Telemetry] " + mqttTopic + " -> " + kafkaTopic);
        }

        kafkaTemplate.send(kafkaTopic, mqttTopic, payload);
    }
}
