#!/bin/bash
mkdir ./certs
openssl genrsa -out ./certs/rootCA.key 4096
openssl req -x509 -new -nodes -key ./certs/rootCA.key -subj "/C=US/ST=CA/O=MyOrg, Inc./CN=root" -sha256 -days 1024 -out ./certs/rootCA.crt
openssl genrsa -out ./certs/key.pem 2048
openssl req -new -sha256 -key ./certs/key.pem -subj "/C=US/ST=CA/O=MyOrg, Inc./CN=$1" -out ./certs/cert.csr
openssl x509 -req -in ./certs/cert.csr -CA ./certs/rootCA.crt -CAkey ./certs/rootCA.key -CAcreateserial -out ./certs/cert.pem -days 500 -sha256
cp ./certs/rootCA.crt ./certs/cacerts.pem
