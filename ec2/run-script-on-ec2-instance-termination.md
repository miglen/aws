# Running script or command on EC2 instance on termination

To perform that you need to add the script on init level 0, which is the halt level. The script will be also invoked on shutdown and termination.
The easiest way is to create symlink in /etc/rc0.d/ starting with S01 so the script will be executed first in the sequence of scripts. The usual time that you have for execution is ~2 minutes, but it may vary so don't count on it.

Here is an example:

`ln -s /etc/ec2-termination /etc/rc0.d/S01ec2-termination`

One important thing to consider is that in this run level you might loose environment variables such as $PATH so you need to specify the full path to your programs such as `/bin/cp` or `/usr/bin/curl`

There are other ways to achieve execution of a script before termination:
 * Spot instances - You can check the (termination time)[https://aws.amazon.com/blogs/aws/new-ec2-spot-instance-termination-notices/], and if the instance is marked for termination to run your (script)[https://blog.fugue.co/2015-01-06-spot-termination-notices.html].
 * Auto Scaling - You can use the [Lifecycle Hooks](http://docs.aws.amazon.com/AutoScaling/latest/DeveloperGuide/AutoScalingGroupLifecycle.html) connected to SNS topic where the instance is subscribed and firest command on termination.
 * User request - You can perform [EC2 Run command](https://aws.amazon.com/ec2/run-command/) before the actual termination.
