# rsync & scp on EC2



```sudo  rsync -PazSHAX --rsh "ssh -i KEYPAIR.pem" --rsync-path "sudo rsync" \
  LOCALFILES ubuntu@HOSTNAME:REMOTEDIR/```
