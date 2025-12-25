# Этап 1: Сборка приложения
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

# Этап 2: Запуск приложения
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar

# Мета информация
LABEL maintainer="your-email@example.com"
LABEL description="MQTT-Kafka Bridge для дипломного проекта"

# Порт для мониторинга (если добавим Actuator)
EXPOSE 8080

# Запуск приложения
ENTRYPOINT ["java", "-jar", "app.jar"]