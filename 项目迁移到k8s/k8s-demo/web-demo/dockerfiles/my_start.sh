#!/bin/bash

sh /usr/local/tomcat/bin/startup.sh

# 为了让容器不会退出
tail -f /usr/local/tomcat/logs/catalina.out
