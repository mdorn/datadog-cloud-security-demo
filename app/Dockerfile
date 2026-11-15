FROM maven:3.8.6-eclipse-temurin-8@sha256:9e0cb7a6d15f3b0b59e11db52da2ec06177063f70ee00e83ed09b57a13d46447 AS build
WORKDIR /src
COPY pom.xml .
RUN mvn -B -q dependency:go-offline
COPY src ./src
RUN mvn -B -q package dependency:copy-dependencies -DincludeScope=runtime -DoutputDirectory=target/lib

FROM openjdk:8u212-jre-slim-stretch@sha256:39bece5e977d0daeb0510335f2624b929f893c167a09e6fc4e28412bb78eeb90
WORKDIR /app
COPY --from=build /src/target/app.jar /app/app.jar
COPY --from=build /src/target/lib/ /app/lib/
USER 65534:65534
ENTRYPOINT ["java", "-Xmx128m", "-cp", "/app/app.jar:/app/lib/*", "demo.Heartbeat"]
