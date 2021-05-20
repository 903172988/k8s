FROM 192.168.254.131/k8s/tomcat:8.0.51-alpine

# 拷贝到Tomcat的部署目录下
COPY target/ROOT /usr/local/tomcat/webapps/ROOT
# 拷贝自定义启动脚本
COPY start.sh /usr/local/tomcat/bin/start.sh

ENTRYPOINT ["sh", "/usr/local/tomcat/bin/start.sh"]