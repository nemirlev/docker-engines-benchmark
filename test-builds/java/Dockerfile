# Multi-stage build for Spring Boot application
FROM maven:3.8.4-openjdk-17 AS builder

WORKDIR /app

RUN mkdir -p src/main/java/com/example/demo

# Copy configuration files
COPY pom.xml .
COPY DemoApplication.java src/main/java/com/example/demo/

# Download dependencies and build
RUN mvn dependency:go-offline
RUN mvn package -DskipTests

# Final stage
FROM openjdk:17-slim
COPY --from=builder /app/target/*.jar app.jar
ENTRYPOINT ["java","-jar","/app.jar"]