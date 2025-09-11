FROM registry.redhat.io/ubi9/openjdk-17
LABEL io.openshift.s2i.scripts-url="image:///usr/libexec/s2i"

COPY target/*.jar /app.jar

ENTRYPOINT ["java","-jar","/app.jar"]

EXPOSE 8080
