#!/bin/bash

# 判断pipeline脚本中定义的构建目录是否存在
if [ "${BUILD_DIR}" == "" ];then
    echo "env 'BUILD_DIR' is not set"
    exit 1
fi

# 定义构建docker镜像时的工作目录
DOCKER_DIR=${BUILD_DIR}/${JOB_NAME}
if [ ! -d ${DOCKER_DIR} ];then
    mkdir -p ${DOCKER_DIR}
fi

echo "docker workspace: ${DOCKER_DIR}"

# 项目所在的Jenkins工作目录路径
JENKINS_DIR=${WORKSPACE}/${MODULE}
echo "jenkins workspace: ${JENKINS_DIR}"

if [ ! -f ${JENKINS_DIR}/target/*.war ];then
    echo "target war file not found ${JENKINS_DIR}/target/*.war"
    exit 1
fi

cd ${DOCKER_DIR}
rm -rf *
unzip -oq ${JENKINS_DIR}/target/*.war -d ./ROOT

cp ${JENKINS_DIR}/Dockerfile .
if [ -d ${JENKINS_DIR}/dockerfiles ];then
    cp -r ${JENKINS_DIR}/dockerfiles .
fi

# 生成版本号
VERSION=$(date +%Y%m%d%H%M%S)
IMAGE_NAME=192.168.254.131/k8s/${JOB_NAME}:${VERSION}
# 将镜像名称写到一个文件中，方便后续脚本获取
echo "${IMAGE_NAME}" > ${WORKSPACE}/IMAGE
echo "building image: ${IMAGE_NAME}"

# 构建镜像并推送到远端仓库
docker build -t ${IMAGE_NAME} .
docker push ${IMAGE_NAME}
