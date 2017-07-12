# HybridArchiveStorage

## Introduction
Traditional data warehouse archive strategy involves moving the old data into offsite tapes.  This does not quite fit the size for modern analytics applications since the data is unavailable for business analytics in real time need. 
Mature Hadoop clusters needs a modern data archival strategy to keep the storage expense at  check when data volume increase exponentially. 
The term hybrid here designates an archival solution which is always available as well as completely transparent to the application layer 
This document will cover:  
1.	Use case 
2.	Requirement 
3.	Storage cost analysis 
4.	Design Approach 
5.	Architecture diagram 
6.	Code 
7.	How to setup and Run the code 


## Use case 
Entire business data is in HDFS (HDP clusters) backed by Amazon EBS. 
Disaster recovery solution is in place. 
Amazon claims S3 storage delivers 99.999999999% durability. In case of data loss from S3 we have to recover the data from disaster recovery site. 


## Requirement 
1. Decrease storage costs. 
2. Archived data should be available to perform analytics 24X7. 
3. Access hot and cold (archived) data simultaneously from the application. 
4. Solution should be transparent to the application layer. In other words absolutely no change should be required from the application layer after the hybrid archival strategy is implemented. 
5. Performance should be acceptable. 
Below are the possible solutions for the use cases.  


## Storage cost analysis 

###	 Storage vs Cost Graph 

![cost_graph](https://user-images.githubusercontent.com/17171996/28139781-27b49212-671b-11e7-8f8e-e0df564f8a2c.jpg) 


###	Basis for Calculation 

**For S3**                                                                                                  
$0.023 per GB-month of usage                             
Source: https://aws.amazon.com/s3/pricing/ 	

**For EBS SSD (gp2)**

$0.10 per GB-month of provisioned storage                            
Including replication factor of 3 this becomes net $0.30 per GB  
Source: https://aws.amazon.com/ebs/pricing/ 
				
**Important Note:**
EBS is provisioned storage whereas S3 is pay as you use. 
In other words for future data growth say you provision an EBS storage of 1 TB. 
You have to pay 100% for it regardless you are using 0% or 90% of it. 
Whereas S3 is just the storage you are using.  
So for 2GB pay for 2 GB and for 500 GB pay for 500GB. 
Hence S3 price calculation is divided by 2 roughly calculating the way it will grow in correlation to the HDFS EBS storage.	 


##	Design approach 
All the approaches depends on the work done in the below Jira where datanode is conceptualized as a collection of heterogeneous storage with different durability and performance requirements. 
https://issues.apache.org/jira/browse/HDFS-2832 
###	Design 1 
1) Hot data with partitions that are wholly hosted by HDFS. 
2) Cold data with partitions that are wholly hosted by S3. 
3) A view that unions these two tables which is the live table that we expose to end users. 

###	Design 2 
1) Hot data with partitions that are wholly hosted by HDFS. 
2) Cold data with partitions that are wholly hosted by S3. 
3) Both hot and cold data are in the same table 

Design 2 is chosen over Design 1 because Design 1 is not transparent to the application layer. 
The change from old table to the view would inherently transfer some level of porting/integration extra work to the application. 


## Architecture Diagram
###	High Level Design 

![architecture](https://user-images.githubusercontent.com/17171996/28139806-4289302a-671b-11e7-86fc-a3c1238b1b14.jpg) 


###	Automation Flow Diagram 

![flow](https://user-images.githubusercontent.com/17171996/28139822-52d9bcba-671b-11e7-842a-520d082dee85.jpg) 


## Setup & Run 
###	Setup 
1.	cd /root/scripts/dataCopy 
2.	vi hive_hybrid_storage.sh  -- Put the script here 
3.	chmod 755 hive_hybrid_storage.sh 
4.	cd /root/scripts/dataCopy/conf 
5.	vi test_table.conf   -- This is where the cold partition names are placed 

### Run 
#### Option1  
Retain the hdfs partition and delete it manually after data verification. 
./hive_hybrid_storage.sh schema_name.test_table test_table.conf retain 

#### Option2 
Delete the hdfs partition as part of the script. 
It will delete after data is copied to s3. So there is an option to copy it back to hdfs if you want to revert the location of the partition to hdfs. 

./hive_hybrid_storage.sh schema_name.test_table test_table.conf delete 





