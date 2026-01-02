package ru.diplom;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@AllArgsConstructor
public class SensorData {
    String deviceId;
    Long timestamp;
    String type;
    double value;
}
