### docker-compose 安装

下载地址 https://github.com/docker/compose/releases/

![image-20210518100057385](C:\Users\90317\AppData\Roaming\Typora\typora-user-images\image-20210518100057385.png)

下载二进制文件，上传到服务器，重命名

```
 mv /tmp/docker-compose-Linux-x86_64 /usr/local/bin/docker-compose
```

验证

```
 docker-compose -v 
```

###  Docker 安装

下载地址：https://download.docker.com/linux/static/stable/x86_64/docker-19.03.9.tgz 

```shell
tar zxvf docker-19.03.9.tgz 
mv docker/* /usr/bin
```

使用systemd管理

```
cat > /usr/lib/systemd/system/docker.service << EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service
Wants=network-online.target
[Service]
Type=notify
ExecStart=/usr/bin/dockerd
ExecReload=/bin/kill -s HUP $MAINPID
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TimeoutStartSec=0
Delegate=yes
KillMode=process
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s
[Install]
WantedBy=multi-user.target
EOF
```

设置阿里云镜像加速器，登录阿里云可以查看自己的加速地址 https://cr.console.aliyun.com/cn-hangzhou/instances/mirrors

```shell
mkdir /etc/docker
cat > /etc/docker/daemon.json << EOF 
{
  "registry-mirrors": ["https://i9iblr0h.mirror.aliyuncs.com"] 这里修改为自己的地址
}
EOF
```

设置开机启动

```shell
systemctl daemon-reload 
systemctl start docker 
systemctl enable docker
```

### harbor安装

**harbor下载地址** https://github.com/goharbor/harbor/

![image-20210517203815469](C:\Users\90317\AppData\Roaming\Typora\typora-user-images\image-20210517203815469.png)



我这里使用的是**v1.6.0**版本，下载离线安装包

![image-20210517204022336](C:\Users\90317\AppData\Roaming\Typora\typora-user-images\image-20210517204022336.png)

解压后，进入解压目录

```shell
tar xf harbor.v1.6.0.tar.gz
cd harbor
```

修改配置文件harbor.cfg，把hostname改为对应机器的ip，我这里是192.168.254.131，其他默认即可

![image-20210517204315501](C:\Users\90317\AppData\Roaming\Typora\typora-user-images\image-20210517204315501.png)

使用的是http,还要加上harbor的地址

cat /etc/docker/daemon.json 
{
  "registry-mirrors": ["https://i9iblr0h.mirror.aliyuncs.com"],
  **"insecure-registries" : ["192.168.254.131"]**
}

```
sh prepare.sh
sh install.sh
```

等待执行完成，提示成功即可

### ingress-nginx安装使用

**k8s集群** 部署是参考https://github.com/903172988/k8s这的

ingress-nginx 配置文件地址https://github.com/kubernetes/ingress-nginx/tree/nginx-0.20.0/deploy

**mandatory.yaml** 是其他yaml文件的合集

![image-20210517200013864](C:\Users\90317\AppData\Roaming\Typora\typora-user-images\image-20210517200013864.png)

以下用到的yaml文件都在这 https://github.com/903172988/k8s/tree/main/ingress-nginx

node1节点打标签

```
kubectl label node node1 app=ingress
kubectl get nodes --show-labels
```

ingress-nginx调度在app=ingress,node1的节点，修改mandatory.yaml

![image-20210517170012110](C:\Users\90317\AppData\Roaming\Typora\typora-user-images\image-20210517170012110.png)

部署ingress-nginx

```
kubectl apply -f mandatory_hostNetwork.yaml
```

ingress-nginx对外暴露

```
kubectl apply -f service-nodeport.yaml
```

测试demo

```
kubectl apply -f ingress-demo.yaml
```

/etc/hosts添加域名解析

192.168.254.129 tomcat.weng.com
192.168.254.129 api.weng.com

![image-20210517201326719](C:\Users\90317\AppData\Roaming\Typora\typora-user-images\image-20210517201326719.png)

![image-20210517201400956](C:\Users\90317\AppData\Roaming\Typora\typora-user-images\image-20210517201400956.png)

说明ingress-nginx是正常的





