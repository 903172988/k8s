#!/bin/bash

name=${JOB_NAME}
image=$(cat ${WORKSPACE}/IMAGE)
host=${HOST}

echo "deploying ... name: ${name}, image: ${image}, host: ${host}"

rm -f web.yaml
cp $(dirname "${BASH_SOURCE[0]}")/template/web.yaml .
echo "copy ok"
# 模板文件中的替换占位符
sed -i "s,{{name}},${name},g" web.yaml
sed -i "s,{{image}},${image},g" web.yaml
sed -i "s,{{host}},${host},g" web.yaml

cat web.yaml
echo "ready to apply"
# 获取当前的deploy次数
revision=$(kubectl get deploy ${name} -o go-template='{{index .metadata.annotations "deployment.kubernetes.io/revision"}}')
kubectl apply -f web.yaml


# ===== 健康检查 =====
echo "start health check!"

new_revision=$(kubectl get deploy ${name} -o go-template='{{index .metadata.annotations "deployment.kubernetes.io/revision"}}')
check_count=0
# 如果等于apply之前的次数，代表还没deploy完成
while [ "${new_revision}" == "${revision}" ]
do
    if [ ${check_count} -gt 60 ];then
        echo "deploy failed!"
        exit 1
    fi

    sleep 1
    new_revision=$(kubectl get deploy ${name} -o go-template='{{index .metadata.annotations "deployment.kubernetes.io/revision"}}')
    ((check_count++))
    echo "check revision ${check_count} times"
done
echo "check revision success!"

success=0
count=60
# 转换数组时的分隔符
IFS=","
while [ ${count} -gt 0 ]
do
    # 获取各种副本数
    replicas=$(kubectl get deploy ${name} -o go-template='{{.status.replicas}},{{.status.updatedReplicas}},{{.status.readyReplicas}},{{.status.availableReplicas}}')
    echo "replicas: ${replicas}"
    # 转换为数组
    arr=(${replicas})
    # 判断各种副本数是否相等
    if [ "${arr[0]}" == "${arr[1]}" -a "${arr[1]}" == "${arr[2]}" -a "${arr[2]}" == "${arr[3]}" ];then
        echo "health check success!"
        success=1
        break
    fi

    ((count--))
    sleep 2
done

if [ ${success} -ne 1 ];then
    echo "health check failed!"
    exit 1
fi
