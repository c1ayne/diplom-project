package com.diplom.config;

import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.common.serialization.StringSerializer;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.core.DefaultKafkaProducerFactory;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.core.ProducerFactory;

import java.util.HashMap;
import java.util.Map;

/**
 * Конфигурация Kafka-продюсера.
 *
 * Параметры надёжности:
 * - acks=all: подтверждение от лидера и всех синхронных реплик (ISR) перед
 *   подтверждением записи продюсеру — максимальная гарантия сохранности данных.
 * - enable.idempotence=true: продюсер присваивает каждому сообщению уникальный
 *   sequence number, что исключает дубликаты при повторных отправках после сбоя сети.
 *
 * Параметры производительности:
 * - linger.ms=20: продюсер накапливает сообщения до 20 мс перед отправкой пакета,
 *   увеличивая пропускную способность за счёт батчинга.
 * - batch.size=16384: максимальный размер пакета в байтах (16 КБ).
 * - buffer.memory=33554432: объём буфера продюсера в байтах (32 МБ).
 */
@Configuration
public class KafkaConfiguration {

    @Value("${spring.kafka.bootstrap-servers}")
    private String bootstrapServers;

    @Bean
    public ProducerFactory<String, String> producerFactory() {
        Map<String, Object> configProps = new HashMap<>();

        // Адрес кластера Kafka
        configProps.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);

        // Сериализаторы ключа и значения
        configProps.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
        configProps.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class);

        // Гарантии надёжности: acks=all + идемпотентность
        configProps.put(ProducerConfig.ACKS_CONFIG, "all");
        configProps.put(ProducerConfig.ENABLE_IDEMPOTENCE_CONFIG, true);

        // Параметры производительности (дублируют application.yaml явно,
        // так как ProducerFactory создаётся вручную и не читает spring.kafka.producer.*)
        configProps.put(ProducerConfig.LINGER_MS_CONFIG, 20);
        configProps.put(ProducerConfig.BATCH_SIZE_CONFIG, 16384);
        configProps.put(ProducerConfig.BUFFER_MEMORY_CONFIG, 33554432L);

        return new DefaultKafkaProducerFactory<>(configProps);
    }

    @Bean
    public KafkaTemplate<String, String> kafkaTemplate() {
        return new KafkaTemplate<>(producerFactory());
    }
}