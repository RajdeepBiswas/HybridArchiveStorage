#!/bin/bash
##########################################################################################################
#Author: Rajdeep Biswas
#Date:07/10/2017
#Description:
#Hive hybrid storage mechanism to reduce storage cost exponentially utilizing 
#cold data for S3 storage along with hot data in hdfs for the hive tables
#Primary Functions: exportPartitions and relocatePartitions
#Uses configuration files to store S3 keys (Owned by root)
#Needs root access to execute
#Example usage
#./hive_hybrid_storage.sh schema.table_name conf_part_table_name.conf retain
#./hive_hybrid_storage.sh schema.table_name conf_part_table_name.conf delete
##########################################################################################################
if [ $# -ne 3 ]
then
	echo -e "\nError: Exactly 3 arguments are allowed. Full argument set like schema.table_name conf_part_table_name.conf retain or schema.table_name conf_part_table_name.conf delete\n"
	exit 1
elif [[ ! "$1" =~ . ]]
then
	echo -e "\nError: Schema name needs to be prefixed with table name\n"
	exit 1
elif [[ ! "$3" =~ ^(retain|delete)$ ]]
then
	echo -e "\nError: Wrong operation. Argument 3 can only be retain or delete. Full argument set like schema.table_name conf_part_table_name.conf retain or schema.table_name conf_part_table_name.conf delete\n"
	exit 1	
fi

baseDir=/root/scripts/dataCopy
schemaName_tableName=$1
confFile=$2
hdfsOperation=$3
s3bucket=s3a://test.hadoop.development

function logsetup {
	ts=$(date +%Y_%m_%d_%H_%M_%S)
	LOGFILE="$baseDir/$schemaName_tableName/hive_hybrid_storage_s3_$ts.log"
	exec > >(tee -a $LOGFILE)
	exec 2>&1
}

function log {
	echo "[$(date +%Y/%m/%d:%H:%M:%S)]: $*"
}

function exportPartitions {
	log "Step1: Transfering data to S3"
	while read tablepart
	do
		#The s3 keys for hdfs are in core-site.xml
		sudo -u hdfs hadoop distcp -p -update hdfs:///apps/hive/warehouse/${schemaName}.db/${tableName}/${tablepart} ${s3bucket}/apps/hive/warehouse/${schemaName}.db/${tableName}/${tablepart}
		
		##Important#Drop the partitions in HDFS
		if [ $hdfsOperation = 'delete' ]
		then
			sudo -u hdfs hdfs dfs -rm -R /apps/hive/warehouse/${schemaName}.db/${tableName}/${tablepart}
			log "/apps/hive/warehouse/${schemaName}.db/${tableName}/${tablepart} successfully deleted!"
		elif [ $hdfsOperation = 'retain' ]
		then
			log "Retaining hdfs folder /apps/hive/warehouse/${schemaName}.db/${tableName}/${tablepart}"
			log "Run hdfs dfs -rm -R /apps/hive/warehouse/${schemaName}.db/${tableName}/${tablepart} after data verification"
		else
			log "Wrong operation. Argument 3 can only be retain or delete"
		fi
	done < $baseDir/conf/$confFile
	log " Wrote specified partitions to ${s3bucket}/apps/hive/warehouse/${schemaName}.db/${tableName}"
}

function relocatePartitions {
	echo "USE ${schemaName};" > $baseDir/$schemaName_tableName/${tableName}_DDL.txt
	while read tablepart
	do
		partname=$(echo ${tablepart/=/=\"})
		echo "ALTER TABLE ${tableName} PARTITION ($partname\") SET LOCATION \"${s3bucket}/apps/hive/warehouse/${schemaName}.db/${tableName}/${tablepart}\";" >> $baseDir/$schemaName_tableName/${tableName}_DDL.txt
		echo "ANALYZE TABLE ${tableName} PARTITION ($partname\") COMPUTE STATISTICS;" >> $baseDir/$schemaName_tableName/${tableName}_DDL.txt	
	done < $baseDir/conf/$confFile
	#The s3 keys for hive are in hive-site.xml
	cp -f $baseDir/$schemaName_tableName/${tableName}_DDL.txt /tmp/
	sudo -u hive hive -f /tmp/${tableName}_DDL.txt

}


##############
#MAIN
##############

cd $baseDir
if [ ! -e $schemaName_tableName ]
then
	mkdir $schemaName_tableName
fi

schemaName=$(echo $schemaName_tableName | cut -d . -f1)
tableName=$(echo $schemaName_tableName | cut -d . -f2)

logsetup

log "hdfs s3 hybrid storage initiation..."

log "Partitions copy for $schemaName_tableName initiation..."
exportPartitions
log "Partitions copy for $schemaName_tableName finished."

log "Partition relocate for $schemaName_tableName initiation..."
relocatePartitions
log "Partition relocate for $schemaName_tableName finished."

log "$schemaName_tableName hybrid storage setup finished. Please verify the data!"

#########Simple Test for verification###########
#describe formatted schema_name.table_name partition (filename="partition1.csv.gz");

#describe formatted schema_name.table_name partition (filename="partition2.csv.gz");

#select count(*) from schema_name.table_name where  filename="partition1.csv.gz";

#select count(*) from schema_name.table_name where  filename="partition2.csv.gz";

#select * from schema_name.table_name where  filename="partition2.csv.gz" limit 5;

#MSCK REPAIR TABLE schema_name.table_name;
# This warning wll go away once the partition in HDFS is deleted and can be safely ignored
#Partitions not in metastore: table_name:filename=partition1.csv.gz  #table_name:filename=partition2.csv.gz

###################################################

