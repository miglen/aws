    #!/bin/bash
    # Nico Snyman, nico@gammafly.com, 14/05/2015
    # Change an instance type, while keeping snapshots
    # This script will stop an instance identified by instance ID,
    # take snapshots of all atached volumes, and restart it
    # Use:
    # -i instance ID - REQUIRED - stored in instance_id
    # -t instance new instance type - REQUIRED - stored in instance_type
    # -s if set to 0, no snapshot will be taken, dafault is 1
    #       (take snapshot of attached volumes) - stored in snapshot
    # -h Print Help
    #
    # Example: change_instance.sh -i i-aeae453e -t t2.small -s 0
    # The script requires AWS CLI tools to be installed and configured
    # If you want to take snapshots BEFORE stopping the instance, edit
    # the "Main" part of the script, moving stop_instance to below create_snapshot
    #
    # NOTE: I do no error checking to see if the instance exists, the script
    # will crash horribly if it doesn't
     
     
    #Some variables
    instance_id="0"
    instance_type="0"
    snapshot=1
     
    PROGNAME=$(basename $0) #Sets PROGNAME to the name of the script
    logfile="~/ec2-instance-change.log" #Set up the log file name
    tempfile="/tmp/volume_info.txt" #Sets up the temp file for volume lists
     
    clean_up() {
     
            # Perform program exit housekeeping
            rm $tempfile
            echo "$PROGNAME aborted by user"       
            exit
    }
     
    #usage - print script help
    usage() {
     
            # Display usage message on standard error
            echo "Usage:    $PROGNAME [OPTION] [Args]
    Change an instance type, while keeping snapshots
    This script will stop an instance identified by instance ID,
    take snapshots of all atached volumes, and restart it
     
    Options:
    -i              instance ID - REQUIRED - stored in instance_id
    -t              instance new instance type - REQUIRED - stored in instance_type
    -s              if set to 0, no snapshot will be taken, dafault is 1
                    (take snapshot of attached volumes) - stored in snapshot
     
    Example: change_instance.sh -i i-aeae453e -t t2.small -s 0
    The script requires AWS CLI tools to be installed and configured
    If you want to take snapshots BEFORE stopping the instance, edit the #Main#
    part of the script, moving stop_instance to below create_snapshot
     
    Allowed instance types:
    t2.micro | t2.small | t2.medium | m3.medium | m3.large | m3.xlarge | m3.2xlarge
    c4.large | c4.xlarge | c4.2xlarge | c4.4xlarge | c4.8xlarge | c3.large | c3.xlarge | c3.2xlarge | c3.4xlarge | c3.8xlarge
    r3.large | r3.xlarge | r3.2xlarge | r3.4xlarge | r3.8xlarge
    i2.xlarge | i2.2xlarge | i2.4xlarge | i2.8xlarge | d2.xlarge | d2.2xlarge | d2.4xlarge | d2.8xlarge
    g2.2xlarge | g2.8xlarge
    " 1>&2
    }
     
    #volume_info() - Get a list of all volumes attached to instance-id, write to /tmp/volume_info.txt
    volume_info () {
                    aws ec2 describe-volumes --filter Name=attachment.instance-id,Values=$instance_id --query Volumes[*].{ID:VolumeId} --output text | tr '\t' '\n' > $tempfile 2>&1
    }
     
    #create_snapshots(): Take a snapshot of all volumes with correct tags
    create_snapshots(){
            for volume_id in $(cat $tempfile)
            do
                    #Create a decription for the snapshot that describes the volume: servername.device-backup-date
            temp="-backup-$(date +%Y-%m-%d)"
            description=$instance_id"-"$volume_id$temp
                    description=${description// /.}
                    #echo "Volume ID is $volume_id" >> $logfile
                    echo "INFO: Creating snapshot $description"
                    #Take a snapshot of the current volume, and capture the resulting snapshot ID
                    snapresult=$(aws ec2 create-snapshot --output=text --description $description --volume-id $volume_id --query SnapshotId)
                   
            # Add some tags to the snapshot
                    tagresult=$(aws ec2 create-tags --resource $snapresult --tags Key=CreatedBy,Value=ChangeInstanceType)
                    echo "INFO: Adding tags CreatedBy:$PROGNAME = $tagresult"
            done
    }
     
    read_parameters() {
    while [ "$1" != "" ]; do
        case $1 in
            -i | --instance )       shift
                                    instance_id=$1
                                                                    ;;
            -s | --snapshot )               shift
                                                                    snapshot=$1
                                                                    retention_date_in_seconds=`date +%s --date "$days days ago"`  #Set oldest date snapshots should be kept
                                    ;;
                    -t | --type )                   shift
                                                                    instance_type=$1
                                                                    ;;
            -h | --help )           shift
                                                                    usage
                                    exit 0
                                    ;;
            * )                     usage
                                    exit 1
        esac
        shift
    done
     
        if [ $instance_id  == "0" ]; then
                    echo "Instance_id is required, use -h for Help." 1>&2
                    exit 1
            fi
     
    # TCheck that instance type is specified
        if [ $instance_type == "0" ]; then
                    echo "Instance_type is required, use -h for Help." 1>&2
                    exit 1
            fi
    }
     
    stop_instance () {
    ##Code to stop instance, notify user, wait till instance has stopped before returning
    ##First check if the instance is actually running
    instance_state=$(aws ec2 describe-instances --instance-ids $instance_id --query Reservations[*].Instances[*].State.Name --output text)
    echo "INFO: Instance state is: $instance_state"
            if [ $instance_state = "running" ]; then
                    echo "INFO: Stopping instance $instance_id"
                    aws ec2 stop-instances --instance-ids $instance_id
            fi
                    i=0
                    state=$(aws ec2 describe-instances --instance-ids $instance_id --query Reservations[*].Instances[*].State.Name --output text)
            until [ $state = "stopped" ]; do
            sleep 1s
            i=$((i+1))
            state=$(aws ec2 describe-instances --instance-ids $instance_id --query Reservations[*].Instances[*].State.Name --output text)
            printf "."
                    if [ "$i" -ge "180" ]; then
                    echo "ERROR: Instance took too long to stop, exiting"
                    exit 1
                    fi
            done
            printf "\n"
            echo "INFO: Instance stopped"
    }
     
    start_instance () {
            ##Code to start instance, notify user, wait till instance is running before returning
            echo "INFO: Starting instance $instance_id"
            aws ec2 start-instances --instance-ids $instance_id
            i=0
            state=$(aws ec2 describe-instances --instance-ids $instance_id --query Reservations[*].Instances[*].State.Name --output text)
            until [ $state = "running" ]; do
                    sleep 1s
                    i=$((i+1))
                    printf "."
                    if [ "$i" -ge "180" ]; then
                            echo "ERROR: Instance took too long to start, exiting"
                            exit 1
                    fi
                    state=$(aws ec2 describe-instances --instance-ids $instance_id --query Reservations[*].Instances[*].State.Name --output text)
            done
            new_instance_type=$(aws ec2 describe-instance-attribute --instance-id $instance_id --attribute instanceType)
            printf "\n"
            echo "INSTANCEID $new_instance_type"
            echo
            echo "INFO: Completed."
    }
     
    change_instance_type () {
            ##Code to change the instance type, notify user, return
            instance_state=$(aws ec2 describe-instances --instance-ids $instance_id --query Reservations[*].Instances[*].State.Name --output text)
                    if [ $instance_state == "stopped" ]; then
                            echo "INFO: Changing $instance_id to $instance_type"
                            aws ec2 modify-instance-attribute --instance-id $instance_id --instance-type "{\"Value\": \"$instance_type\"}"
                    else
                            echo "ERROR: Instance state is: $instance_state"
                            echo "ERROR: Cannot change instance type in this state, exiting" 1>&2
                    exit 1
                    fi
    }
     
    ### Main ###
    ############
     
    read_parameters $@
     
    if [ "$snapshot" -eq "1" ]; then
            volume_info
    fi
     
    stop_instance
     
    if [ "$snapshot" -eq "1" ]; then
            create_snapshots
    fi
     
    change_instance_type
     
    start_instance
    #clean_up