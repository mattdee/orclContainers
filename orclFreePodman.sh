
#!/bin/bash
#
#
   #===================================================================================
   #
   #         FILE: orclFreePodman.sh
   #
   #        USAGE: run it
   #
   #  DESCRIPTION:
   #      OPTIONS:  
   # REQUIREMENTS: 
   #       AUTHOR: Matt D
   #      CREATED: 12.17.2024
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
    clear
    echo "##########################################################"
    echo "# This will manage your Oracle Database Podman container #"
    echo "##########################################################"

    echo
    echo "################################################"
    echo "#                                              #"
    echo "#    What would you like to do ?               #"
    echo "#                                              #"
    echo "#          1  == Start Oracle container        #"
    echo "#          2  == Stop Oracle container         #"
    echo "#          3  == Bash access                   #"
    echo "#          4  == SQLPlus nolog connect         #"
    echo "#          5  == SQLPlus SYSDBA                #"
    echo "#          6  == SQLPlus user                  #"
    echo "#          7  == Do nothing (exit)             #"
    echo "#          8  == Clean unused volumes          #"
    echo "#          9  == Root access                   #"
    echo "#         10  == Install utilities             #"
    echo "#         11  == Copy file into container      #"
    echo "#         12  == Copy file out of container    #"
    echo "#         13  == Remove Oracle container       #"
    echo "#         14  == Setup ORDS                    #"
    echo "#         15  == Serve ORDS                    #"
    echo "#         16  == Check MongoDB API connection  #"
    echo "#                                              #"
    echo "################################################"
    echo 
    read -p "Please enter your choice: " menuChoice
    export menuChoice=$menuChoice
}

# Menu item
function helpMe()
{
    echo "Help wanted..."
    sleep 5
    startUp
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
    
    clear 
    msg="Please wait for Oracle to start ...${1}..."
    tput cup $row $col
    echo -n "$msg"
    l=${#msg}
    l=$(( l+$col ))
    for i in {10..1}
        do
            tput cup $row $l
            echo -n "$i"
            sleep 1
         done
    #startUp
}

function badChoice()
{
    echo "Invalid choice, please try again..."
    sleep 5
    startUp
}

# see if podman is installed and if not, install homebrew and podman with requirements
function checkPodman()
{
    if ! command -v podman > /dev/null 2>&1; then
        echo "Podman is not installed on your system."

        # Prompt the user for installation
        read -p "Would you like to install Podman and its dependencies? (y/n): " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            echo "Installing Podman and dependencies..."

            # Install Homebrew if it's not installed
            if ! command -v brew > /dev/null 2>&1; then
                echo "Homebrew is not installed. Installing Homebrew first..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                export PATH="/usr/local/bin:$PATH"  # For Intel Macs
                export PATH="/opt/homebrew/bin:$PATH"  # For Apple Silicon
            fi

            # Install Podman, QEMU, and vfkit
            brew tap cfergeau/crc;brew install vfkit;brew install qemu;brew install podman;brew install podman-desktop

            # Initialize Podman machine
            echo "Initializing Podman machine..."
            podman machine init --cpus 8 --memory 16384 --disk-size 550

            echo "Starting Podman machine..."
            podman machine start

            echo "Podman installation complete!"
        else
            echo "Podman is required to run this script. Exiting..."
            exit 1
        fi
    fi

    # Verify Podman is running
    if ! podman ps > /dev/null 2>&1; then
        echo "Podman is installed but not running. Starting Podman machine..."
        podman machine start
    fi
}

# Menu item
function copyIn()
{
    checkPodman
    export orclRunning=$(podman ps --no-trunc --format "table {{.ID}}\t {{.Names}}\t" | grep -i Oracle_DB_Container  | awk '{print $2}' )
    echo "Please enter the ABSOLUTE PATH to the file you want copied: "
    read thePath
    echo "Please enter the FILE NAME you want copied: "
    read theFile
    echo "Copying info: " $thePath/$theFile
    podman cp $thePath/$theFile $orclRunning:/tmp

}

# Menu item
function copyOut()
{
    checkPodman
    export orclRunning=$(podman ps --no-trunc --format "table {{.ID}}\t {{.Names}}\t" | grep -i Oracle_DB_Container  | awk '{print $2}' )
    echo "Please enter the ABSOLUTE PATH in the CONTAINER to the file you want copied to host: "
    read thePath
    echo "Please enter the FILE NAME in the CONTAINER you want copied: "
    read theFile
    echo "Copy info: " $orclRunning":" $thePath/$theFile
    podman cp $orclRunning:$thePath/$theFile /tmp/

}

function setorclPwd()
{
    checkPodman
    export orclRunning=$(podman ps --no-trunc --format "table {{.ID}}\t {{.Names}}\t" | grep -i Oracle_DB_Container  | awk '{print $2}' )
    podman exec $orclRunning /home/oracle/setPassword.sh Oradoc_db1
}

# Menu item
function installMongoTools()
{
    export orclImage=$(podman ps --no-trunc --format "table {{.ID}}\t {{.Names}}\t" | grep -i Oracle_DB_Container  | awk '{print $2}' )
    podman exec -i -u 0 $orclImage /usr/bin/bash -c "echo '[mongodb-org-7.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/8/mongodb-org/7.0/aarch64/
gpgcheck=1
enabled=1
gpgkey=https://pgp.mongodb.com/server-7.0.asc' >>/etc/yum.repos.d/mongodb-org-7.0.repo"

    podman exec -i -u 0 $orclImage /usr/bin/yum install -y mongodb-mongosh
   
}

# Menu item
function installUtils()
{
    clear screen
    echo "Installing useful tools after provisioning container..."
    echo "Please be patient as this can take time given network latency."

    checkPodman
    export orclRunning=$(podman ps --no-trunc --format "table {{.ID}}\t {{.Names}}\t" | grep -i Oracle_DB_Container  | awk '{print $2}' )
    # workaround for ol repo issues, need to zero file
    podman exec -it -u 0 $orclRunning /bin/bash -c "/usr/bin/touch /etc/yum/vars/ociregion"
    podman exec -it -u 0 $orclRunning /bin/bash -c "/usr/bin/echo > /etc/yum/vars/ociregion"


    podman exec -it -u 0 $orclRunning /bin/bash -c "/usr/bin/echo 'oracle ALL=(ALL) NOPASSWD: ALL' >>/etc/sudoers"


    podman exec -it -u 0 $orclRunning /usr/bin/rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
    podman exec -it -u 0 $orclRunning /usr/bin/yum update -y

    podman exec -it -u 0 $orclRunning /usr/bin/yum install -y sudo which java-17-openjdk wget htop lsof zip unzip rlwrap git
    # podman exec -it -u 0 $orclRunning /usr/bin/rpm -ivh https://yum.oracle.com/repo/OracleLinux/OL8/oracle/software/x86_64/getPackage/ords-24.1.1-4.el8.noarch.rpm
    # new ords version
    # https://download.oracle.com/otn_software/java/ords/ords-latest.zip
    podman exec $orclRunning /usr/bin/wget -O /home/oracle/ords.zip https://download.oracle.com/otn_software/java/ords/ords-latest.zip
    podman exec $orclRunning /usr/bin/unzip /home/oracle/ords.zip -d /home/oracle/ords/
    

    # install mongo tools
    installMongoTools

    # get my personal tools
    podman exec $orclRunning /usr/bin/wget -O /tmp/PS1.sh https://raw.githubusercontent.com/mattdee/orclDocker/main/PS1.sh
    podman exec $orclRunning /bin/bash /tmp/PS1.sh
    podman exec $orclRunning /usr/bin/wget -O /opt/oracle/product/23ai/dbhomeFree/sqlplus/admin/glogin.sql https://raw.githubusercontent.com/mattdee/orclDocker/main/glogin.sql
    setorclPwd
    startUp
}


function setorclPwd()
{
    checkPodman
    export orclRunning=$(podman ps --no-trunc --format "table {{.ID}}\t {{.Names}}\t" | grep -i Oracle_DB_Container  | awk '{print $2}' )
    podman exec $orclRunning /home/oracle/setPassword.sh Oradoc_db1
}

function createPodnet()
{
    podman network create -d bridge podmannet
}

# Menu item
function listPorts()
{
    export orclRunning=$(podman ps --no-trunc --format "table {{.ID}}\t {{.Names}}\t" | grep -i Oracle_DB_Container  | awk '{print $2}' )
    podman port $orclRunning
}

# Menu item
function startOracle() # start or restart the container named Oracle_DB_Container
{   
    checkPodman
    createPodnet
    # check to see if Oracle_DB_Container is running and if running exit
    export orclRunning=$(podman ps --no-trunc --format "table {{.ID}}\t {{.Names}}\t" | grep -i Oracle_DB_Container  | awk '{print $2}' )
    export orclPresent=$(podman container ls -a --no-trunc --format "table {{.ID}}\t {{.Names}}\t" | grep -i Oracle_DB_Container  | awk '{print $2}')

    if [ "$orclRunning" == "Oracle_DB_Container" ]; then
        echo "Oracle podman container is running, please select other option."
        sleep 5
        startUp
    elif [ "$orclPresent" == "Oracle_DB_Container" ]; then
        echo "Oracle podman container found, restarting..."
        podman restart $orclPresent
        countDown
        serveORDS
    else
        echo "No Oracle podman image found, provisioning..."
        # podman run -d --network="podmannet" -p 1521:1521 -it --name Oracle_DB_Container container-registry.oracle.com/database/free:23.4.0.0

        # x86_64 attempt
        # podman run -d --network="podmannet" --platform linux/amd64 -p 1521:1521 -p 5902:5902 -p 5500:5500 -p 8080:8080 -p 8443:8443 -p 27017:27017 -it --name Oracle_DB_Container container-registry.oracle.com/database/free:latest

        podman run -d --network="podmannet" -p 1521:1521 -p 5902:5902 -p 5500:5500 -p 8080:8080 -p 8443:8443 -p 27017:27017 -it --name Oracle_DB_Container container-registry.oracle.com/database/free:latest

        # podman run --platform linux/amd64 quay.io/podman/hello

        export runningOrcl=$(podman ps --no-trunc --format '{"name":"{{.Names}}"}'    | cut -d : -f 2 | sed 's/"//g' | sed 's/}//g')
        echo "Oracle is running as: "$runningOrcl
        echo "Please be patient as it takes time for the container to start..."
        countDown
        installUtils
    fi
    listPorts

}


# Menu item
function stopOracle()
{
    checkPodman
    export stopOrcl=$(podman ps --no-trunc | grep -i oracle | awk '{print $1}')
    echo $stopOrcl

    for i in $stopOrcl
    do
        echo $i
        echo "Stopping container: " $i
        podman stop $i
    done

    cleanVolumes

}

# Menu item
function cleanVolumes()
{
    podman volume prune -f 
}

# Menu item
function removeContainer()
{
    stopOracle
    podman rm $(podman ps -a | grep Oracle_DB_Container | awk '{print $1}')
}

# Menu item
function bashAccess()
{
    checkPodman
    export orclImage=$(podman ps --no-trunc --format "table {{.ID}}\t {{.Names}}\t" | grep -i Oracle_DB_Container  | awk '{print $2}' )
    podman exec -it $orclImage /bin/bash
}

# Menu item
function rootAccess()
{
    checkPodman
    export orclImage=$(podman ps --no-trunc --format "table {{.ID}}\t {{.Names}}\t" | grep -i Oracle_DB_Container  | awk '{print $2}' )
    podman exec -it -u 0 $orclImage /bin/bash
}


# Menu item
function sqlPlusnolog()
{
    checkPodman
    export orclImage=$(podman ps --no-trunc --format "table {{.ID}}\t {{.Names}}\t" | grep -i Oracle_DB_Container  | awk '{print $2}' )
    podman exec -it $orclImage bash -c "source /home/oracle/.bashrc; sqlplus /nolog"
}

# Menu item
function sysDba()
{
    checkPodman
    export orclImage=$(podman ps --no-trunc --format "table {{.ID}}\t {{.Names}}\t" | grep -i Oracle_DB_Container  | awk '{print $2}' )
    podman exec -it $orclImage bash -c "source /home/oracle/.bashrc; sqlplus sys/Oradoc_db1@'(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=127.0.0.1)(PORT=1521))
    (CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=FREEPDB1)))' as sysdba"
}


function createMatt()
{
    checkPodman
    export orclImage=$(podman ps --no-trunc --format "table {{.ID}}\t {{.Names}}\t" | grep -i Oracle_DB_Container  | awk '{print $2}' )
    podman exec -it $orclImage bash -c "source /home/oracle/.bashrc; sqlplus sys/Oradoc_db1@'(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=127.0.0.1)(PORT=1521))
    (CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=FREEPDB1)))' as sysdba <<EOF
    grant sysdba,dba to matt identified by matt;
    exit;
EOF"
}

# Menu item
function sqlPlususer()
{
    checkPodman
    export orclImage=$(podman ps --no-trunc --format "table {{.ID}}\t {{.Names}}\t" | grep -i Oracle_DB_Container  | awk '{print $2}' )
    createMatt
    podman exec -it $orclImage bash -c "source /home/oracle/.bashrc; sqlplus matt/matt@'(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=127.0.0.1)(PORT=1521))
    (CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=FREEPDB1)))'"
}

# Menu item
function serveORDS()
{
    echo "Attempting to start ORDS in container..."
    export orclImage=$(podman ps --no-trunc --format "table {{.ID}}\t {{.Names}}\t" | grep -i Oracle_DB_Container  | awk '{print $2}' )
    
    podman exec -it $orclImage bash -c "source /home/oracle/.bashrc; sqlplus sys/Oradoc_db1@'(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=127.0.0.1)(PORT=1521))
    (CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=FREEPDB1)))' as sysdba <<EOF
    grant soda_app, create session, create table, create view, create sequence, create procedure, create job, unlimited tablespace to matt;
    exit;
EOF"
    
    # ords enable the matt schema
    podman exec -it $orclImage bash -c "source /home/oracle/.bashrc; sqlplus matt/matt@'(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=127.0.0.1)(PORT=1521))
    (CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=FREEPDB1)))'<<EOF
    exec ords.enable_schema(true);
    exit;
EOF"

    podman exec -d $orclImage /bin/bash -c "/home/oracle/ords/bin/ords --config /home/oracle/ords_config serve > /dev/null 2>&1; sleep 10"
    sleep 10
    podman exec -d $orclImage /bin/bash -c "/usr/bin/ps -ef | grep -i ords"

}

# Menu item
function stopORDS()
{
    export orclImage=$(podman ps --no-trunc --format "table {{.ID}}\t {{.Names}}\t" | grep -i Oracle_DB_Container  | awk '{print $2}' )
    podman exec $orclImage /bin/bash -c "for i in $(ps -ef | grep ords | awk '{print $2}'); do echo $i; kill -9 $i; done"
}

# Menu item
function setupORDS()
{

    checkPodman
    export orclImage=$(podman ps --no-trunc --format "table {{.ID}}\t {{.Names}}\t" | grep -i Oracle_DB_Container  | awk '{print $2}' )
        
    # make temp passwd file
    podman exec -i -u 0 $orclImage /bin/bash -c "echo 'Oradoc_db1' > /tmp/orclpwd"

    echo "Configuring ORDS..."

    # user for ORDS
    createMatt
    
    # ORDS silent set up
    podman exec -i $orclImage /bin/bash -c "/home/oracle/ords/bin/ords --config /home/oracle/ords_config install --admin-user SYS --db-hostname localhost --db-port 1521 --db-servicename FREEPDB1 --log-folder /tmp/ --feature-sdw true --feature-db-api true --feature-rest-enabled-sql true --password-stdin </tmp/orclpwd"
    
    # ORDS manual set up
    # podman exec -i $orclImage /home/oracle/ords/bin/ords --config /home/oracle/ords_config install

    # ORDS uninstall
    # /home/oracle/ords/bin/ords uninstall --admin-user SYS --db-hostname localhost --db-port 1521 --db-servicename FREEPDB1 --log-folder /tmp/ --force --password-stdin </tmp/orclpwd

    #stopORDS

    # set mongoapi configs
    podman exec -it $orclImage /home/oracle/ords/bin/ords --config /home/oracle/ords_config config set mongo.enabled true
    podman exec -it $orclImage /home/oracle/ords/bin/ords --config /home/oracle/ords_config config set mongo.port 27017
    podman exec -it $orclImage /home/oracle/ords/bin/ords --config /home/oracle/ords_config config info mongo.enabled
    podman exec -it $orclImage /home/oracle/ords/bin/ords --config /home/oracle/ords_config config info mongo.port

    serveORDS

    # set db privs for user
    podman exec -it $orclImage bash -c "source /home/oracle/.bashrc; sqlplus sys/Oradoc_db1@'(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=127.0.0.1)(PORT=1521))
    (CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=FREEPDB1)))' as sysdba <<EOF
    grant soda_app, create session, create table, create view, create sequence, create procedure, create job, unlimited tablespace to matt;
    exit;
EOF"
    
    # ords enable the matt schema
    podman exec -it $orclImage bash -c "source /home/oracle/.bashrc; sqlplus matt/matt@'(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=127.0.0.1)(PORT=1521))
    (CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=FREEPDB1)))'<<EOF
    exec ords.enable_schema(true);
    exit;
EOF"

}

# Menu item
function checkMongoAPI()
{
    # test mongo connections in the container
    echo "Checking MongoDB API health..."
    export orclImage=$(podman ps --no-trunc --format "table {{.ID}}\t {{.Names}}\t" | grep -i Oracle_DB_Container  | awk '{print $2}' )
    podman exec -it $orclImage bash -c "mongosh --tlsAllowInvalidCertificates 'mongodb://matt:matt@127.0.0.1:27017/matt?authMechanism=PLAIN&ssl=true&retryWrites=false&loadBalanced=true'<<EOF
    db.createCollection('test123');
EOF"
    
    podman exec -it $orclImage bash -c "mongosh --tlsAllowInvalidCertificates 'mongodb://matt:matt@127.0.0.1:27017/matt?authMechanism=PLAIN&ssl=true&retryWrites=false&loadBalanced=true'<<EOF
    db.test123.insertOne({ name: 'Matt DeMarco', email: 'matthew.demarco@oracle.com', notes: 'It is me' });
EOF"

    podman exec -it $orclImage bash -c "mongosh --tlsAllowInvalidCertificates 'mongodb://matt:matt@127.0.0.1:27017/matt?authMechanism=PLAIN&ssl=true&retryWrites=false&loadBalanced=true'<<EOF
    db.test123.find().pretty();
EOF"
    
}


function setupAPEX()
{
    # reference
    # https://docs.oracle.com/en/database/oracle/apex/23.2/htmig/downloading-installing-apex.html#GUID-7E432C6D-CECC-4977-B183-3C654380F7BF
    checkPodman
    export orclImage=$(podman ps --no-trunc --format "table {{.ID}}\t {{.Names}}\t" | grep -i Oracle_DB_Container  | awk '{print $2}' )
    
    # get latest APEX release
    podman exec $orclRunning /usr/bin/wget -O /home/oracle/apex-latest.zip https://download.oracle.com/otn_software/apex/apex-latest.zip

    # sysdba sql statement setup steps
    # @apexins.sql SYSAUX SYSAUX TEMP /i/
    # @apex_rest_config.sql Oracle Oracle
    # ALTER USER APEX_LISTENER IDENTIFIED BY Oracle ACCOUNT UNLOCK;
    # ALTER USER APEX_PUBLIC_USER IDENTIFIED BY Oracle ACCOUNT UNLOCK;
    # ALTER USER APEX_REST_PUBLIC_USER IDENTIFIED BY Oracle ACCOUNT UNLOCK;



}

# Process arguments to bypass the menu
case "$1" in
    "start")
        echo "Starting container..."
        startOracle
        ;;
    "stop")
        echo "Stopping container..."
        stopOracle
        ;;
    "restart")
        echo "Restarting container..."
        stopOracle
        startOracle
        ;;
    "bash")
        echo "Attempting bash access..."
        bashAccess
        ;;
    "root")
        echo "Attempting root access..."
        rootAccess
        ;;
    "sql")
        echo "Attempting SQLPlus access..."
        sqlPlususer
        ;;
    "ords")
        echo "Attempting to start ORDS..."
        serveORDS
        ;;
    "mongoAPI")
        echo "Attempting to check Mongo API status..."
        checkMongo
        ;;
    "help")
        echo "Providing help..."
        helpMe
        ;;
    "")
        echo "No args...proceed with menu"
        #sleep 3
        ;;
    *)
        echo "Invalid argument: $1"
        ;;
esac



# Let's go to work
startUp
case $menuChoice in
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
    9)
        rootAccess
        ;;
    10) 
        installUtils
        ;;
    11)
        copyIn
        ;;
    12)
        copyOut
        ;;
    13)
        removeContainer
        ;;
    14)
        setupORDS
        ;;
    15)
        serveORDS
        ;;
    16)
        checkMongoAPI
        ;;
    *) 
        badChoice
        ;;
    esac

