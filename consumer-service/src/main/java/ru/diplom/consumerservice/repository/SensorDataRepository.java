package ru.diplom.consumerservice.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import ru.diplom.consumerservice.entity.SensorData;

@Repository
public interface SensorDataRepository extends JpaRepository<SensorData, Long> {

    /**
     * Проверяет существование записи с указанным messageId.
     *
     * @param messageId уникальный идентификатор сообщения (topic-partition-offset)
     * @return true, если запись с таким messageId уже существует
     */
    boolean existsByMessageId(String messageId);
}