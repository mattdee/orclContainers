#!/bin/bash
#
#
   #===================================================================================
   #
   #         FILE: orclDocker.sh
   #
   #        USAGE: select an option or do all
   #
   #  DESCRIPTION:
   #      OPTIONS:  
   # REQUIREMENTS: 
   #       AUTHOR: Matt D
   #      CREATED: 11.10.2021
   #      UPDATED: 11.10.2021
   #      VERSION: 1.0
   #
   #
   #
   #
   #
   #
   #===================================================================================


function startUp()
{
    clear screen
    echo "##########################################################"
    echo "# This will manage your Oracle Database Docker container #"
    echo "##########################################################"

    echo
    echo
    echo 

    echo "################################################"
    echo "#                                              #"
    echo "#    What would you like to do ?               #"
    echo "#                                              #"
    echo "#          1 ==   Start Oracle docker image    #"
    echo "#                                              #"
    echo "#          2 ==   Stop Oracle docker image     #"
    echo "#                                              #"
    echo "#          3 ==   Bash access                  #"
    echo "#                                              #"
    echo "#          4 ==   SQLPlus nolog connect        #"
    echo "#                                              #"
    echo "#          5 ==   SQLPlus SYSDBA               #"
    echo "#                                              #"
    echo "#          6 ==   SQLPlus user                 #"
    echo "#                                              #"
    echo "#          7 ==   Do NOTHING                   #"
    echo "#                                              #"
    echo "################################################"
    echo 
    echo "Please enter in your choice:> "
    read whatwhat

#   if [ $whatwhat -gt 9 ]
#       then
#       echo "Please enter a valid choice"
#       sleep 3
#       startUp
#   fi
    
}

function doNothing()
{
    echo "################################################"
    echo "You don't want to do nothing...lazy..."
    echo "So...you want to quit...yes? "
    echo "Enter yes or no"
    echo "################################################"
    read doWhat
    if [[ $doWhat = yes ]]; then
        echo "Yes"
        echo "Bye! ¯\_(ツ)_/¯ " 
        exit 1
    else
        echo "No"
        startUp
    fi
    
}

function countDown()
{
    row=2
    col=2
    urls="$@"
 
    msg="Please wait ${1}..."
    clear
    tput cup $row $col
    echo -n "$msg"
    l=${#msg}
    l=$(( l+$col ))
    for i in {30..1}
        do
            tput cup $row $l
            echo -n "$i"
            sleep 1
         done
}

function checkDocker()
{
    # open Docker, only if is not running...super hacky
    if (! docker stats --no-stream ); then
        open /Applications/Docker.app
    while (! docker stats --no-stream ); do
        echo "Waiting for Docker to launch..."
        sleep 1
    done
    fi
}

function checkOrclexists()
{
  # docker container ls -a --no-trunc --format "table {{.ID}}\t {{.Names}}\t {{.Command}}\t" | grep -i oracle  | awk '{print $2}'

    checkDocker
    # get oracle image if present
    export uThere=$(docker container ls -a --no-trunc --format "table {{.ID}}\t {{.Names}}\t {{.Command}}\t" | grep -i oracle  | awk '{print $2}')
    echo "Oracle container found with name: " $uThere

    if [ -z "$uThere" ]; then
        echo "Oracle docker container not found."
    else
        echo "Oracle docker container present."
        echo "Would you like to start it?"
        echo "Enter yes or no:"
        read theChoice
        if [ $theChoice = yes ]; then
            echo "Yes"
            docker restart $uThere
        else
            echo "No"
            echo "Okay dokay ... "
            startUp
        fi

    fi
}

function startOracle()
{
    # example 
    # docker run -d --network="bridge" -p 1521:1521 -p 5500:5500 -it --name Oracle_DB_Container store/oracle/database-enterprise:12.2.0.1

    checkOrclexists
    if [ -z $uThere ]; then
        echo $uThere
        echo "Oracle is going to restart"
    else
        export orclImage=$(docker images --no-trunc | grep oracle | awk '{print $3}' | cut -d : -f 2 )
        echo $orclImage
        docker run -itd --network="bridge" -p 1521:1521 -p 5500:5500  $orclImage
        export runningOrcl=$(docker ps --no-trunc --format '{"name":"{{.Names}}"}'    | cut -d : -f 2 | sed 's/"//g' | sed 's/}//g')
        echo "Oracle is running as: "$runningOrcl
        echo "Please be patient as it takes time for the container to start..."
        countDown
    fi

}


function stopOracle()
{
    checkDocker
    export stopOrcl=$(docker ps --no-trunc | grep -i oracle | awk '{print $1}')
    echo $stopOrcl

    for i in $stopOrcl
    do
        echo $i
        echo "Stopping container: " $i
        docker stop $i
    done

    cleanVolumes

}


function cleanVolumes()
{
    docker volume prune -f 
}


function bashAccess()
{
    checkDocker
    #export orclImage=$(docker ps --format "table {{.Image}}\t{{.Ports}}\t{{.Names}}"| grep -i oracle  | awk '{print $4}')
    # this works by greping the known oracle database port
    export orclImage=$(docker ps --no-trunc --format "table {{.ID}}\t{{.Ports}}" | grep 1521 | awk '{print $1}')
    docker exec -it $orclImage /bin/bash
}


function sqlPlusnolog()
{
    checkDocker
    #export orclImage=$(docker ps --format "table {{.Image}}\t{{.Ports}}\t{{.Names}}"| grep -i oracle  | awk '{print $4}')
    export orclImage=$(docker ps --no-trunc --format "table {{.ID}}\t{{.Ports}}" | grep 1521 | awk '{print $1}')
    docker exec -it $orclImage bash -c "source /home/oracle/.bashrc; sqlplus /nolog"
}

function sysDba()
{
    checkDocker
    export orclImage=$(docker ps --no-trunc --format "table {{.ID}}\t{{.Ports}}" | grep 1521 | awk '{print $1}')
    docker exec -it $orclImage bash -c "source /home/oracle/.bashrc; sqlplus sys/Oradoc_db1@'(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=127.0.0.1)(PORT=1521))
    (CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=ORCLPDB1.localdomain)))' as sysdba"
}

function createMatt()
{
    checkDocker
    export orclImage=$(docker ps --no-trunc --format "table {{.ID}}\t{{.Ports}}" | grep 1521 | awk '{print $1}')
    docker exec -it $orclImage bash -c "source /home/oracle/.bashrc; sqlplus sys/Oradoc_db1@'(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=127.0.0.1)(PORT=1521))
    (CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=ORCLPDB1.localdomain)))' as sysdba <<EOF
    grant sysdba,dba to matt identified by matt;
    exit;
EOF"
}


function sqlPlususer()
{
    checkDocker
    export orclImage=$(docker ps --no-trunc --format "table {{.ID}}\t{{.Ports}}" | grep 1521 | awk '{print $1}')
    createMatt
    docker exec -it $orclImage bash -c "source /home/oracle/.bashrc; sqlplus matt/matt@'(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=127.0.0.1)(PORT=1521))
    (CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=ORCLPDB1.localdomain)))'"
}




# Let's go to work
startUp
case $whatwhat in
    1) 
        startOracle
        ;;
    2) 
        stopOracle
        ;;
    3)
        bashAccess
        ;;   
    4)
        sqlPlusnolog
        ;;
    5) 
        sysDba
        ;;
    6)
        sqlPlususer
        ;;
    7)
        doNothing
        ;;
    8) 
        cleanVolumes
        ;;
esac


