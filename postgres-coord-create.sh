#!/bin/bash

while getopts ":c:s:n:" opt
do
        case "${opt}" in
                n) workernode=${OPTARG};;
                c) allowclientip=${OPTARG};;
                s) allowsubnetip=${OPTARG};;
        esac
done

#allowsubnetip="10.0.0.0/8"
#allowclientip="67.160.105.89/32"
echo "Getting the curl running"
curl https://install.citusdata.com/community/deb.sh | sudo bash
sudo apt-get -y install postgresql-14-citus-10.2

echo "Installed Citus 14"
sudo pg_conftool 14 main set shared_preload_libraries citus

echo "Downloaded the script and installed. Central config: /etc/postgresql/14/main,Database: /var/lib/postgresql/14/main"

sudo pg_conftool 14 main set listen_addresses '*'
echo "Set the listen_address to * to allow external connections"

hbasubnets=$(echo -e  "host\tall\t\tall\t\t$allowsubnetip\t\ttrust")
hbaexternal=$(echo -e "host\tall\t\tall\t\t$allowclientip\ttrust")
echo "# Allowing urestricted access to local nodes -- Kashyap" | sudo tee -a /etc/postgresql/14/main/pg_hba.conf
echo "$hbasubnets" | sudo tee -a /etc/postgresql/14/main/pg_hba.conf
echo "$hbaexternal" | sudo tee -a /etc/postgresql/14/main/pg_hba.conf

# start the db server
sudo service postgresql restart
# and make it start automatically when computer does
sudo update-rc.d postgresql enable
# add the citus extension
sudo -i -u postgres psql -c "CREATE EXTENSION citus;"

echo ">>>>>>>>>>>>>>>>>>Adding worker nodes to citus"
#sudo -u postgres psql -c "SELECT * FROM citus_add_node('$workernode',5432)"

# ./postgres-coord-create.sh -c 67.160.105.89/32 -s 10.0.0.0/8 -n 10.5.0.5