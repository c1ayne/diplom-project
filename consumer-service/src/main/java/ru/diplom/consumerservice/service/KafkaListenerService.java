package ru.diplom.consumerservice.service;

import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Service;

import java.util.Collections;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class KafkaListenerService {

    private final Set<String> processedMessageIds = Collections.newSetFromMap(new ConcurrentHashMap<>());

    @KafkaListener(topics = "kafka-telemetry", groupId = "telemetry_group")
    public void listenTelemetry(ConsumerRecord<String, String> record) {

        String messageId = generateUniqueId(record);

        if (processedMessageIds.contains(messageId)) {
            System.out.println("Duplicate detected, skipping: " + messageId);
            return;
        }

        if (record.value().contains("poison")) {
            throw new RuntimeException("Simulated Poison Pill Error!");
        }

        System.out.println("   [Telemetry] Received:");
        System.out.println("   Key (Original Topic): " + record.key());
        System.out.println("   Value: " + record.value());
        System.out.println("   Partition: " + record.partition() + ", Offset: " + record.offset());

        if (processedMessageIds.size() > 1000) processedMessageIds.clear();
        processedMessageIds.add(messageId);
    }

    @KafkaListener(topics = "kafka-critical", groupId = "alert_group")
    public void listenCritical(ConsumerRecord<String, String> record) {

        String messageId = generateUniqueId(record);

        if (processedMessageIds.contains(messageId)) {
            System.err.println("⚠️ Duplicate ALARM detected, skipping: " + messageId);
            return;
        }

        if (record.value().contains("poison")) {
            throw new RuntimeException("Simulated Poison Pill Error in ALARM!");
        }

        System.err.println("   [ALARM] CRITICAL EVENT RECEIVED:");
        System.err.println("   Source: " + record.key());
        System.err.println("   Payload: " + record.value());

        if (processedMessageIds.size() > 1000) processedMessageIds.clear();
        processedMessageIds.add(messageId);
    }

    private String generateUniqueId(ConsumerRecord<?, ?> record) {
        return record.topic() + "-" + record.partition() + record.offset();
    }
}
