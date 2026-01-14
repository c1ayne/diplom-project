package ru.diplom.consumerservice.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import ru.diplom.consumerservice.entity.SensorData;

@Repository
public interface SensorDataRepository extends JpaRepository<SensorData, Long> {
}
