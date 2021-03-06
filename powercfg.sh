#!/system/bin/sh
# Project WIPE https://github.com/yc9559/cpufreq-interactive-opt
# Author: yc9559
# Platform: kirin_970
# Generated at: Thu Jun 28 01:02:05 2018

C0_GOVERNOR_DIR="/sys/devices/system/cpu/cpu0/cpufreq/interactive"
C1_GOVERNOR_DIR="/sys/devices/system/cpu/cpu4/cpufreq/interactive"
C0_CPUFREQ_DIR="/sys/devices/system/cpu/cpu0/cpufreq"
C1_CPUFREQ_DIR="/sys/devices/system/cpu/cpu4/cpufreq"

# $1:timer_rate $2:value
function set_param_little() 
{
	echo ${2} > ${C0_GOVERNOR_DIR}/${1}
}

# $1:timer_rate $2:value
function set_param_big() 
{
	echo ${2} > ${C1_GOVERNOR_DIR}/${1}
}

# $1:timer_rate
function print_param() 
{
	print_value "LITTLE: ${1}" ${C0_GOVERNOR_DIR}/${1}
	print_value "big: ${1}" ${C1_GOVERNOR_DIR}/${1}
}

function unify_environment() 
{
	# SELinux permissive
	setenforce 0
	# Exynos hotplug
	lock_value 0 /sys/power/cpuhotplug/enabled
	lock_value 0 /sys/devices/system/cpu/cpuhotplug/enabled
	lock_value 1 /sys/devices/system/cpu/cpu4/online
	lock_value 1 /sys/devices/system/cpu/cpu5/online
	lock_value 1 /sys/devices/system/cpu/cpu6/online
	lock_value 1 /sys/devices/system/cpu/cpu7/online
	# in case of using ondemand as default governor
	lock_value "interactive" ${C0_CPUFREQ_DIR}/scaling_governor
	lock_value "interactive" ${C1_CPUFREQ_DIR}/scaling_governor
}

function runonce_custom()
{
	# avoid permission problem, do not set 0444
	set_value 0-3 /dev/cpuset/background/cpus
	set_value 2-3 /dev/cpuset/system-background/cpus
	set_value 0-3,4-7 /dev/cpuset/foreground/cpus
	set_value 0-3,4-7 /dev/cpuset/top-app/cpus

	# Linaro HMP, between 0 and 1024, maybe compare to the capacity of current cluster
	# PELT and period average smoothing sampling, so the parameter style differ from WALT by Qualcomm a lot.
	# https://lists.linaro.org/pipermail/linaro-dev/2012-November/014485.html
	# https://www.anandtech.com/show/9330/exynos-7420-deep-dive/6
	# lock_value 60 /sys/kernel/hmp/load_avg_period_ms
	lock_value 256 /sys/kernel/hmp/down_threshold
	lock_value 640 /sys/kernel/hmp/up_threshold
	lock_value 0 /sys/kernel/hmp/boost
}

function before_modify()
{
	chown 0.0 ${C0_GOVERNOR_DIR}/*
	chmod 0666 ${C0_GOVERNOR_DIR}/*
	lock_value 480000 ${C0_CPUFREQ_DIR}/scaling_min_freq

	set_value 1 /sys/devices/system/cpu/cpu4/online
	chown 0.0 ${C1_GOVERNOR_DIR}/*
	chmod 0666 ${C1_GOVERNOR_DIR}/*
	lock_value 680000 ${C1_CPUFREQ_DIR}/scaling_min_freq
}

function after_modify()
{
	chmod 0444 ${C0_GOVERNOR_DIR}/*
	chmod 0444 ${C1_GOVERNOR_DIR}/*
	verify_param
}

function powersave_custom()
{
	:
}

function balance_custom()
{
	:
}

function performance_custom()
{
	:
}

function fast_custom()
{
	:
}



# $1:value $2:file path
function set_value() 
{
	if [ -f $2 ]; then
		echo $1 > $2
	fi
}

# $1:value $2:file path
function lock_value() 
{
	if [ -f $2 ]; then
		# chown 0.0 $2
		chmod 0666 $2
		echo $1 > $2
		chmod 0444 $2
	fi
}

# $1:io-scheduler $2:block-path
function set_io() 
{
	if [ -f $2/queue/scheduler ]; then
		if [ `grep -c $1 $2/queue/scheduler` = 1 ]; then
			echo $1 > $2/queue/scheduler
			echo 512 > $2/queue/read_ahead_kb
			lock_value 0 $2/queue/iostats
			lock_value 256 $2/queue/nr_requests
			lock_value 0 $2/queue/iosched/slice_idle
		fi
	fi
}

# $1:display-name $2:file path
function print_value() 
{
	if [ -f $2 ]; then
		echo $1
		cat $2
	fi
}

function verify_param() 
{
	expected_target=${C0_GOVERNOR_DIR}/target_loads
	if [ "$action" = "powersave" ]; then
		expected_value="80 980000:60 1180000:87 1380000:70 1480000:98"
	elif [ "$action" = "balance" ]; then
		expected_value="80 980000:61 1180000:88 1380000:70 1480000:96"
	elif [ "$action" = "performance" ]; then
		expected_value="80 980000:63 1180000:76 1480000:96"
	elif [ "$action" = "fast" ]; then
		expected_value="80 1780000:90"
	fi
	if [ "`cat ${expected_target}`" = "${expected_value}" ]; then
		echo "${action} OK"
	else
		echo "${action} FAIL"
	fi
}

action=$1
if [ ! -n "$action" ]; then
    action="balance"
fi

if [ "$action" = "debug" ]; then
	echo "Project WIPE https://github.com/yc9559/cpufreq-interactive-opt"
	echo "Author: yc9559"
	echo "Platform: kirin_970"
	echo "Generated at: Thu Jun 28 01:02:05 2018"
	echo ""
	print_value "Cluster 0: min_freq" ${C0_CPUFREQ_DIR}/scaling_min_freq
	print_param above_hispeed_delay
	print_param target_loads
	print_value "sched_spill_load" /proc/sys/kernel/sched_spill_load
	print_value "eMMC IO scheduler" /sys/block/mmcblk0/queue/scheduler
	print_value "UFS IO scheduler" /sys/block/sda/queue/scheduler
	which perfd
	exit 0
fi

if [ ! -f /dev/.project_wipe ]; then
	unify_environment
fi

before_modify

# RunOnce
if [ ! -f /dev/.project_wipe ]; then
	# set flag
	touch /dev/.project_wipe

	runonce_custom

	set_io cfq /sys/block/mmcblk0
	set_io cfq /sys/block/sda

	# shared interactive parameters
	set_param_little timer_rate 20000
	set_param_little timer_slack 180000
	set_param_little boost 0
	set_param_little boostpulse_duration 0
	set_param_big timer_rate 20000
	set_param_big timer_slack 180000
	set_param_big boost 0
	set_param_big boostpulse_duration 0
fi

if [ "$action" = "powersave" ]; then
	powersave_custom
	set_param_little above_hispeed_delay "18000 1380000:38000 1480000:98000"
	set_param_little hispeed_freq 1180000
	set_param_little go_hispeed_load 98
	set_param_little target_loads "80 980000:60 1180000:87 1380000:70 1480000:98"
	set_param_little min_sample_time 18000
	set_param_big above_hispeed_delay "18000 1580000:98000 1780000:138000"
	set_param_big hispeed_freq 1280000
	set_param_big go_hispeed_load 98
	set_param_big target_loads "80 1280000:98 1480000:91 1580000:98"
	set_param_big min_sample_time 18000
	lock_value 0 /sys/devices/system/cpu/cpu5/online
	lock_value 0 /sys/devices/system/cpu/cpu6/online
	lock_value 0 /sys/devices/system/cpu/cpu7/online
fi

if [ "$action" = "balance" ]; then
	balance_custom
	set_param_little above_hispeed_delay "18000 1480000:38000 1680000:98000"
	set_param_little hispeed_freq 1180000
	set_param_little go_hispeed_load 97
	set_param_little target_loads "80 980000:61 1180000:88 1380000:70 1480000:96"
	set_param_little min_sample_time 38000
	set_param_big above_hispeed_delay "18000 1580000:98000 1780000:138000"
	set_param_big hispeed_freq 1280000
	set_param_big go_hispeed_load 94
	set_param_big target_loads "80 980000:72 1280000:77 1580000:98"
	set_param_big min_sample_time 18000
	lock_value 1 /sys/devices/system/cpu/cpu5/online
	lock_value 1 /sys/devices/system/cpu/cpu6/online
	lock_value 0 /sys/devices/system/cpu/cpu7/online
fi

if [ "$action" = "performance" ]; then
	performance_custom
	set_param_little above_hispeed_delay "18000 1680000:38000"
	set_param_little hispeed_freq 1180000
	set_param_little go_hispeed_load 98
	set_param_little target_loads "80 980000:63 1180000:76 1480000:96"
	set_param_little min_sample_time 78000
	set_param_big above_hispeed_delay "18000 1580000:98000 1780000:38000"
	set_param_big hispeed_freq 1480000
	set_param_big go_hispeed_load 86
	set_param_big target_loads "80 980000:57 1280000:70 1480000:65 1580000:98"
	set_param_big min_sample_time 18000
	lock_value 1 /sys/devices/system/cpu/cpu5/online
	lock_value 1 /sys/devices/system/cpu/cpu6/online
	lock_value 1 /sys/devices/system/cpu/cpu7/online
fi

if [ "$action" = "fast" ]; then
	fast_custom
	lock_value 1480000 ${C0_CPUFREQ_DIR}/scaling_min_freq
	set_param_little above_hispeed_delay "18000 1680000:198000"
	set_param_little hispeed_freq 1480000
	set_param_little target_loads "80 1780000:90"
	set_param_little min_sample_time 38000
	lock_value 1280000 ${C1_CPUFREQ_DIR}/scaling_min_freq
	set_param_big above_hispeed_delay "18000 1780000:198000"
	set_param_big hispeed_freq 1280000
	set_param_big target_loads "80 1980000:90"
	set_param_big min_sample_time 38000
	lock_value 1 /sys/devices/system/cpu/cpu5/online
	lock_value 1 /sys/devices/system/cpu/cpu6/online
	lock_value 1 /sys/devices/system/cpu/cpu7/online

fi

after_modify

exit 0
