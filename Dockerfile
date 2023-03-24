FROM registry.access.redhat.com/ubi8/openjdk-17-runtime:1.15-1

COPY target/*.jar /app.jar

ENTRYPOINT ["java","-jar","/app.jar"]

EXPOSE 8080