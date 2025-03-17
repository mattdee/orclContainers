# Oracle Database Container Management Scripts

A collection of bash scripts to easily manage Oracle Database containers in either Docker or Podman environments.

## Overview

> **Note:** `orclDocker.sh` is maintained for historical reasons only and is no longer actively developed. `orclFreePodman.sh` is the preferred and actively maintained script for managing Oracle Database containers.

These scripts provide a convenient way to manage Oracle Database containers, allowing you to:
- Start/stop containers
- Access the container shell (bash)
- Connect to the database via SQLPlus
- Set up and serve ORDS (Oracle REST Data Services)
- Configure and test MongoDB API compatibility
- Install additional utilities
- Copy files in and out of the container
- And more

## Scripts

The repository contains two main scripts:

1. **orclFreePodman.sh** - For Podman environments (works on more platforms) - **Recommended**
2. **orclDocker.sh** - For Docker environments (macOS) - Maintained for historical purposes only

## Prerequisites

### For Docker (orclDocker.sh)
- Docker Desktop installed and running on macOS
- Internet connection for pulling images and installing utilities

### For Podman (orclFreePodman.sh)
- Podman installed (script can help install it if not present)
- On macOS: Homebrew for installing dependencies
- Internet connection for pulling images and installing utilities

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/your-username/orclDocker.git
   cd orclDocker
   ```

2. Make the scripts executable:
   ```bash
   chmod +x orclDocker.sh orclFreePodman.sh
   ```

## Usage

### Interactive Menu

Both scripts provide an interactive menu when run without arguments:

```bash
# Recommended: For Podman
./orclFreePodman.sh

# For Docker (legacy)
./orclDocker.sh
```

### Command Line Arguments

Both scripts support direct commands for common operations:

```bash
# Recommended: Using Podman
./orclFreePodman.sh start    # Start the Oracle container
./orclFreePodman.sh stop     # Stop the Oracle container
./orclFreePodman.sh bash     # Access bash shell in the container
./orclFreePodman.sh sql      # Access SQLPlus as a user
./orclFreePodman.sh ords     # Start ORDS server

# Legacy: Using Docker
./orclDocker.sh [command]    # Same commands as above
```

## Menu Options

### orclFreePodman.sh Options (Recommended)

1. Start Oracle container
2. Stop Oracle container
3. Bash access
4. SQLPlus nolog connect
5. SQLPlus SYSDBA
6. SQLPlus user
7. Do nothing (exit)
8. Clean unused volumes
9. Root access
10. Install utilities
11. Copy file into container
12. Copy file out of container
13. Remove Oracle container
14. Setup ORDS
15. Serve ORDS
16. Check MongoDB API connection

### orclDocker.sh Options (Legacy)

1. Start Oracle docker image
2. Stop Oracle docker image
3. Bash access
4. SQLPlus nolog connect
5. SQLPlus SYSDBA
6. SQLPlus user
7. Do NOTHING (exit)

## Oracle Database Container Details

- **Image**: Oracle Database Free
- **Version**: Latest (23c AI)
- **Default Credentials**:
  - SYS/SYSTEM password: `Oradoc_db1`
  - Created user: `matt` with password `matt`
- **Exposed Ports**:
  - 1521: Oracle Database listener
  - 5500: Enterprise Manager Express
  - 8080/8443: ORDS (Oracle REST Data Services)
  - 27017: MongoDB API compatibility

## Features

### ORDS (Oracle REST Data Services)
The scripts support automatic setup and serving of ORDS, allowing RESTful web services access to the Oracle database.

### MongoDB API Compatibility
Oracle Database 23c includes MongoDB API compatibility. These scripts support configuration and testing of this feature.

### Container Management
- Start/stop/restart containers
- Clean unused volumes
- Install additional utilities (sudo, wget, htop, etc.)
- File transfer between host and container

### Database Access
- SQLPlus with various connection methods
- Automatic user creation with DBA privileges

## Why Podman?

Podman offers several advantages over Docker:

1. **Daemonless architecture**: Podman doesn't require a background daemon to run
2. **Rootless containers**: Improved security with containers that don't require root privileges
3. **Cross-platform compatibility**: Works well on Linux, macOS, and Windows
4. **OCI compliance**: Full compatibility with OCI (Open Container Initiative) standards
5. **Resource management**: Better management of CPU, memory, and storage resources

## Example Workflows

### Setting Up a New Oracle Database Container

```bash
./orclFreePodman.sh start
# The script will:
# 1. Check for and start Podman if needed
# 2. Create and start the Oracle container
# 3. Wait for the database to initialize
# 4. Install additional utilities
```

### Setting Up ORDS and MongoDB API

```bash
# Using menu options:
./orclFreePodman.sh
# Select 14 to set up ORDS
# Select 15 to serve ORDS
# Select 16 to check MongoDB API connection
```

## Troubleshooting

### Container Not Starting
- Ensure Docker/Podman is installed and running
- Check for sufficient memory and disk space
- Use option 8 in Podman script to clean unused volumes

### Database Connection Issues
- Wait for the container to fully initialize (can take several minutes)
- Verify the container is running with `docker ps` or `podman ps`
- Check for port conflicts with other services

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Created by Matt D
- Oracle Database Free images provided by Oracle

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.