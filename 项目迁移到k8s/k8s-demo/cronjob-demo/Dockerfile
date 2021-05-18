FROM 192.168.243.138/kubernetes/openjdk:latest

COPY target/cronjob-demo-1.0-SNAPSHOT.jar /cronjob-demo.jar

ENTRYPOINT ["java", "-cp", "cronjob-demo.jar", "com.example.demo.cronjob.Main"]