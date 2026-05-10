package ru.diplom.consumerservice.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.kafka.common.TopicPartition;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.core.KafkaOperations;
import org.springframework.kafka.listener.CommonErrorHandler;
import org.springframework.kafka.listener.DeadLetterPublishingRecoverer;
import org.springframework.kafka.listener.DefaultErrorHandler;
import org.springframework.util.backoff.ExponentialBackOff;

/**
 * Конфигурация Kafka-потребителя.
 * Настраивает стратегию обработки ошибок с экспоненциальным backoff
 * и маршрутизацией необработанных сообщений в Dead Letter Topic (DLT).
 */
@Configuration
public class KafkaConfig {

    private static final Logger log = LoggerFactory.getLogger(KafkaConfig.class);

    /**
     * Обработчик ошибок с экспоненциальным backoff и Dead Letter Queue.
     *
     * Стратегия повторных попыток:
     * - Начальный интервал: 1 сек
     * - Множитель: 2 (1с → 2с → 4с)
     * - Максимальный интервал: 10 сек
     * - Максимальное число попыток: 3
     *
     * После исчерпания попыток сообщение направляется в топик <original-topic>.DLT
     * для последующего анализа и ручной обработки.
     */
    @Bean
    public CommonErrorHandler errorHandler(KafkaOperations<Object, Object> template) {
        DeadLetterPublishingRecoverer recoverer = new DeadLetterPublishingRecoverer(
                template,
                (record, ex) -> {
                    log.error("Сообщение направляется в DLT: topic={}.DLT, partition={}, причина={}",
                            record.topic(), record.partition(), ex.getMessage());
                    return new TopicPartition(record.topic() + ".DLT", record.partition());
                });

        ExponentialBackOff backOff = new ExponentialBackOff(1000L, 2.0);
        backOff.setMaxInterval(10_000L);  // максимум 10 секунд между попытками
        backOff.setMaxElapsedTime(30_000L); // не более 30 секунд суммарно (~3 попытки)

        return new DefaultErrorHandler(recoverer, backOff);
    }

    @Bean
    public ObjectMapper objectMapper() {
        return new ObjectMapper();
    }
}