#!/bin/bash
INST_OFFSET=`expr $UID % 64`
SIMULATE_SIZE=50000 # Unit: MB
LOG_SIZE=30000 # Unit: MB
declare inst_count=''
declare last_id=''

init_dss_conf()
{
    dss_home=$1
    inst_id=`expr $2 + $INST_OFFSET`
    simu_path=$3
    lock_path=$4
    echo "init ${dss_home}"

    mkdir -p ${dss_home}/cfg
    mkdir -p ${dss_home}/log

    echo "data:${simu_path}/dss_data.dmp" > ${dss_home}/cfg/dss_vg_conf.ini
    for i in `seq 0 $last_id`
    do
        echo "log${i}:${simu_path}/dss_log${i}.dmp" >> ${dss_home}/cfg/dss_vg_conf.ini
    done

    echo "INST_ID = ${inst_id}" > ${dss_home}/cfg/dss_inst.ini
    echo "_LOG_LEVEL = 255" >> ${dss_home}/cfg/dss_inst.ini
    echo "_LOG_BACKUP_FILE_COUNT = 128" >> ${dss_home}/cfg/dss_inst.ini
    echo "_LOG_MAX_FILE_SIZE = 100M" >> ${dss_home}/cfg/dss_inst.ini
    echo "LSNR_PATH = ${dss_home}" >> ${dss_home}/cfg/dss_inst.ini
    echo "DISK_LOCK_FILE_PATH = ${lock_path}" >> ${dss_home}/cfg/dss_inst.ini
}

create_vg()
{
    dss_home=$1
    simu_path=$2

    export DSS_HOME=${dss_home}
    rm -rf ${simu_path}
    mkdir ${simu_path}

    echo " =========== truncate `expr ${SIMULATE_SIZE} / 1000`G =========== "
#    dd if=/dev/zero bs=1048576 count=${SIMULATE_SIZE} of=${simu_path}/dss_data.dmp
    truncate -s `expr ${SIMULATE_SIZE} / 1000`G ${simu_path}/dss_data.dmp
    chmod 777 ${simu_path}/dss_data.dmp

    for i in `seq 0 $last_id`
    do
        echo " =========== truncate `expr ${LOG_SIZE} / 1000`G =========== "
#        dd if=/dev/zero bs=1048576 count=${LOG_SIZE} of=${simu_path}/dss_log${i}.dmp
        truncate -s `expr ${SIMULATE_SIZE} / 1000`G ${simu_path}/dss_log${i}.dmp
        chmod 777 ${simu_path}/dss_log${i}.dmp
    done

    echo "> creating volume group ${simu_path}/dss_data.dmp"
    ${GAUSSHOME}/bin/dsscmd cv -g data -v ${simu_path}/dss_data.dmp -s 2048 -D ${dss_home}

    for i in `seq 0 $last_id`
    do
        echo "> creating volume group ${simu_path}/dss_log${i}.dmp"
        ${GAUSSHOME}/bin/dsscmd cv -g log${i} -v ${simu_path}/dss_log${i}.dmp -s 2048 -D ${dss_home}
    done
}

start_dss()
{
    dsshome_pre=$1
    echo " =================   starting $inst_count dssserver process   ================="
    for i in `seq 0 $last_id`
    do
        dss="${dsshome_pre}${i}"
        echo "> starting ${dss}" && nohup ${GAUSSHOME}/bin/dssserver -D ${dss} &
        sleep 1
    done

    # check start node number equals input value number
    dss_pids=`ps ux | grep dssserver | grep -v grep | wc -l`
    if [ $inst_count != ${dss_pids} ]; then
        echo "dssserver start failed, or parameter error"
        exit 1;
    else
        echo " =================   $inst_count dssserver process started    ================="
    fi
}

function main() {
    inst_count=$1
    last_id=`expr $inst_count - 1`
    pre_path=$2
    if [ ! -d ${pre_path} ]; then
        mkdir -p ${pre_path}
    fi
    simu_path=$3

    echo "init & start $inst_count dss node"
    for i in `seq 0 $last_id`
    do
        echo "init_dss_conf ${pre_path}/dss_home$i"
        init_dss_conf ${pre_path}/dss_home$i $i ${simu_path} ${pre_path}
    done

    create_vg ${pre_path}/dss_home0 ${simu_path}
    start_dss ${pre_path}/dss_home ${inst_count}
}

main $@