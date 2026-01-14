package ru.diplom.consumerservice.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.kafka.common.TopicPartition;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.core.KafkaOperations;
import org.springframework.kafka.listener.CommonErrorHandler;
import org.springframework.kafka.listener.DeadLetterPublishingRecoverer;
import org.springframework.kafka.listener.DefaultErrorHandler;
import org.springframework.util.backoff.FixedBackOff;

@Configuration
public class KafkaConfig {

    @Bean
    public CommonErrorHandler errorHandler(KafkaOperations<Object, Object> template) {
        DeadLetterPublishingRecoverer recoverer = new DeadLetterPublishingRecoverer(
                template,
                (record, ex) -> {
                    System.out.println("Sending to DLQ: " + record.topic() + ".DLT | Reason: " + ex.getMessage());
                    return new TopicPartition(record.topic() + ".DLT", record.partition());
                });

        return new DefaultErrorHandler(recoverer, new FixedBackOff(1000L, 2));
    }

    @Bean
    public ObjectMapper objectMapper() {
        return new ObjectMapper();
    }
}
