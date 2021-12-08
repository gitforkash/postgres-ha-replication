#!/bin/bash

while getopts ":c:s:r:p:t:m:o:i:" opt
do
        case "${opt}" in
                c) allowclientip=${OPTARG};;
                s) allowsubnetip=${OPTARG};;
                r) role=${OPTARG};;
                p) primaryserverip=${OPTARG};;
                t) replicaslot=${OPTARG};;
                m) monitorhost=${OPTARG};;
                o) monitorport=${OPTARG};;
                i) coordinatornode=${OPTARG};;
        esac
done

#allowsubnetip="10.0.0.0/8"
#allowclientip="67.160.105.89/32"
echo ">>>>>>>Getting the curl running"
curl https://install.citusdata.com/community/deb.sh | sudo bash
sudo apt-get -y install postgresql-14-citus-10.2

echo ">>>>>>>Installed Citus 14"
sudo pg_conftool 14 main set shared_preload_libraries citus

echo ">>>>>>>Downloaded the script and installed. Central config: /etc/postgresql/14/main,Database: /var/lib/postgresql/14/main"

sudo pg_conftool 14 main set listen_addresses '*'
echo ">>>>>>>Set the listen_address to * to allow external connections"

hbasubnets=$(echo -e  "host\tall\t\tall\t\t$allowsubnetip\t\ttrust")
hbaexternal=$(echo -e "host\tall\t\tall\t\t$allowclientip\ttrust")
echo "# Allowing urestricted access to local nodes -- Kashyap" | sudo tee -a /etc/postgresql/14/main/pg_hba.conf
echo "$hbasubnets" | sudo tee -a /etc/postgresql/14/main/pg_hba.conf
echo "$hbaexternal" | sudo tee -a /etc/postgresql/14/main/pg_hba.conf
echo ">>>>>>>>>$role and primary $primaryserverip"
if [[ "$role" == "primary" ]];
then
        echo ">>>>>>>Role is primary and setting up replication.............."
        hbareplicator=$(echo -e "host\treplication\treplicator\t$allowsubnetip\ttrust")
        echo "$hbareplicator" | sudo tee -a /etc/postgresql/14/main/pg_hba.conf
fi

# start the db server
sudo service postgresql restart
# and make it start automatically when computer does
sudo update-rc.d postgresql enable
# add the citus extension
sudo -i -u postgres psql -c "CREATE EXTENSION citus;"

if [[ "$role" == "primary" ]]
then
        ip4=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
        sudo psql -U postgres -p 5432 -h $coordinatornode -c "Select * from citus_add_node('$ip4',5432);"
        echo ">>>>>>Updated node in coordinator"
fi


sudo service postgresql stop
#Enable HA Failover extension
echo ">>>>>>>Enabling HA Failover extension on top of citus"
sudo apt-get -y install postgresql-14-auto-failover
echo ">>>>>>>Version of Failover PG: "
/usr/bin/pg_autoctl --version


if [[ "$role" == "replica" ]];
then
        sudo service postgresql stop
        echo ">>>>>>>Role is replica and deleting folder and setting up base backup.............."
        sudo rm -R /var/lib/postgresql/14/main
        sudo -u postgres pg_basebackup -h $primaryserverip -D /var/lib/postgresql/14/main -U replicator -P -v -R -X stream -C -S $replicaslot
        echo ">>>>>>>Replication step complete"
        sudo service postgresql restart
fi


if [[ "$role" == "primary" ]]
then
        echo ">>>>>>>Role is primary and setting up role of replicator.............."
        #Create user replicator and add to pg_hba.conf
        echo ">>>>>>>Create a user replicator for replica to sync up"
        sudo -u postgres psql -c "Create user replicator WITH REPLICATION ENCRYPTED PASSWORD 'admin@123'"
fi

#Converting Primary host to be HA compliant
sudo service postgresql stop 
echo ">>>>>>>Convert primary host to HA compliance with Monitor host $monitorhost and port $monitorport"
echo ">>>>>>>Using pg_autoctl on existing db will restart, so restarting not needed"
echo ">>>>>>>Status of postgres: "

sudo service postgresql status
sudo service postgresql stop
sleep 20
echo ">>>>>>>>Attempting to create postgrse as HA from existing location"
sudo -i -u postgres PGDATA=/var/lib/postgresql/14/main PGPORT=5432 pg_autoctl create postgres --pgdata /var/lib/postgresql/14/main --ssl-self-signed --auth trust --monitor postgres://autoctl_node@$monitorhost:$monitorport/pg_auto_failover?sslmode=require --run


# Worker: ./postgres-worker-replica-create.sh -c 67.160.105.89/32 -s 10.0.0.0/8 -r primary -m 10.5.0.4 -o 5000 -i 10.5.0.7
# Replica: ./postgres-worker-replica-create.sh -c 67.160.105.89/32 -s 10.0.0.0/8 -r replica -t slot1 -m 10.5.0.4 -o 5000 -p 10.5.0.5

# sudo -i -u postgres PGDATA=/var/lib/postgresql/14/main PGPORT=5432 pg_autoctl create postgres --pgdata /var/lib/postgresql/14/main --ssl-self-signed --auth trust --monitor postgres://autoctl_node@10.5.0.4:5000/pg_auto_failover?sslmode=require --run