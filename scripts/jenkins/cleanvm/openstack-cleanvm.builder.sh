#!/usr/bin/env bash

export jtsync=${automationrepo}/scripts/jtsync/jtsync.rb
# We need a workaround for the cleanvm job.
# The job will run on a host with SLE11 installed.
# There are no packages for ruby available to run jtsync.
export jtsync_fix="ssh root@tu-sle12"

# Workaround to get only the name of the job:
# https://issues.jenkins-ci.org/browse/JENKINS-39189
# When the JOB_BASE_NAME contains only in ex. "openstack-cleanvm", this
# workaround can be removed.
echo "$JOB_BASE_NAME"
main_job_name=cleanvm

function exec_jtsync {
  # only enable jtsync when build is not manually triggered
  if [[ ${ROOT_BUILD_CAUSE} != "MANUALTRIGGER" ]]; then
    $jtsync_fix "$jtsync --ci opensuse --matrix $1,$2,$3 $4" || :
  fi
}

sudo /usr/local/sbin/freshvm cleanvm $image
sleep 100
cloudsource=openstack$(echo $openstack_project | tr '[:upper:]' '[:lower:]')
oshead=1
set -u
set +e
scp ${automationrepo}/scripts/jenkins/qa_openstack.sh root@cleanvm:
ssh root@cleanvm "export cloudsource=$cloudsource; export OSHEAD=$oshead; export NONINTERACTIVE=1; bash -x ~/qa_openstack.sh"
ret=$?
if [ "$ret" != 0 ] ; then
  virsh shutdown cleanvm
  # wait for clean shutdown
  n=20 ; while [[ $n > 0 ]] && virsh list |grep cleanvm.*running ; do sleep 2 ; n=$(($n-1)) ; done
  virsh destroy cleanvm
  # cleanup old images
  find /mnt/cleanvmbackup -mtime +5 -type f | xargs --no-run-if-empty rm
  # backup /dev/vg0/cleanvm disk image
  file=/mnt/cleanvmbackup/${BUILD_NUMBER}-${openstack_project}-${image}.raw.gz
  time gzip -c1 /dev/vg0/cleanvm > $file
  du $file
  exec_jtsync ${main_job_name} ${openstack_project} ${BUILD_NUMBER} 1
  exit 1
fi

exec_jtsync ${main_job_name} ${openstack_project} ${BUILD_NUMBER} $ret
exit $ret
