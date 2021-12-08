#!/bin/bash

while getopts ":c:s:p:" opt
do
        case "${opt}" in
                c) allowclientip=${OPTARG};;
                s) allowsubnetip=${OPTARG};;
                p) monitorport=${OPTARG};;
        esac
done

echo "Removing m2 folder from /var/lib/postgresql"
sudo rm -r /var/lib/postgresql

echo "Getting the citus install script and executing it"
curl https://install.citusdata.com/community/deb.sh | sudo bash
# install the server and initialize db
sudo apt-get -y install postgresql-14-auto-failover
sudo pg_conftool 14 main set listen_addresses '*'
echo ">>>>>>>>Monitor installed.."

hbasubnets=$(echo -e  "host\tall\t\tall\t\t$allowsubnetip\t\ttrust")
hbaexternal=$(echo -e "host\tall\t\tall\t\t$allowclientip\ttrust")
hbahostssl=$(echo -e "hostssl\tall\t\tall\t\t$allowsubnetip\ttrust")
echo "# Allowing urestricted access to local nodes -- Kashyap" | sudo tee -a /etc/postgresql/14/main/pg_hba.conf
echo "$hbasubnets" | sudo tee -a /etc/postgresql/14/main/pg_hba.conf
echo "$hbaexternal" | sudo tee -a /etc/postgresql/14/main/pg_hba.conf
echo "# Allowing monitor registration to all nodes on network on SSL" | sudo tee -a /etc/postgresql/14/main/pg_hba.conf
echo "$hbahostssl" | sudo tee -a /etc/postgresql/14/main/pg_hba.conf

echo "# Allowing urestricted access to local nodes -- Kashyap" | sudo tee -a ./m2/pg_hba.conf
echo "$hbasubnets" | sudo tee -a ./m2/pg_hba.conf
echo "$hbaexternal" | sudo tee -a ./m2/pg_hba.conf
echo "# Allowing monitor registration to all nodes on network on SSL" | sudo tee -a ./m2/pg_hba.conf
echo "$hbahostssl" | sudo tee -a ./m2/pg_hba.conf

# Get IP address to provide to monitor
ip4=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
sudo -i -u postgres PGDATA=./m2 PGPORT=$monitorport pg_autoctl create monitor --ssl-self-signed --hostname $ip4 --auth trust --run


# ./postgres-monitor-create.sh -c 67.160.105.89/32 -s 10.0.0.0/8 -p 5000
# sudo PGDATA=./m2 PGPORT=5000 pg_autoctl create monitor --ssl-self-signed --hostname 10.5.0.4 --auth trust --run