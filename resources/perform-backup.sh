#/bin/sh


# Set the has_failed variable to false. This will change if any of the subsequent database backups/uploads fail.
has_failed=false
current_date=$(TZ='Asia/Seoul' date +%y%m%d%H%M%S)

# Loop through all the defined databases, seperating by a ,
for CURRENT_DATABASE in ${TARGET_DATABASE_NAMES//,/ }
do
BACKUPFILES="$CURRENT_DATABASE"_"backup"_"$current_date"
    # Perform the database backup. Put the output to a variable. If successful upload the backup to S3, if unsuccessful print an entry to the console and the log, and set has_failed to true.
    if sqloutput=$(consul snapshot save -http-addr=$TARGET_DATABASE_HOST:$TARGET_DATABASE_PORT /tmp/$CURRENT_DATABASE_$current_date.snap)
    then
        
        echo -e "Database backup successfully completed for $CURRENT_DATABASE at $(TZ='Asia/Seoul' date +'%Y-%m-%d %H:%M:%S')."

        # Perform the upload to S3. Put the output to a variable. If successful, print an entry to the console and the log. If unsuccessful, set has_failed to true and print an entry to the console and the log
        if awsoutput=$(aws s3 cp /tmp/$CURRENT_DATABASE_$current_date.snap s3://$AWS_BUCKET_NAME$AWS_BUCKET_BACKUP_PATH/$BACKUPFILES.snap 2>&1)
        then
            echo -e "Database backup successfully uploaded for $CURRENT_DATABASE at $(TZ='Asia/Seoul' date +'%Y-%m-%d %H:%M:%S')."
        else
            echo -e "Database backup failed to upload for $CURRENT_DATABASE at $(TZ='Asia/Seoul' date +'%Y-%m-%d %H:%M:%S'). Error: $awsoutput" | tee -a /tmp/consul-backup.log
            has_failed=true
        fi

    else
        echo -e "Database backup FAILED for $CURRENT_DATABASE at $(TZ='Asia/Seoul' date +'%Y-%m-%d %H:%M:%S'). Error: $sqloutput" | tee -a /tmp/consul-backup.log
        has_failed=true
    fi

done



# Check if any of the backups have failed. If so, exit with a status of 1. Otherwise exit cleanly with a status of 0.
if [ "$has_failed" = true ]
then

    # If Slack alerts are enabled, send a notification alongside a log of what failed
    if [ "$SLACK_ENABLED" = true ]
    then
        # Put the contents of the database backup logs into a variable
        logcontents=`cat /tmp/consul-backup.log`

        # Send Slack alert
        /slack-alert.sh "One or more backups on database host $TARGET_DATABASE_HOST failed. The error details are included below:" "$logcontents"
    fi

    echo -e "consul-backup encountered 1 or more errors. Exiting with status code 1."
    exit 1

else

    # If Slack alerts are enabled, send a notification that all database backups were successful
    if [ "$SLACK_ENABLED" = true ]
    then
        /slack-alert.sh "All database backups successfully completed on database host $TARGET_DATABASE_HOST."
    fi

    exit 0
    
fi
