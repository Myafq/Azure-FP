#!/bin/bash
# $1 = Azure storage account name
# $2 = Azure storage account key
# $3 = Azure file share name
# $4 = mountpoint path
# $5 - username
# $6 - db address
# $7 - db user
# $8 - db password
# For more details refer to https://azure.microsoft.com/en-us/documentation/articles/storage-how-to-use-files-linux/

# update package lists
apt-get -y update

# install cifs-utils and mount file share
apt-get install cifs-utils
mkdir $4
mount -t cifs //$1.file.core.windows.net/$3 $4 -o vers=3.0,username=$1,password=$2,dir_mode=0755,file_mode=0664,uid=33,gid=33
#  install docker
apt-get install     apt-transport-https     ca-certificates     curl     gnupg-agent     software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
apt update
apt-get install docker-ce docker-ce-cli containerd.io -y 
# configure nginx
mkdir -p $4/{certs,nginx}
cat << 'EOF' > $4/nginx/default.conf
server {
   listen 80 default_server;

   location ^~ /.well-known/acme-challenge/ {
   proxy_pass       http://127.0.0.1:4443;
   proxy_set_header Host      $host;
   proxy_set_header X-Real-IP $remote_addr;

   }
   location / {
   if ($http_x_forwarded_proto != https) {
    return 302 https://$host$request_uri;
   }
   proxy_pass       http://127.0.0.1:4080;
   proxy_set_header Host      $host;
   proxy_set_header X-Real-IP $remote_addr;
   proxy_set_header X-Real-IP $remote_addr;
   }

}
EOF
# install lets-proxy
wget https://github.com/rekby/lets-proxy/releases/download/v0.15.1.11/lets-proxy-linux-amd64.tar.gz 
tar xf lets-proxy-linux-amd64.tar.gz 
mv lets-proxy /bin/
lets-proxy --service-name=lets-proxy --service-action=install --cert-dir=$4/certs
service lets-proxy start
# run nginx and wordpress
docker run --name fpwp -v $4/wp-content/:/var/www/html/wp-content/ \
   -e WORDPRESS_DB_HOST=$6 \
   -e WORDPRESS_DB_USER=$7 \
   -e WORDPRESS_DB_PASSWORD=$8 \
   -e WORDPRESS_DB_NAME=fpwpdb \
   -e WORDPRESS_TABLE_PREFIX=fpwp \
   -p 4080:80 -d wordpress
docker run --name fpnginx --network host -v /mnt/fpwp/nginx:/etc/nginx/conf.d -d nginx
