package ru.diplom.loadtester;

/**
 * Модель данных датчика — идентична модели в модуле generator.
 * Используется для генерации JSON-payload при нагрузочном тестировании.
 */
public class SensorData {

    private String deviceId;
    private Long timestamp;
    private String type;
    private double value;

    public SensorData() {}

    public SensorData(String deviceId, Long timestamp, String type, double value) {
        this.deviceId = deviceId;
        this.timestamp = timestamp;
        this.type = type;
        this.value = value;
    }

    public String getDeviceId()              { return deviceId; }
    public void setDeviceId(String deviceId) { this.deviceId = deviceId; }

    public Long getTimestamp()               { return timestamp; }
    public void setTimestamp(Long timestamp) { this.timestamp = timestamp; }

    public String getType()                  { return type; }
    public void setType(String type)         { this.type = type; }

    public double getValue()                 { return value; }
    public void setValue(double value)       { this.value = value; }
}