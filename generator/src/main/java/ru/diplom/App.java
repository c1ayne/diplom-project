package ru.diplom;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.eclipse.paho.client.mqttv3.MqttClient;
import org.eclipse.paho.client.mqttv3.MqttException;
import org.eclipse.paho.client.mqttv3.MqttMessage;

import java.util.Random;
import java.util.concurrent.TimeUnit;

public class App {

    private static final String TOPIC_SENSOR_TEMPLATE = "sensors/factory/%s/telemetry";
    private static final String TOPIC_ALERT_TEMPLATE = "alerts/factory/%s/alarm";

    public static void main( String[] args ) {
        try {
            MqttClient client = MqttManager.createClient();

            ObjectMapper mapper = new ObjectMapper();
            Random random = new Random();

            String[] deviceIds = {"sensor-01", "sensor-02", "sensor-03", "pump-A", "pump-B"};

            System.out.println("Starting generation loops");

            while (true) {
                String deviceId = deviceIds[random.nextInt(deviceIds.length)];

                SensorData data = new SensorData();
                data.setDeviceId(deviceId);
                data.setTimestamp(System.currentTimeMillis());

                boolean isCritical = random.nextInt(10) == 0;

                String topic;

                if (isCritical) {
                    data.setType("CRITICAL_OVERHEAT");
                    data.setValue(80.0 + random.nextDouble() * 20);
                    topic = String.format(TOPIC_ALERT_TEMPLATE, deviceId);
                } else {
                    data.setType("TEMPERATURE");
                    data.setValue(20.0 + random.nextDouble() * 10);
                    topic = String.format(TOPIC_SENSOR_TEMPLATE, deviceId);
                }

                String jsonPayload = mapper.writeValueAsString(data);

                MqttMessage message = new MqttMessage(jsonPayload.getBytes());
                message.setQos(1);

                client.publish(topic, message);
                System.out.println("Sent to [" + topic + "]: " + jsonPayload);

                TimeUnit.MILLISECONDS.sleep(500);
            }
        } catch (MqttException e) {
            System.err.println("MQTT Error: " + e.getMessage());
            e.printStackTrace();
        } catch (Exception e) {
            System.err.println("Error: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
