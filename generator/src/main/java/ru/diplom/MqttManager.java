package ru.diplom;

import org.eclipse.paho.client.mqttv3.MqttClient;
import org.eclipse.paho.client.mqttv3.MqttConnectOptions;
import org.eclipse.paho.client.mqttv3.MqttException;
import org.eclipse.paho.client.mqttv3.persist.MemoryPersistence;

import java.util.UUID;

public class MqttManager {

    public static MqttClient createClient() throws MqttException {
        String brokerUrl = System.getenv().getOrDefault("MQTT_BROKER_URL", "tcp://localhost:1883");
        String publisherId = "generator-" + UUID.randomUUID();

        MqttClient client = new MqttClient(brokerUrl, publisherId, new MemoryPersistence());

        MqttConnectOptions options = new MqttConnectOptions();

        options.setAutomaticReconnect(true);
        options.setCleanSession(true);
        options.setConnectionTimeout(10);

        System.out.println("Connect to MQTT broker: " + brokerUrl + "as " + publisherId);

        client.connect(options);

        System.out.println("Connection successfully");

        return client;
    }
}
