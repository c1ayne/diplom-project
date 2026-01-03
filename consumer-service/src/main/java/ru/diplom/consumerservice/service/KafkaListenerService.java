package ru.diplom.consumerservice.service;

import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Service;

@Service
public class KafkaListenerService {

    @KafkaListener(topics = "kafka-telemetry", groupId = "telemetry_group")
    public void listenTelemetry(ConsumerRecord<String, String> record) {
        System.out.println("   [Telemetry] Received:");
        System.out.println("   Key (Original Topic): " + record.key());
        System.out.println("   Value: " + record.value());
        System.out.println("   Partition: " + record.partition() + ", Offset: " + record.offset());
    }

    @KafkaListener(topics = "kafka-critical", groupId = "alert_group")
    public void listenCritical(ConsumerRecord<String, String> record) {
        System.err.println("   [ALARM] CRITICAL EVENT RECEIVED:");
        System.err.println("   Source: " + record.key());
        System.err.println("   Payload: " + record.value());
    }
}
