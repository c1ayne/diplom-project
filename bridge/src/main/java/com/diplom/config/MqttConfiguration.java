package com.diplom.config;

import org.eclipse.paho.client.mqttv3.MqttConnectOptions;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.integration.channel.DirectChannel;
import org.springframework.integration.core.MessageProducer;
import org.springframework.integration.mqtt.core.DefaultMqttPahoClientFactory;
import org.springframework.integration.mqtt.core.MqttPahoClientFactory;
import org.springframework.integration.mqtt.inbound.MqttPahoMessageDrivenChannelAdapter;
import org.springframework.integration.mqtt.support.DefaultPahoMessageConverter;
import org.springframework.messaging.MessageChannel;

import java.util.Arrays;
import java.util.UUID;

/**
 * Конфигурация MQTT-подписчика на основе Spring Integration.
 *
 * Ключевые решения:
 * - CleanSession=false: брокер сохраняет состояние сессии и буферизует
 *   неподтверждённые QoS 1 сообщения на время переподключения моста.
 *   В сочетании с QoS 1 это обеспечивает гарантию at-least-once на входе пайплайна.
 * - Shared Subscriptions ($share/bridge-group/...): позволяют запускать несколько
 *   экземпляров моста одновременно — брокер балансирует сообщения между ними,
 *   обеспечивая горизонтальное масштабирование без дублирования обработки.
 */
@Configuration
public class MqttConfiguration {

    private static final Logger log = LoggerFactory.getLogger(MqttConfiguration.class);

    @Value("${app.mqtt.broker-url}")
    private String brokerUrl;

    @Value("${app.mqtt.topics}")
    private String[] topics;

    @Bean
    public MqttPahoClientFactory mqttClientFactory() {
        DefaultMqttPahoClientFactory factory = new DefaultMqttPahoClientFactory();
        MqttConnectOptions options = new MqttConnectOptions();
        options.setServerURIs(new String[]{brokerUrl});
        options.setAutomaticReconnect(true);
        // CleanSession=false: брокер сохраняет состояние сессии между переподключениями,
        // гарантируя доставку буферизованных QoS 1 сообщений после восстановления связи
        options.setCleanSession(false);
        factory.setConnectionOptions(options);
        return factory;
    }

    @Bean
    public MessageChannel mqttInputChannel() {
        return new DirectChannel();
    }

    @Bean
    public MessageProducer inbound() {
        // UUID в clientId обеспечивает уникальность при горизонтальном масштабировании:
        // каждый экземпляр моста регистрируется в брокере под своим идентификатором
        String clientId = "bridge-" + UUID.randomUUID();

        // Shared Subscriptions: префикс $share/<group>/<topic> инструктирует брокер
        // доставлять каждое сообщение только одному подписчику из группы (балансировка нагрузки)
        String[] sharedTopics = new String[topics.length];
        for (int i = 0; i < topics.length; i++) {
            sharedTopics[i] = "$share/bridge-group/" + topics[i].trim();
        }

        log.info("Активация Shared Subscription: {}", Arrays.toString(sharedTopics));

        MqttPahoMessageDrivenChannelAdapter adapter =
                new MqttPahoMessageDrivenChannelAdapter(clientId, mqttClientFactory(), sharedTopics);
        adapter.setCompletionTimeout(5000);
        adapter.setConverter(new DefaultPahoMessageConverter());
        adapter.setQos(1);
        adapter.setOutputChannel(mqttInputChannel());
        return adapter;
    }
}