#!/bin/bash

openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout weng.key -out weng.crt -subj "/CN=*.weng.com/O=*.weng.com"

kubectl create secret tls weng-tls --key weng.key --cert weng.crt