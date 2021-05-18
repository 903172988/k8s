FROM 192.168.243.138/kubernetes/tomcat:latest

# 拷贝到Tomcat的部署目录下
COPY ROOT /usr/local/tomcat/webapps/ROOT
# 拷贝自定义启动脚本
COPY dockerfiles/my_start.sh /usr/local/tomcat/bin/my_start.sh

ENTRYPOINT ["sh", "/usr/local/tomcat/bin/my_start.sh"]