FROM 192.168.254.131/k8s/openjdk:8-jre-alpine

COPY target/cronjob-demo-1.0-SNAPSHOT.jar /cronjob-demo.jar

ENTRYPOINT ["java", "-cp", "cronjob-demo.jar", "com.example.demo.cronjob.Main"]