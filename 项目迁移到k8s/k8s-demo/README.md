[TOC]


# 四种常见业务系统迁移至kubernetes


----------


## 定时任务迁移kubernetes

项目结构如下，这是一个很简单的maven项目，没有任何外部依赖：

![输入图片说明](https://images.gitee.com/uploads/images/2020/0908/180858_2f47b5ca_1765987.png "屏幕截图.png")


项目中只有一个`Main`类，代码如下：
```java
package com.example.demo.cronjob;

import java.util.Random;

public class Main {

    public static void main(String[] args) {

        Random r = new Random();
        int time = r.nextInt(20) + 10;
        System.out.println("I will working for " + time + " seconds!");

        try {
            Thread.sleep(time * 1000);
        } catch (Exception e) {
            e.printStackTrace();
        }
        System.out.println("All work is done! Bye!");
    }
}
```

以往我们是将项目部署到Linux系统上，然后通过`crontab`定时执行这个项目。那么迁移到k8s后，该如何让k8s定时执行这个项目呢？这就是本小节将要介绍的内容。

将业务系统迁移到Kubernetes主要需要经过两大步：
![输入图片说明](https://images.gitee.com/uploads/images/2020/0908/180908_8482f9cc_1765987.png "屏幕截图.png")

1、搞定基础镜像，Java项目自然需要运行在有JRE环境的容器里，所以直接上docker hub搜索下Java这个关键词使用官方的镜像即可。docker hub上现在的Java镜像是openjdk，所以我们直接拉取openjdk即可：
```bash
[root@s1 ~]# docker pull openjdk
```

然后将镜像改下tag并推到我们自己的Harbor仓库上：
```bash
[root@s1 ~]# docker tag openjdk:latest 192.168.243.138/kubernetes/openjdk:latest
[root@s1 ~]# docker push 192.168.243.138/kubernetes/openjdk:latest
```

2、搞定服务运行的相关文件，项目中就只有一个类，我们直接通过maven进行打包即可：
```bash
$ mvn clean package -Dmaven.test.skip=true
```

最终我们得到一个jar包：
```bash
[root@s1 ~/cronjob]# ls
cronjob-demo-1.0-SNAPSHOT.jar
[root@s1 ~/cronjob]# 
```

3、构建镜像，创建一个Dockerfile，内容如下：
```bash
[root@s1 ~/cronjob]# vim Dockerfile
FROM 192.168.243.138/kubernetes/openjdk:latest

COPY cronjob-demo-1.0-SNAPSHOT.jar /cronjob-demo.jar

ENTRYPOINT ["java", "-cp", "cronjob-demo.jar", "com.example.demo.cronjob.Main"]
```

build 镜像：
```bash
[root@s1 ~/cronjob]# docker build -t cronjob:v1 .
```

测试能否正常运行：
```bash
[root@s1 ~/cronjob]# docker run -it cronjob:v1
I will working for 12 seconds!
All work is done! Bye!
[root@s1 ~/cronjob]# 
```

把该镜像推到我们自己的Harbor仓库上：
```bash
[root@s1 ~/cronjob]# docker tag cronjob:v1 192.168.243.138/kubernetes/cronjob:v1
[root@s1 ~/cronjob]# docker push 192.168.243.138/kubernetes/cronjob:v1
```

4、确定服务发现的策略，由于这只是一个定时任务，不需要服务发现，所以这一步略过

5、编写k8s配置文件：
```yml
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: cronjob-demo
spec:
  # 定义cron表达式，与linux里的表达式是一样的
  schedule: "*/1 * * * *"
  # 保留执行成功的3个历史job
  successfulJobsHistoryLimit: 3
  # 是否挂起，如果设置为true则任务不会真正被执行
  suspend: false
  # 并行的策略
  concurrencyPolicy: Forbid
  # 保留执行失败的1个历史job
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        metadata:
          labels:
            app: cronjob-demo
        spec:
          # 重启策略
          restartPolicy: Never
          containers:
          - name: cronjob-demo
            image: 192.168.243.138/kubernetes/cronjob:v1
```

将`cronjob`部署到k8s上：
```bash
[root@m1 ~/cronjob]# kubectl apply -f cronjob.yaml 
cronjob.batch/cronjob-demo created
[root@m1 ~/cronjob]# 
```

部署完成后，查看运行情况：
```bash
[root@m1 ~/cronjob]# kubectl get cronjobs
NAME           SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
cronjob-demo   */1 * * * *   False     0        <none>          29s
[root@m1 ~/cronjob]# kubectl get cronjobs
NAME           SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
cronjob-demo   */1 * * * *   False     1        12s             43s
[root@m1 ~/cronjob]# kubectl get pods
NAME                            READY   STATUS      RESTARTS   AGE
cronjob-demo-1599535980-brd88   0/1     Completed   0          37s
[root@m1 ~/cronjob]# kubectl logs cronjob-demo-1599535980-brd88
I will working for 15 seconds!
All work is done! Bye!
[root@m1 ~/cronjob]# 
```


----------



## SpringBoot的web服务迁移kubernetes

项目结构如下：

![输入图片说明](https://images.gitee.com/uploads/images/2020/0908/180938_d767ec3b_1765987.png "屏幕截图.png")

这是一个最基础的SpringBoot web服务，启动类和maven依赖没啥好说的，controller的内容如下：
```java
package com.example.demo.controller;

import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class DemoController {

    @RequestMapping("/hello")
    public String sayHello(@RequestParam String name) {
        return "Hello " + name + "! I'm springboot-web-demo controller!";
    }
}
```

配置文件的内容如下：
```bash
server.name=springboot-web-demo
server.port=8080
```

按照之前的步骤，把项目打成jar包：
```bash
[root@m1 ~/spring-boot-web]# ls
springboot-web-demo-1.0-SNAPSHOT.jar
[root@m1 ~/spring-boot-web]# 
```

编写Dockerfile：
```bash
[root@m1 ~/spring-boot-web]# vim Dockerfile
FROM 192.168.243.138/kubernetes/openjdk:latest

COPY springboot-web-demo-1.0-SNAPSHOT.jar /springboot-web-demo.jar

ENTRYPOINT ["java", "-jar", "springboot-web-demo.jar"]
```

build 镜像：
```bash
[root@s1 ~/spring-boot-web]# docker build -t springboot-web-demo:v1 .
```

测试能否正常运行：
```bash
[root@m1 ~/spring-boot-web]# docker run -it springboot-web-demo:v1
```

把该镜像推到我们自己的Harbor仓库上：
```bash
[root@s1 ~/spring-boot-web]# docker tag springboot-web-demo:v1 192.168.243.138/kubernetes/springboot-web-demo:v1
[root@s1 ~/spring-boot-web]# docker push 192.168.243.138/kubernetes/springboot-web-demo:v1
```

由于这是一个需要提供给外部访问的web服务，所以我们需要确定服务发现的策略，这里采用的就是之前我们搭建的ingress-nginx。编写k8s配置文件：
```yaml
#deploy
apiVersion: apps/v1
kind: Deployment
metadata:
  name: springboot-web-demo
spec:
  selector:
    matchLabels:
      app: springboot-web-demo
  replicas: 1
  template:
    metadata:
      labels:
        app: springboot-web-demo
    spec:
      containers:
      - name: springboot-web-demo
        image: 192.168.243.138/kubernetes/springboot-web-demo:v1
        ports:
        - containerPort: 8080
---
#service
apiVersion: v1
kind: Service
metadata:
  name: springboot-web-demo
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 8080
  selector:
    app: springboot-web-demo
  type: ClusterIP

---
#ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: springboot-web-demo
spec:
  rules:
  - host: springboot.web.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service: 
            name: springboot-web-demo
            port:
              number:  80
```


将`springboot-web-demo`部署到k8s上：
```bash
[root@m1 ~/spring-boot-web]# kubectl apply -f springboot-web.yaml 
```

查看运行状态：
```bash
[root@m1 ~/spring-boot-web]# kubectl get pods |grep spring
springboot-web-demo-565c9986dd-fngnm   1/1     Running     0          11s
[root@m1 ~/spring-boot-web]# kubectl get svc |grep spring
springboot-web-demo   ClusterIP   10.97.87.31      <none>        80/TCP    3m4s
[root@m1 ~/spring-boot-web]# kubectl get deployments |grep spring
springboot-web-demo   1/1     1            1           3m27s
[root@m1 ~/spring-boot-web]# 
```

为了使得访问`springboot.web.com`域名能够请求到部署了`ingress-nginx`服务的`worker`节点上，需要在本机的`hosts`文件中添加一行配置，这里的ip为部署了`ingress-nginx`节点的ip：
```bash
192.168.243.140 springboot.web.com
```

外部访问测试：
![输入图片说明](https://images.gitee.com/uploads/images/2020/0908/180950_e7ce24a1_1765987.png "屏幕截图.png")


----------


## 传统dubbo服务迁移kubernetes

项目结构如下：

![输入图片说明](https://images.gitee.com/uploads/images/2020/0908/180956_d6c70999_1765987.png "屏幕截图.png")

首先看`dubbo-demo-api`项目，里面定义的是需要给外部调用的服务api，其表现形式就是一个Java接口。代码如下：
```java
package com.example.demo.api;

public interface DemoService {

    String sayHello(String name);
}
```

然后再看`dubbo-demo`项目，这是服务提供者（provider）的具体实现，实现了api项目里定义的接口。代码如下：
```java
package com.example.demo.service;

import com.example.demo.api.DemoService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class DemoServiceImpl implements DemoService {

    private static final Logger log = LoggerFactory.getLogger(DemoServiceImpl.class);

    @Override
    public String sayHello(String name) {
        log.debug("dubbo say hello to : {}", name);
        return "Hello " + name;
    }
}
```

`provider.xml`文件里则定义了服务提供者的信息，如service的api及其实现类路径等：
```xml
<beans xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xmlns:dubbo="http://dubbo.apache.org/schema/dubbo"
       xmlns="http://www.springframework.org/schema/beans"
       xsi:schemaLocation="http://www.springframework.org/schema/beans http://www.springframework.org/schema/beans/spring-beans-4.3.xsd
       http://dubbo.apache.org/schema/dubbo http://dubbo.apache.org/schema/dubbo/dubbo.xsd">

    <!-- service implementation, as same as regular local bean -->
    <bean id="demoService" class="com.example.demo.service.DemoServiceImpl"/>

    <!-- declare the service interface to be exported -->
    <dubbo:service interface="com.example.demo.api.DemoService" ref="demoService"/>

</beans>
```

`dubbo.properties`文件则定义了dubbo相关的一些配置信息：
```bash
# 服务名称
dubbo.application.name=demo
# zookeeper的注册地址
dubbo.registry.address=zookeeper://10.155.20.62:2181
# provider.xml文件的路径
dubbo.spring.config=classpath*:spring/provider.xml
# 协议名称
dubbo.protocol.name=dubbo
# 服务对外暴露的端口
dubbo.protocol.port=20880
```

了解完项目的基本内容后，我们将其打包一下，这与之前有点不一样。首先进入`dubbo-demo-api`项目，将其安装到本地仓库，因为`dubbo-demo`项目的pom文件依赖了它：
```bash
$ mvn clean install -Dmaven.test.skip=true
```

然后对`dubbo-demo`项目进行打包：
```bash
$ mvn clean package -Dmaven.test.skip=true
```

打包成功会有一个压缩包和一个jar包：
```bash
[root@m1 ~/dubbo-demo]# ls
dubbo-demo-1.0-SNAPSHOT-assembly.tar.gz  dubbo-demo-1.0-SNAPSHOT.jar
[root@m1 ~/dubbo-demo]# 
```

将压缩包解压：
```bash
[root@m1 ~/dubbo-demo]# tar -zxvf dubbo-demo-1.0-SNAPSHOT-assembly.tar.gz
```

执行启动脚本启动该项目：
```bash
[root@m1 ~/dubbo-demo]# bin/start.sh 
Starting the demo ...PID: 
STDOUT: /root/dubbo-demo/logs/stdout.log
[root@m1 ~/dubbo-demo]# 
```

查看日志输出：
```bash
[root@m1 ~/dubbo-demo]# cat logs/stdout.log 
[2020-09-08 16:07:22] Dubbo service server started!
[root@m1 ~/dubbo-demo]# 
```

查看端口是否有正常监听：
```bash
[root@m1 ~/dubbo-demo]# netstat -lntp |grep 20880
tcp        0      0 0.0.0.0:20880           0.0.0.0:*        LISTEN      99949/java          
[root@m1 ~/dubbo-demo]# 
```

使用`telnet`测试服务调用是否正常：
```bash
[root@m1 ~/dubbo-demo]# telnet 192.168.243.138 20880
Trying 192.168.243.138...
Connected to 192.168.243.138.
Escape character is '^]'.

dubbo>ls
com.example.demo.api.DemoService
dubbo>ls com.example.demo.api.DemoService
sayHello
dubbo>invoke com.example.demo.api.DemoService.sayHello("Zero")
"Hello Zero"
elapsed: 7 ms.
dubbo>
```

测试`stop.sh`脚本能否正常停止项目：
```bash
[root@m1 ~/dubbo-demo]# bin/stop.sh 
Stopping the demo ..................OK!
PID: 99949
[root@m1 ~/dubbo-demo]# netstat -lntp |grep 20880
[root@m1 ~/dubbo-demo]# 
```

测试完后，将压缩包里的内容解压到一个单独的目录下：
```bash
[root@m1 ~/dubbo-demo]# mkdir ROOT
[root@m1 ~/dubbo-demo]# tar -zxvf dubbo-demo-1.0-SNAPSHOT-assembly.tar.gz -C ROOT/
[root@m1 ~/dubbo-demo]# ls ROOT/
bin  conf  lib
[root@m1 ~/dubbo-demo]#
```

由于容器内部环境与操作系统环境是不一样的，所以我们需要修改`start.sh`启动脚本，修改后的内容如下：
```bash
[root@m1 ~/dubbo-demo]# vim ROOT/bin/start.sh
#!/bin/bash

cd `dirname $0`
BIN_DIR=`pwd`
cd ..

DEPLOY_DIR=`pwd`
CONF_DIR=${DEPLOY_DIR}/conf

SERVER_NAME=`sed '/dubbo.application.name/!d;s/.*=//' conf/dubbo.properties | tr -d '\r'`
SERVER_PORT=`sed '/dubbo.protocol.port/!d;s/.*=//' conf/dubbo.properties | tr -d '\r'`

if [ -z "${SERVER_NAME}" ]; then
    echo "ERROR: can not found 'dubbo.application.name' config in 'dubbo.properties' !"
	exit 1
fi

LOGS_DIR=""
if [ -n "${LOGS_FILE}" ]; then
	LOGS_DIR=`dirname ${LOGS_FILE}`
else
	LOGS_DIR=${DEPLOY_DIR}/logs
fi
if [ ! -d ${LOGS_DIR} ]; then
	mkdir ${LOGS_DIR}
fi
STDOUT_FILE=${LOGS_DIR}/stdout.log

LIB_DIR=${DEPLOY_DIR}/lib
LIB_JARS=`ls ${LIB_DIR} | grep .jar | awk '{print "'${LIB_DIR}'/"$0}'|tr "\n" ":"`

JAVA_OPTS=" -Djava.awt.headless=true -Djava.net.preferIPv4Stack=true "
JAVA_DEBUG_OPTS=""
if [ "$1" = "debug" ]; then
    JAVA_DEBUG_OPTS=" -Xdebug -Xnoagent -Djava.compiler=NONE -Xrunjdwp:transport=dt_socket,address=8000,server=y,suspend=n "
fi

echo -e "Starting the ${SERVER_NAME} ...\c"

${JAVA_HOME}/bin/java -Dapp.name=${SERVER_NAME} ${JAVA_OPTS} ${JAVA_DEBUG_OPTS} ${JAVA_JMX_OPTS} -classpath ${CONF_DIR}:${LIB_JARS} com.alibaba.dubbo.container.Main
```

然后编写Dockerfile：
```bash
[root@m1 ~/dubbo-demo]# vim Dockerfile
FROM 192.168.243.138/kubernetes/openjdk:latest

COPY ROOT /ROOT

ENTRYPOINT ["sh", "/ROOT/bin/start.sh"]
```

build 镜像：
```bash
[root@m1 ~/dubbo-demo]# docker build -t dubbo-demo:v1 .
```

测试能否正常运行：
```bash
[root@m1 ~/dubbo-demo]# docker run -it dubbo-demo:v1
[2020-09-08 08:12:24] Dubbo service server started!
```

把该镜像推到我们自己的Harbor仓库上：
```bash
[root@m1 ~/dubbo-demo]# docker tag dubbo-demo:v1 192.168.243.138/kubernetes/dubbo-demo:v1
[root@m1 ~/dubbo-demo]# docker push 192.168.243.138/kubernetes/dubbo-demo:v1
```

确定服务发现的策略，dubbo的服务发现策略其实是不太好选择的，因为不管哪种策略都不是那么的合适，所以没有一个通用的策略，需要视具体情况而定。在这里我们选择了`hostNetwork`这种模式，将dubbo服务的通过宿主机暴露出来。

`hostNetwork`模式也有一个问题，就是端口是监听在宿主机上的，万一其他dubbo服务也调度到了这台主机上，端口也是一样的话，就会发生端口冲突的问题。所以选择`hostNetwork`模式就必须保证每个dubbo服务的端口都不一样，由于要确保每个服务的端口都不一样，就得考虑有一个统一的地方管理好这些服务的端口。

编写k8s配置文件：
```yaml
#deploy
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dubbo-demo
spec:
  selector:
    matchLabels:
      app: dubbo-demo
  replicas: 1
  template:
    metadata:
      labels:
        app: dubbo-demo
    spec:
      hostNetwork: true
      affinity:
        podAntiAffinity:
          # 让多个实例不调度在同一个节点上，避免端口冲突
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - dubbo-demo
            topologyKey: "kubernetes.io/hostname"
      containers:
      - name: dubbo-demo
        image: 192.168.243.138/kubernetes/dubbo-demo:v1
        ports:
        - containerPort: 20880
```

将`dubbo-demo`部署到k8s上：
```bash
[root@m1 ~/dubbo-demo]# kubectl apply -f dubbo-demo.yaml 
```

查看运行状态：
```bash
[root@m1 ~/dubbo-demo]# kubectl get pods -o wide |grep dubbo
dubbo-demo-5b4c68f7b7-qvz88            1/1     Running            0          63s     192.168.243.139   s1     <none>           <none>
[root@m1 ~/dubbo-demo]# kubectl get deployments |grep dubbo
dubbo-demo            1/1     1            1           25s
[root@m1 ~/dubbo-demo]# 
```

可以看到该Pod被调度到了s1节点上，到s1节点上看看端口是否有正常监听：
```bash
[root@s1 ~]# netstat -lntp |grep 20880
tcp        0      0 0.0.0.0:20880           0.0.0.0:*         LISTEN      4573/java           
[root@s1 ~]# 
```

使用`telnet`测试服务调用是否正常：
```bash
[root@s1 ~]# telnet 127.0.0.1 20880
Trying 127.0.0.1...
Connected to 127.0.0.1.
Escape character is '^]'.

dubbo>invoke com.example.demo.api.DemoService.sayHello("Zero")
"Hello Zero"
elapsed: 4 ms.
dubbo>
```


----------


## 传统web服务迁移kubernetes

项目结构如下：

![输入图片说明](https://images.gitee.com/uploads/images/2020/0908/181012_4226b1a8_1765987.png "屏幕截图.png")

这是一个典型的传统web项目，配置文件都是标准的没啥好说的。其中controller的代码如下，调用了之前我们部署的dubbo服务：
```java
package com.example.demo.controller;

import com.example.demo.api.DemoService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;

@Controller
public class DemoController {

    private static final Logger log = LoggerFactory.getLogger(DemoController.class);

    @Autowired
    private DemoService demoService;

    @RequestMapping("/hello")
    @ResponseBody
    public String sayHello(@RequestParam String name) {
        log.debug("say hello to :{}", name);
        String message = demoService.sayHello(name);
        log.debug("dubbo result:{}", message);

        return message;
    }
}
```

由于传统的web服务是需要运行在Tomcat之类的web容器里的，所以就不能像之前那样只单纯使用一个Java镜像了。先准备好基础镜像并推到Harbor上：
```bash
[root@m1 ~/web-demo]# docker pull tomcat
[root@m1 ~/web-demo]# docker tag tomcat:latest 192.168.243.138/kubernetes/tomcat:latest
[root@m1 ~/web-demo]# docker push 192.168.243.138/kubernetes/tomcat:latest
```

然后通过maven对项目进行打包：
```bash
$ mvn clean package -Dmaven.test.skip=true
```

打出来的是一个war包：
```bash
[root@m1 ~/web-demo]# ls
web-demo-1.0-SNAPSHOT.war
[root@m1 ~/web-demo]# 
```

创建一个`ROOT`目录并将`war`包解压到该目录中：
```bash
[root@m1 ~/web-demo]# mkdir ROOT
[root@m1 ~/web-demo]# cd ROOT/
[root@m1 ~/web-demo/ROOT]# jar -xvf web-demo-1.0-SNAPSHOT.war
[root@m1 ~/web-demo/ROOT]# rm -rf web-demo-1.0-SNAPSHOT.war
```

由于Tomcat自带的启动脚本是后台启动的，会导致容器启动后就退出，所以我们需要自定义一个启动脚本hold住容器不会退出：
```bash
[root@m1 ~/web-demo]# vim my_start.sh
sh /usr/local/tomcat/bin/startup.sh

# 为了让容器不会退出
tail -f /usr/local/tomcat/logs/catalina.out
[root@m1 ~/web-demo]# chmod a+x my_start.sh
```

编写Dockerfile：
```bash
[root@m1 ~/web-demo]# vim Dockerfile
FROM 192.168.243.138/kubernetes/tomcat:latest

# 拷贝到Tomcat的部署目录下
COPY ROOT /usr/local/tomcat/webapps/ROOT
# 拷贝自定义启动脚本
COPY my_start.sh /usr/local/tomcat/bin/my_start.sh

ENTRYPOINT ["sh", "/usr/local/tomcat/bin/my_start.sh"]
```

build 镜像：
```bash
[root@m1 ~/web-demo]# docker build -t web-demo:v1 .
```

测试能否正常运行：
```bash
[root@m1 ~/web-demo]# docker run -it web-demo:v1
```

把该镜像推到我们自己的Harbor仓库上：
```bash
[root@m1 ~/web-demo]# docker tag web-demo:v1 192.168.243.138/kubernetes/web-demo:v1
[root@m1 ~/web-demo]# docker push 192.168.243.138/kubernetes/web-demo:v1
```

服务发现策略与之前演示的那个Spring Boot Web服务的策略是一样的，通过ingress-nginx暴露给外部访问。编写k8s配置文件：
```yml
#deploy
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-demo
spec:
  selector:
    matchLabels:
      app: web-demo
  replicas: 1
  template:
    metadata:
      labels:
        app: web-demo
    spec:
      containers:
      - name: web-demo
        image: 192.168.243.138/kubernetes/web-demo:v1
        ports:
        - containerPort: 8080
---
#service
apiVersion: v1
kind: Service
metadata:
  name: web-demo
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 8080
  selector:
    app: web-demo
  type: ClusterIP

---
#ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-demo
spec:
  rules:
    - host: demo.web.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web-demo
                port:
                  number:  80
```

将`web-demo`部署到k8s集群中：
```bash
[root@m1 ~/web-demo]# kubectl apply -f web-demo.yaml
```

查看服务运行状态：
```bash
[root@m1 ~/web-demo]# kubectl get pods |grep web-demo
springboot-web-demo-565c9986dd-fngnm   1/1     Running            0          3h26m
web-demo-67856887cd-4k2dd              1/1     Running            0          5m35s
[root@m1 ~/web-demo]# kubectl get svc |grep web-demo
springboot-web-demo   ClusterIP   10.97.87.31      <none>        80/TCP    3h29m
web-demo              ClusterIP   10.111.96.20     <none>        80/TCP    5m46s
[root@m1 ~/web-demo]# 
```

为了使得访问`demo.web.com`域名能够请求到部署了`ingress-nginx`服务的`worker`节点上，需要在本机的`hosts`文件中添加一行配置，这里的ip为部署了`ingress-nginx`节点的ip：
```bash
192.168.243.140 demo.web.com
```

外部访问测试：
![输入图片说明](https://images.gitee.com/uploads/images/2020/0908/181025_bc6d8545_1765987.png "屏幕截图.png")


----------

以上就是常见的四种常见业务系统迁移至k8s的演示，所有的代码在如下地址：
- https://gitee.com/Zero-One/k8s-demo

