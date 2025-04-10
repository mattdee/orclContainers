#!/bin/bash
#
#
   #===================================================================================
   #
   #         FILE: orclFreePodman.sh
   #
   #        USAGE: ./orclFreePodman.sh [start|stop|restart|bash|root|sql|ords|mongoapi|help]
   #
   #  DESCRIPTION: Oracle Database Free podman container management script
   #      OPTIONS: See menu or command line arguments
   # REQUIREMENTS: Podman, internet connection
   #       AUTHOR: Matt D
   #      CREATED: 12.17.2024
   #      VERSION: 1.1
   #
   #===================================================================================

# Global variables
ORACLE_USER="matt"
ORACLE_PASS="matt"
ORACLE_SYS_PASS="Oradoc_db1"
ORACLE_CONTAINER="Oracle_DB_Container"
ORACLE_PDB="FREEPDB1"
CONTAINER_PORT_MAP="-p 1521:1521 -p 5902:5902 -p 5500:5500 -p 8080:8080 -p 8443:8443 -p 27017:27017"
MAX_INVALID=3
INVALID_COUNT=0

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

#===========================
# Helper Functions
#===========================

logInfo() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

logWarning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

logError() {
    echo -e "${RED}[ERROR]${NC} $1"
}

logSuccess() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Display formatted menu
displayMenu() {
    clear
    echo -e "${CYAN}===========================================================================${NC}"
    echo -e "${CYAN}          Oracle Database Free Edition Management Script                   ${NC}"
    echo -e "${CYAN}===========================================================================${NC}"
    
    echo -e "\n${GREEN}Container Management:${NC}"
    echo "  1) Start Oracle container          6) Install utilities"
    echo "  2) Stop Oracle container           7) Copy file into container"
    echo "  3) Bash access                     8) Copy file out of container"
    echo "  4) Root access                     9) Clean unused volumes"
    echo "  5) Remove Oracle container         10) Exit script"
    
    echo -e "\n${GREEN}Database Access & Utilities:${NC}"
    echo "  11) SQL*Plus nolog connection      14) Setup ORDS"
    echo "  12) SQL*Plus user connection       15) Start ORDS service"
    echo "  13) SQL*Plus SYSDBA connection     16) Check MongoDB API connection"

    echo -e "\n${CYAN}===========================================================================${NC}"
    read -p "Please enter your choice [1-16]: " menuChoice
    export menuChoice=$menuChoice
}

# Check if podman is installed and running
checkPodman() {
    if ! command -v podman > /dev/null 2>&1; then
        logError "Podman is not installed on your system."

        read -p "Would you like to install Podman and its dependencies? (y/n): " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            logInfo "Installing Podman and dependencies..."

            # Install Homebrew if it's not installed
            if ! command -v brew > /dev/null 2>&1; then
                logInfo "Homebrew is not installed. Installing Homebrew first..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                export PATH="/usr/local/bin:$PATH"  # For Intel Macs
                export PATH="/opt/homebrew/bin:$PATH"  # For Apple Silicon
            fi

            # Install Podman, QEMU, and vfkit
            brew tap cfergeau/crc
            brew install vfkit qemu podman podman-desktop

            # Initialize Podman machine
            logInfo "Initializing Podman machine..."
            podman machine init --cpus 8 --memory 16384 --disk-size 550

            logInfo "Starting Podman machine..."
            podman machine start

            logSuccess "Podman installation complete!"
        else
            logError "Podman is required to run this script. Exiting..."
            exit 1
        fi
    fi

    # Verify Podman is running
    if ! podman ps > /dev/null 2>&1; then
        logInfo "Podman is installed but not running. Starting Podman machine..."
        podman machine start
    fi
}

# Create podman network if it doesn't exist
createPodnet() {
    if ! podman network inspect podmannet &>/dev/null; then
        logInfo "Creating podman network 'podmannet'..."
        podman network create -d bridge podmannet
    fi
}

# Get running container ID/name
getContainerId() {
    export orclRunning=$(podman ps --no-trunc --format "table {{.ID}}\t {{.Names}}\t" | grep -i $ORACLE_CONTAINER | awk '{print $2}')
    echo $orclRunning
}

# Countdown timer
countDown() {
    message=${1:-"Please wait..."}
    seconds=${2:-5}
    
    logInfo "$message"
    for (( i=$seconds; i>=1; i-- )); do
        echo -ne "\rStarting in $i seconds..."
        sleep 1
    done
    echo -e "\rStarting now!                  "
}

# Handle invalid menu choice
badChoice() {
    # Increment the invalid choice counter
    ((INVALID_COUNT++))

    logWarning "Invalid choice, please try again..."
    logWarning "Attempt $INVALID_COUNT of $MAX_INVALID."

    # Check if invalid attempts exceed the max allowed
    if [ "$INVALID_COUNT" -ge "$MAX_INVALID" ]; then
        logError "Too many invalid attempts. Exiting the script..."
        exit 1
    fi

    sleep 2
}

#===========================
# Core Functions
#===========================

# Exit function
doNothing() {
    logWarning "You want to quit...yes?"
    read -p "Enter yes or no: " doWhat
    if [[ $doWhat = yes ]]; then
        logInfo "Bye! ¯\\_(ツ)_/¯"
        exit 0
    else
        return
    fi
}

# List container ports
listPorts() {
    container_id=$(getContainerId)
    if [ -n "$container_id" ]; then
        logInfo "Container ports:"
        podman port $container_id
    else
        logError "No running container found."
    fi
}

# Start Oracle container
startOracle() {
    checkPodman
    createPodnet
    
    # Check if container is already running
    export orclRunning=$(getContainerId)
    export orclPresent=$(podman container ls -a --no-trunc --format "table {{.ID}}\t {{.Names}}\t" | grep -i $ORACLE_CONTAINER | awk '{print $2}')

    if [ "$orclRunning" == "$ORACLE_CONTAINER" ]; then
        logWarning "Oracle podman container is already running."
        listPorts
        return
    elif [ "$orclPresent" == "$ORACLE_CONTAINER" ]; then
        logInfo "Oracle podman container found, restarting..."
        podman restart $orclPresent
        countDown "Waiting for Oracle to start" 5
        serveORDS
    else
        echo "Please choose the Oracle Database container version:"
        echo "1. Lite Version (Good for general database development)"
        echo "2. Full Version (Required for the MongoDB API)"
        read -p "Enter your choice [1/2]: " choice

        case $choice in
            1)
                image="container-registry.oracle.com/database/free:23.5.0.0-lite"
                ;;
            2)
                image="container-registry.oracle.com/database/free:latest"
                ;;
            *)
                logWarning "Invalid choice. Defaulting to Full version."
                image="container-registry.oracle.com/database/free:latest"
                ;;
        esac

        logInfo "Provisioning new Oracle container with image: $image"
        podman run -d --network="podmannet" $CONTAINER_PORT_MAP -it --name $ORACLE_CONTAINER $image

        if [ $? -ne 0 ]; then
            logError "Failed to start Oracle container."
            return 1
        fi

        logSuccess "Oracle container started successfully."
        countDown "Waiting for Oracle to initialize" 15
        installUtils
    fi
    listPorts
}

# Stop Oracle container
stopOracle() {
    checkPodman
    export stopOrcl=$(podman ps --no-trunc | grep -i oracle | awk '{print $1}')
    
    if [ -z "$stopOrcl" ]; then
        logWarning "No Oracle containers are running."
        return
    fi

    for i in $stopOrcl; do
        logInfo "Stopping container: $i"
        podman stop $i
        if [ $? -eq 0 ]; then
            logSuccess "Container stopped successfully."
        else
            logError "Failed to stop container."
        fi
    done

    cleanVolumes
}

# Clean unused volumes
cleanVolumes() {
    logInfo "Cleaning unused volumes..."
    podman volume prune -f
    logSuccess "Volumes cleaned."
}

# Remove container
removeContainer() {
    stopOracle
    logInfo "Removing Oracle container..."
    podman rm $(podman ps -a | grep $ORACLE_CONTAINER | awk '{print $1}')
    if [ $? -eq 0 ]; then
        logSuccess "Container removed successfully."
    else
        logError "Failed to remove container."
    fi
}

# Get bash access to container
bashAccess() {
    checkPodman
    export orclImage=$(getContainerId)
    
    if [ -z "$orclImage" ]; then
        logError "Oracle container is not running."
        return 1
    fi
    
    logInfo "Opening bash shell in container..."
    podman exec -it $orclImage /bin/bash
}

# Get root access to container
rootAccess() {
    checkPodman
    export orclImage=$(getContainerId)
    
    if [ -z "$orclImage" ]; then
        logError "Oracle container is not running."
        return 1
    fi
    
    logInfo "Opening root shell in container..."
    podman exec -it -u 0 $orclImage /bin/bash
}

# Get SQLPlus nolog access
sqlPlusNolog() {
    checkPodman
    export orclImage=$(getContainerId)
    
    if [ -z "$orclImage" ]; then
        logError "Oracle container is not running."
        return 1
    fi
    
    logInfo "Opening SQLPlus session (no login)..."
    podman exec -it $orclImage bash -c "source /home/oracle/.bashrc; sqlplus /nolog"
}

# Get SYSDBA access
sysDba() {
    checkPodman
    export orclImage=$(getContainerId)
    
    if [ -z "$orclImage" ]; then
        logError "Oracle container is not running."
        return 1
    fi
    
    logInfo "Opening SQLPlus session as SYSDBA..."
    podman exec -it $orclImage bash -c "source /home/oracle/.bashrc; sqlplus sys/$ORACLE_SYS_PASS@'(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=127.0.0.1)(PORT=1521))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=$ORACLE_PDB)))' as sysdba"
}

# Create user account
createUser() {
    checkPodman
    export orclImage=$(getContainerId)
    
    if [ -z "$orclImage" ]; then
        logError "Oracle container is not running."
        return 1
    fi
    
    logInfo "Creating user account..."
    podman exec -it $orclImage bash -c "source /home/oracle/.bashrc; sqlplus sys/$ORACLE_SYS_PASS@'(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=127.0.0.1)(PORT=1521))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=$ORACLE_PDB)))' as sysdba <<EOF
    grant sysdba,dba to $ORACLE_USER identified by $ORACLE_PASS;
    exit;
EOF"
}

# Get SQLPlus user access
sqlPlusUser() {
    checkPodman
    export orclImage=$(getContainerId)
    
    if [ -z "$orclImage" ]; then
        logError "Oracle container is not running."
        return 1
    fi
    
    createUser
    logInfo "Opening SQLPlus session as $ORACLE_USER..."
    podman exec -it $orclImage bash -c "source /home/oracle/.bashrc; sqlplus $ORACLE_USER/$ORACLE_PASS@'(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=127.0.0.1)(PORT=1521))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=$ORACLE_PDB)))'"
}

# Set Oracle password
setOrclPwd() {
    checkPodman
    export orclRunning=$(getContainerId)
    
    if [ -z "$orclRunning" ]; then
        logError "Oracle container is not running."
        return 1
    fi
    
    logInfo "Setting Oracle password..."
    podman exec $orclRunning /home/oracle/setPassword.sh $ORACLE_SYS_PASS
}

# Install MongoDB tools
installMongoTools() {
    export orclImage=$(getContainerId)
    
    if [ -z "$orclImage" ]; then
        logError "Oracle container is not running."
        return 1
    fi
    
    logInfo "Installing MongoDB tools..."
    podman exec -i -u 0 $orclImage /usr/bin/bash -c "echo '[mongodb-org-8.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/8/mongodb-org/8.0/aarch64/
gpgcheck=1
enabled=1
gpgkey=https://pgp.mongodb.com/server-8.0.asc' >>/etc/yum.repos.d/mongodb-org-8.0.repo"

    podman exec -i -u 0 $orclImage /usr/bin/yum install -y mongodb-mongosh
    logSuccess "MongoDB tools installed successfully."
}

# Install utilities
installUtils() {
    logInfo "Installing useful tools after provisioning container..."
    logWarning "Please be patient as this can take time given network latency."

    checkPodman
    export orclRunning=$(getContainerId)
    
    if [ -z "$orclRunning" ]; then
        logError "Oracle container is not running."
        return 1
    fi
    
    # workaround for ol repo issues
    logInfo "Configuring YUM repositories..."
    podman exec -it -u 0 $orclRunning /bin/bash -c "/usr/bin/touch /etc/yum/vars/ociregion"
    podman exec -it -u 0 $orclRunning /bin/bash -c "/usr/bin/echo > /etc/yum/vars/ociregion"

    # Add sudo access for oracle user
    podman exec -it -u 0 $orclRunning /bin/bash -c "/usr/bin/echo 'oracle ALL=(ALL) NOPASSWD: ALL' >>/etc/sudoers"

    # Install EPEL repository
    logInfo "Installing EPEL repository..."
    podman exec -it -u 0 $orclRunning /usr/bin/rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
    podman exec -it -u 0 $orclRunning /usr/bin/yum update -y

    # Install required packages
    logInfo "Installing required packages..."
    podman exec -it -u 0 $orclRunning /usr/bin/yum install -y sudo which java-17-openjdk wget htop lsof zip unzip rlwrap git
   
    # Download and install ORDS
    logInfo "Downloading and installing ORDS..."
    podman exec $orclRunning /usr/bin/wget -O /home/oracle/ords.zip https://download.oracle.com/otn_software/java/ords/ords-latest.zip
    podman exec $orclRunning /usr/bin/unzip /home/oracle/ords.zip -d /home/oracle/ords/
    
    # Install MongoDB tools
    installMongoTools

    # Install personal tools
    logInfo "Installing personal tools..."
    podman exec $orclRunning /usr/bin/wget -O /tmp/PS1.sh https://raw.githubusercontent.com/mattdee/orclDocker/main/PS1.sh
    podman exec $orclRunning /bin/bash /tmp/PS1.sh
    podman exec $orclRunning /usr/bin/wget -O /opt/oracle/product/23ai/dbhomeFree/sqlplus/admin/glogin.sql https://raw.githubusercontent.com/mattdee/orclDocker/main/glogin.sql
    
    # Set Oracle password
    setOrclPwd
    
    logSuccess "Utilities installation complete!"
}

# Copy file into container
copyIn() {
    checkPodman
    export orclRunning=$(getContainerId)
    
    if [ -z "$orclRunning" ]; then
        logError "Oracle container is not running."
        return 1
    fi
    
    read -p "Please enter the ABSOLUTE PATH to the file you want copied: " thePath
    read -p "Please enter the FILE NAME you want copied: " theFile
    
    logInfo "Copying file: $thePath/$theFile into container..."
    podman cp $thePath/$theFile $orclRunning:/tmp
    
    if [ $? -eq 0 ]; then
        logSuccess "File copied successfully to /tmp/$theFile in the container."
    else
        logError "Failed to copy file into container."
    fi
}

# Copy file out of container
copyOut() {
    checkPodman
    export orclRunning=$(getContainerId)
    
    if [ -z "$orclRunning" ]; then
        logError "Oracle container is not running."
        return 1
    fi
    
    read -p "Please enter the ABSOLUTE PATH in the CONTAINER to the file you want copied to host: " thePath
    read -p "Please enter the FILE NAME in the CONTAINER you want copied: " theFile
    
    logInfo "Copying file: $orclRunning:$thePath/$theFile to host..."
    podman cp $orclRunning:$thePath/$theFile /tmp/
    
    if [ $? -eq 0 ]; then
        logSuccess "File copied successfully to /tmp/$theFile on your host."
    else
        logError "Failed to copy file from container."
    fi
}

# Setup ORDS
setupORDS() {
    checkPodman
    export orclImage=$(getContainerId)
    
    if [ -z "$orclImage" ]; then
        logError "Oracle container is not running."
        return 1
    fi
    
    # Create temp password file
    logInfo "Creating temporary password file..."
    podman exec -i -u 0 $orclImage /bin/bash -c "echo '$ORACLE_SYS_PASS' > /tmp/orclpwd"

    logInfo "Configuring ORDS..."

    # Create user for ORDS
    createUser
    
    # ORDS silent setup
    logInfo "Installing ORDS..."
    podman exec -i $orclImage /bin/bash -c "/home/oracle/ords/bin/ords --config /home/oracle/ords_config install --admin-user SYS --db-hostname localhost --db-port 1521 --db-servicename $ORACLE_PDB --log-folder /tmp/ --feature-sdw true --feature-db-api true --feature-rest-enabled-sql true --password-stdin </tmp/orclpwd"
    
    # Set MongoDB API configs
    logInfo "Configuring MongoDB API settings..."
    podman exec -it $orclImage /home/oracle/ords/bin/ords --config /home/oracle/ords_config config set mongo.enabled true
    podman exec -it $orclImage /home/oracle/ords/bin/ords --config /home/oracle/ords_config config set mongo.port 27017
    
    # Display MongoDB API settings
    podman exec -it $orclImage /home/oracle/ords/bin/ords --config /home/oracle/ords_config config info mongo.enabled
    podman exec -it $orclImage /home/oracle/ords/bin/ords --config /home/oracle/ords_config config info mongo.port
    podman exec -it $orclImage /home/oracle/ords/bin/ords --config /home/oracle/ords_config config info mongo.tls

    # Start ORDS
    serveORDS

    # Set database privileges for user
    logInfo "Setting database privileges..."
    podman exec -it $orclImage bash -c "source /home/oracle/.bashrc; sqlplus sys/$ORACLE_SYS_PASS@'(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=127.0.0.1)(PORT=1521))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=$ORACLE_PDB)))' as sysdba <<EOF
    grant soda_app, create session, create table, create view, create sequence, create procedure, create job, unlimited tablespace to $ORACLE_USER;
    exit;
EOF"
    
    # Enable ORDS for user schema
    logInfo "Enabling ORDS for $ORACLE_USER schema..."
    podman exec -it $orclImage bash -c "source /home/oracle/.bashrc; sqlplus $ORACLE_USER/$ORACLE_PASS@'(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=127.0.0.1)(PORT=1521))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=$ORACLE_PDB)))'<<EOF
    exec ords.enable_schema(true);
    exit;
EOF"

    logSuccess "ORDS setup complete!"
}

# Serve ORDS
serveORDS() {
    logInfo "Starting ORDS in container..."
    export orclImage=$(getContainerId)
    
    if [ -z "$orclImage" ]; then
        logError "Oracle container is not running."
        return 1
    fi
    
    # Set database privileges
    podman exec -it $orclImage bash -c "source /home/oracle/.bashrc; sqlplus sys/$ORACLE_SYS_PASS@'(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=127.0.0.1)(PORT=1521))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=$ORACLE_PDB)))' as sysdba <<EOF
    grant soda_app, create session, create table, create view, create sequence, create procedure, create job, unlimited tablespace to $ORACLE_USER;
    exit;
EOF"
    
    # Enable ORDS for schema
    podman exec -it $orclImage bash -c "source /home/oracle/.bashrc; sqlplus $ORACLE_USER/$ORACLE_PASS@'(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=127.0.0.1)(PORT=1521))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=$ORACLE_PDB)))'<<EOF
    exec ords.enable_schema(true);
    exit;
EOF"

    # Start ORDS service
    podman exec -d $orclImage /bin/bash -c "/home/oracle/ords/bin/ords --config /home/oracle/ords_config serve > /dev/null 2>&1; sleep 10"
    sleep 5
    
    # Verify ORDS is running
    podman exec $orclImage /bin/bash -c "/usr/bin/ps -ef | grep -i ords"
    
    logSuccess "ORDS started successfully!"
}

# Stop ORDS
stopORDS() {
    export orclImage=$(getContainerId)
    
    if [ -z "$orclImage" ]; then
        logError "Oracle container is not running."
        return 1
    fi
    
    logInfo "Stopping ORDS..."
    podman exec $orclImage /bin/bash -c "for i in $(ps -ef | grep ords | awk '{print $2}'); do echo $i; kill -9 $i; done"
    logSuccess "ORDS stopped successfully!"
}

# Check MongoDB API
checkMongoAPI() {
    # Test MongoDB connections in the container
    logInfo "Checking MongoDB API health..."
    export orclImage=$(getContainerId)
    
    if [ -z "$orclImage" ]; then
        logError "Oracle container is not running."
        return 1
    fi
    
    logInfo "Creating test collection..."
    podman exec -it $orclImage bash -c "mongosh --tlsAllowInvalidCertificates 'mongodb://$ORACLE_USER:$ORACLE_PASS@127.0.0.1:27017/$ORACLE_USER?authMechanism=PLAIN&ssl=true&retryWrites=false&loadBalanced=true'<<EOF
    db.createCollection('test123');
EOF"
    
    logInfo "Inserting test document..."
    podman exec -it $orclImage bash -c "mongosh --tlsAllowInvalidCertificates 'mongodb://$ORACLE_USER:$ORACLE_PASS@127.0.0.1:27017/$ORACLE_USER?authMechanism=PLAIN&ssl=true&retryWrites=false&loadBalanced=true'<<EOF
    db.test123.insertOne({ name: 'Matt DeMarco', email: 'matthew.demarco@oracle.com', notes: 'It is me' });
EOF"

    logInfo "Reading test document..."
    podman exec -it $orclImage bash -c "mongosh --tlsAllowInvalidCertificates 'mongodb://$ORACLE_USER:$ORACLE_PASS@127.0.0.1:27017/$ORACLE_USER?authMechanism=PLAIN&ssl=true&retryWrites=false&loadBalanced=true'<<EOF
    db.test123.find().pretty();
EOF"
    
    logSuccess "MongoDB API check complete!"
}

# Setup APEX (function stub for future implementation)
setupAPEX() {
    logInfo "APEX setup is not fully implemented yet."
    
    checkPodman
    export orclImage=$(getContainerId)
    
    if [ -z "$orclImage" ]; then
        logError "Oracle container is not running."
        return 1
    fi
    
    # Reference steps
    logInfo "Reference steps for APEX setup:"
    logInfo "1. Download APEX"
    logInfo "2. Install APEX using SQL scripts"
    logInfo "3. Configure APEX users"
    
    # get latest APEX release
    podman exec $orclRunning /usr/bin/wget -O /home/oracle/apex-latest.zip https://download.oracle.com/otn_software/apex/apex-latest.zip

    # Show pending steps
    logInfo "Implementation pending for:"
    logInfo "- @apexins.sql SYSAUX SYSAUX TEMP /i/"
    logInfo "- @apex_rest_config.sql Oracle Oracle"
    logInfo "- ALTER USER APEX_LISTENER IDENTIFIED BY Oracle ACCOUNT UNLOCK;"
    logInfo "- ALTER USER APEX_PUBLIC_USER IDENTIFIED BY Oracle ACCOUNT UNLOCK;"
    logInfo "- ALTER USER APEX_REST_PUBLIC_USER IDENTIFIED BY Oracle ACCOUNT UNLOCK;"
}

#===========================
# Main Program
#===========================

    # Process arguments to bypass the menu
case "$1" in
    "start")
        logInfo "Starting container..."
        startOracle
        exit 0
        ;;
    "stop")
        logInfo "Stopping container..."
        stopOracle
        exit 0
        ;;
    "restart")
        logInfo "Restarting container..."
        stopOracle
        startOracle
        exit 0
        ;;
    "bash")
        logInfo "Attempting bash access..."
        bashAccess
        exit 0
        ;;
    "root")
        logInfo "Attempting root access..."
        rootAccess
        exit 0
        ;;
    "sql")
        logInfo "Attempting SQLPlus access..."
        sqlPlusUser
        exit 0
        ;;
    "ords")
        logInfo "Attempting to start ORDS..."
        serveORDS
        exit 0
        ;;
    "mongoapi")
        logInfo "Attempting to check Mongo API status..."
        checkMongoAPI
        exit 0
        ;;
    "help")
        echo -e "${BLUE}===========================================================================${NC}"
        echo -e "${BLUE}          Oracle Database Free Edition Management Script                   ${NC}"
        echo -e "${BLUE}===========================================================================${NC}"
        echo 
        echo "Usage: $0 [command]"
        echo 
        echo "Container Management Commands:"
        echo "  start    - Start Oracle container"
        echo "  stop     - Stop Oracle container"
        echo "  restart  - Restart Oracle container"
        echo "  bash     - Bash access to container"
        echo "  root     - Root access to container"
        echo 
        echo "Database Access Commands:"
        echo "  sql      - SQLPlus user connection"
        echo "  ords     - Start ORDS"
        echo "  mongoapi - Check MongoDB API connection"
        echo "  help     - Show this help message"
        echo 
        echo "If no command is provided, the script will start in interactive menu mode."
        echo -e "${BLUE}===========================================================================${NC}"
        exit 0
        ;;
    "")
        logInfo "No args provided. Starting menu interface..."
        ;;
    *)
        logError "Invalid argument: $1"
        logInfo "Run '$0 help' for usage information."
        exit 1
        ;;
esac

# Main menu loop
while true; do
    displayMenu
    
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
            rootAccess
            ;;
        5) 
            removeContainer
            ;;
        6)
            installUtils
            ;;
        7)
            copyIn
            ;;
        8)
            copyOut
            ;;
        9)  
            cleanVolumes
            ;;
        10)
            doNothing
            ;;
        11)
            sqlPlusNolog
            ;;
        12)
            sqlPlusUser
            ;;
        13)
            sysDba
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
    
    # Reset count after a valid choice
    if [[ $menuChoice =~ ^[1-9]|1[0-6]$ ]]; then
        INVALID_COUNT=0
    fi
    
    # Pause after each operation to view results
    if [[ $menuChoice != 10 && $menuChoice =~ ^[1-9]|1[0-6]$ ]]; then
        echo
        read -p "Press Enter to continue..." dummy
    fi
done