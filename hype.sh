#!/bin/bash

# Color output functions
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
YELLOW='\033[1;33m'

print_header() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        HyperSpace Node Manager         ║${NC}"
    echo -e "${BLUE}║        Telegram: @nodetrip             ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
}

create_key_file() {
    echo -e "${GREEN}Inserting private key${NC}"
    echo -e "${BLUE}Please enter your private key (without spaces or line breaks):${NC}"
    read -r private_key
    
    if [ -z "$private_key" ]; then
        echo -e "${RED}Error: Private key cannot be empty${NC}"
        return 1
    fi
    
    # Save key to file
    echo "$private_key" > hyperspace.pem
    chmod 644 hyperspace.pem
    
    echo -e "${GREEN}✅ Private key successfully saved to hyperspace.pem${NC}"
    return 0
}

install_node() {
    echo -e "${GREEN}Updating system...${NC}"
    sudo apt update && sudo apt upgrade -y
    cd $HOME
    rm -rf $HOME/.cache/hyperspace/models/*
    sleep 5

    echo -e "${GREEN}🚀 Installing HyperSpace CLI...${NC}"
    while true; do
        curl -s https://download.hyper.space/api/install | bash | tee /root/hyperspace_install.log

        if ! grep -q "Failed to parse version from release data." /root/hyperspace_install.log; then
            echo -e "${GREEN}✅ HyperSpace CLI installed successfully!${NC}"
            break
        else
            echo -e "${RED}❌ Installation failed. Retrying in 5 seconds...${NC}"
            sleep 5
        fi
    done

    echo -e "${GREEN}🚀 Installing AIOS...${NC}"
    echo 'export PATH=$PATH:$HOME/.aios' >> ~/.bashrc
    export PATH=$PATH:$HOME/.aios
    source ~/.bashrc

    screen -S hyperspace -dm
    screen -S hyperspace -p 0 -X stuff $'aios-cli start\n'
    sleep 5

    echo -e "${GREEN}Creating private key file...${NC}"
    echo -e "${YELLOW}Nano editor will open. Paste your private key and save the file (CTRL+X, Y, Enter)${NC}"
    sleep 2
    nano hyperspace.pem

    # Create key backup
    if [ -f "$HOME/hyperspace.pem" ]; then
        echo -e "${GREEN}Creating key backup...${NC}"
        cp $HOME/hyperspace.pem $HOME/hyperspace.pem.backup
        chmod 644 $HOME/hyperspace.pem.backup
    fi

    aios-cli hive import-keys ./hyperspace.pem

    echo -e "${GREEN}🔑 Logging in...${NC}"
    aios-cli hive login
    sleep 5

    echo -e "${GREEN}Loading model...${NC}"
    aios-cli models add hf:second-state/Qwen1.5-1.8B-Chat-GGUF:Qwen1.5-1.8B-Chat-Q4_K_M.gguf

    echo -e "${GREEN}Connecting to system...${NC}"
    aios-cli hive connect
    aios-cli hive select-tier 3

    echo -e "${GREEN}🔍 Checking node status...${NC}"
    aios-cli status

    echo -e "${GREEN}✅ Installation completed!${NC}"
}

check_logs() {
    echo -e "${GREEN}Checking node logs:${NC}"
    screen -r hyperspace
}

check_points() {
    echo -e "${GREEN}Checking points balance:${NC}"
    export PATH=$PATH:$HOME/.aios
    
    if ! pgrep -f "aios-cli" > /dev/null; then
        echo -e "${YELLOW}Daemon not running. Starting...${NC}"
        aios-cli start &
        sleep 5
    fi
    
    # Using the same method as in separate script
    POINTS_OUTPUT=$($HOME/.aios/aios-cli hive points 2>/dev/null)
    if [ ! -z "$POINTS_OUTPUT" ]; then
        CURRENT_POINTS=$(echo "$POINTS_OUTPUT" | grep "Points:" | awk '{print $2}')
        MULTIPLIER=$(echo "$POINTS_OUTPUT" | grep "Multiplier:" | awk '{print $2}')
        TIER=$(echo "$POINTS_OUTPUT" | grep "Tier:" | awk '{print $2}')
        UPTIME=$(echo "$POINTS_OUTPUT" | grep "Uptime:" | awk '{print $2}')
        ALLOCATION=$(echo "$POINTS_OUTPUT" | grep "Allocation:" | awk '{print $2}')
        
        echo -e "${GREEN}✅ Current points: $CURRENT_POINTS${NC}"
        echo -e "${GREEN}✅ Multiplier: $MULTIPLIER${NC}"
        echo -e "${GREEN}✅ Tier: $TIER${NC}"
        echo -e "${GREEN}✅ Uptime: $UPTIME${NC}"
        echo -e "${GREEN}✅ Allocation: $ALLOCATION${NC}"
    else
        echo -e "${RED}❌ Failed to get points value${NC}"
    fi
}

check_status() {
    echo -e "${GREEN}Checking node status:${NC}"
    export PATH=$PATH:$HOME/.aios
    
    if ! pgrep -f "aios-cli" > /dev/null; then
        echo -e "${YELLOW}Daemon not running. Starting...${NC}"
        aios-cli start &
        sleep 5
    fi
    
    aios-cli status
}

remove_node() {
    echo -e "${RED}Removing node...${NC}"
    screen -X -S hyperspace quit
    rm -rf $HOME/.aios
    rm -rf $HOME/.cache/hyperspace
    rm -f hyperspace.pem
    echo -e "${GREEN}Node removed successfully${NC}"
}

restart_node() {
    echo -e "${YELLOW}Restarting node...${NC}"
    
    # Stop processes and delete daemon files
    echo -e "${BLUE}Stopping processes and cleaning temporary files...${NC}"
    lsof -i :50051 | grep LISTEN | awk '{print $2}' | xargs -r kill -9
    rm -rf /tmp/aios*
    rm -rf $HOME/.aios/daemon*
    screen -X -S hyperspace quit
    sleep 5
    
    # Check and restore key file
    if [ ! -f "$HOME/hyperspace.pem" ] && [ -f "$HOME/hyperspace.pem.backup" ]; then
        echo -e "${YELLOW}Main key file not found. Restoring from backup...${NC}"
        cp $HOME/hyperspace.pem.backup $HOME/hyperspace.pem
        chmod 644 $HOME/hyperspace.pem
    fi
    
    # Create new screen session
    echo -e "${BLUE}Creating new screen session...${NC}"
    screen -S hyperspace -dm
    screen -S hyperspace -p 0 -X stuff $'export PATH=$PATH:$HOME/.aios\naios-cli start\n'
    sleep 5
    
    # Authentication and Hive connection
    echo -e "${BLUE}Authenticating to Hive...${NC}"
    export PATH=$PATH:$HOME/.aios
    if [ -f "$HOME/hyperspace.pem" ]; then
        echo -e "${GREEN}Importing key...${NC}"
        aios-cli hive import-keys ./hyperspace.pem
    else
        echo -e "${RED}Key file not found.${NC}"
        echo -e "${YELLOW}Private key required.${NC}"
        echo -e "${YELLOW}Enter your private key (no spaces or line breaks):${NC}"
        read -r private_key
        echo "$private_key" > hyperspace.pem
        chmod 644 hyperspace.pem
        cp $HOME/hyperspace.pem $HOME/hyperspace.pem.backup
        chmod 644 $HOME/hyperspace.pem.backup
        aios-cli hive import-keys ./hyperspace.pem
    fi
    
    echo -e "${BLUE}Logging into Hive...${NC}"
    aios-cli hive login
    sleep 5
    
    echo -e "${BLUE}Connecting to Hive...${NC}"
    aios-cli hive connect
    sleep 5
    
    # Select tier
    echo -e "${BLUE}Selecting tier...${NC}"
    aios-cli hive select-tier 3
    sleep 3
    
    # Check status
    echo -e "${GREEN}Checking node status after restart:${NC}"
    aios-cli status
    
    echo -e "${GREEN}✅ Node restarted!${NC}"
}

setup_restart_cron() {
    echo -e "${YELLOW}Setting up automatic node restart${NC}"
    
    # Check for cron
    if ! command -v crontab &> /dev/null; then
        echo -e "${RED}cron not installed. Installing...${NC}"
        apt-get update && apt-get install -y cron
    fi
    
    # Check cron service
    if ! systemctl is-active --quiet cron; then
        echo -e "${YELLOW}Cron not running. Starting...${NC}"
        systemctl start cron
        systemctl enable cron
    fi
    
    echo -e "${GREEN}Select restart interval:${NC}"
    echo "1) Every 12 hours"
    echo "2) Every 24 hours"
    echo "3) Custom interval"
    echo "4) Disable auto-restart"
    echo "5) Return to main menu"
    
    read -p "Your choice: " cron_choice
    
    # Create restart command
    RESTART_CMD="lsof -i :50051 | grep LISTEN | awk '{print \$2}' | xargs -r kill -9 && rm -rf /tmp/aios* && rm -rf \$HOME/.aios/daemon* && screen -X -S hyperspace quit && sleep 5 && (if [ ! -f \"\$HOME/hyperspace.pem\" ] && [ -f \"\$HOME/hyperspace.pem.backup\" ]; then cp \$HOME/hyperspace.pem.backup \$HOME/hyperspace.pem; fi) && screen -S hyperspace -dm && screen -S hyperspace -p 0 -X stuff 'export PATH=\$PATH:\$HOME/.aios\naios-cli start\n' && sleep 5 && export PATH=\$PATH:\$HOME/.aios && aios-cli hive import-keys ./hyperspace.pem && aios-cli hive login && sleep 5 && aios-cli hive connect && sleep 5 && aios-cli status"
    SCRIPT_PATH="$HOME/hyperspace_restart.sh"
    
    # Create restart script
    echo "#!/bin/bash" > $SCRIPT_PATH
    echo "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/root/.aios" >> $SCRIPT_PATH
    echo "cd $HOME" >> $SCRIPT_PATH
    echo "$RESTART_CMD" >> $SCRIPT_PATH
    chmod +x $SCRIPT_PATH
    
    case $cron_choice in
        1)
            CRON_EXPRESSION="0 0,12 * * *"
            ;;
        2)
            CRON_EXPRESSION="0 0 * * *"
            ;;
        3)
            echo -e "${YELLOW}Enter cron expression (e.g., '0 */6 * * *'):${NC}"
            read -r CRON_EXPRESSION
            ;;
        4)
            crontab -l | grep -v "hyperspace_restart.sh" | crontab -
            echo -e "${GREEN}Auto-restart disabled.${NC}"
            return
            ;;
        5)
            echo -e "${YELLOW}Returning to main menu...${NC}"
            return
            ;;
        *)
            echo -e "${RED}Invalid choice. Using 12-hour default.${NC}"
            CRON_EXPRESSION="0 0,12 * * *"
            ;;
    esac
    
    # Update crontab
    (crontab -l 2>/dev/null | grep -v "hyperspace_restart.sh" ; echo "$CRON_EXPRESSION $SCRIPT_PATH > $HOME/hyperspace_restart.log 2>&1") | crontab -
    
    echo -e "${GREEN}✅ Auto-restart configured!${NC}"
    echo -e "${YELLOW}Schedule: $CRON_EXPRESSION${NC}"
    echo -e "${YELLOW}Script: $SCRIPT_PATH${NC}"
    echo -e "${YELLOW}Log: $HOME/hyperspace_restart.log${NC}"
}

smart_monitor() {
    echo -e "${GREEN}Setting up smart monitoring...${NC}"
    
    # Create monitoring script
    cat > $HOME/points_monitor_hyperspace.sh << 'EOL'
#!/bin/bash
LOG_FILE="$HOME/smart_monitor.log"
SCREEN_NAME="hyperspace"
LAST_POINTS="0"
NAN_COUNT=0
MAX_NAN_RETRIES=3
CHECK_INTERVAL=3600  # Default check interval
FAIL_COUNT=0
MAX_FAIL_RETRIES=2

export PATH="$PATH:$HOME/.aios"

log_message() {
    echo "$(date +"%Y-%m-%d %H:%M:%S"): $1" >> $LOG_FILE
}

restart_node() {
    log_message "Starting node restart..."
    lsof -i :50051 | grep LISTEN | awk '{print $2}' | xargs -r kill -9
    rm -rf /tmp/aios*
    rm -rf $HOME/.aios/daemon*
    screen -X -S hyperspace quit
    sleep 5

    if [ ! -f "$HOME/hyperspace.pem" ] && [ -f "$HOME/hyperspace.pem.backup" ]; then
        cp $HOME/hyperspace.pem.backup $HOME/hyperspace.pem
    fi

    screen -S hyperspace -dm
    screen -S hyperspace -p 0 -X stuff "export PATH=$PATH:$HOME/.aios\naios-cli start\n"
    sleep 10

    export PATH=$PATH:$HOME/.aios
    aios-cli hive import-keys ./hyperspace.pem
    aios-cli hive login
    sleep 10
    aios-cli hive connect
    sleep 5
    aios-cli hive select-tier 3
    sleep 5
    aios-cli status
    
    log_message "Restart completed"
    sleep 60
}

check_node_health() {
    if ! pgrep -f "aios" > /dev/null; then
        log_message "aios process missing"
        return 1
    fi
    
    if ! lsof -i :50051 | grep LISTEN > /dev/null; then
        log_message "Port 50051 not listening"
        return 1
    fi
    
    if ! command -v aios-cli &> /dev/null; then
        log_message "aios-cli missing from PATH"
        return 1
    fi
    
    HIVE_STATUS=$($HOME/.aios/aios-cli hive connect 2>&1)
    if echo "$HIVE_STATUS" | grep -q "error"; then
        log_message "Hive connection error: $HIVE_STATUS"
        return 1
    fi
    
    return 0
}

while true; do
    if ! check_node_health; then
        restart_node
        LAST_POINTS="0"
        NAN_COUNT=0
        FAIL_COUNT=0
        sleep 300
        continue
    fi
    
    POINTS_OUTPUT=$($HOME/.aios/aios-cli hive points 2>&1)
    
    if echo "$POINTS_OUTPUT" | grep -q "Failed to fetch points" || echo "$POINTS_OUTPUT" | grep -q "error"; then
        FAIL_COUNT=$((FAIL_COUNT + 1))
        log_message "Points error: $POINTS_OUTPUT (Attempt $FAIL_COUNT/$MAX_FAIL_RETRIES)"
        
        if [ $FAIL_COUNT -ge $MAX_FAIL_RETRIES ]; then
            log_message "Max errors reached - restarting"
            restart_node
            FAIL_COUNT=0
            NAN_COUNT=0
            LAST_POINTS="0"
        else
            sleep 300
            continue
        fi
    else
        FAIL_COUNT=0
    fi
    
    CURRENT_POINTS=$(echo "$POINTS_OUTPUT" | grep "Points:" | awk '{print $2}')
    
    if [ -z "$CURRENT_POINTS" ]; then
        log_message "No points value - skipping"
        sleep 300
        continue
    fi
    
    log_message "Points check: Current: $CURRENT_POINTS, Previous: $LAST_POINTS"
    
    if [ "$CURRENT_POINTS" = "NaN" ]; then
        NAN_COUNT=$((NAN_COUNT + 1))
        log_message "NaN received ($NAN_COUNT/$MAX_NAN_RETRIES)"
        
        if [ $NAN_COUNT -ge $MAX_NAN_RETRIES ]; then
            log_message "Max NaNs - restarting"
            restart_node
            NAN_COUNT=0
            FAIL_COUNT=0
            LAST_POINTS="0"
        else
            sleep 600
            continue
        fi
    else
        NAN_COUNT=0
    fi
    
    if [ "$CURRENT_POINTS" != "NaN" ] && [ "$LAST_POINTS" != "NaN" ] && [ "$LAST_POINTS" != "0" ]; then
        if [ "$CURRENT_POINTS" = "$LAST_POINTS" ]; then
            log_message "No points change - restarting"
            restart_node
        else
            log_message "Points updated"
        fi
    else
        log_message "Skipping comparison"
    fi
    
    if [ "$CURRENT_POINTS" != "NaN" ]; then
        LAST_POINTS="$CURRENT_POINTS"
    fi
    
    sleep $CHECK_INTERVAL
done
EOL

    chmod +x $HOME/points_monitor_hyperspace.sh
    
    # Stop existing monitoring
    PIDS=$(ps aux | grep "[p]oints_monitor_hyperspace.sh" | awk '{print $2}')
    for PID in $PIDS; do
        kill -9 $PID
    done
    
    # Start new monitoring
    nohup $HOME/points_monitor_hyperspace.sh > $HOME/points_monitor_hyperspace.log 2>&1 &
    
    echo -e "${GREEN}✅ Smart monitoring enabled!${NC}"
    echo -e "${YELLOW}Log: $HOME/smart_monitor.log${NC}"
    echo -e "${YELLOW}Process log: $HOME/points_monitor_hyperspace.log${NC}"
}

stop_monitor() {
    echo -e "${YELLOW}Stopping monitor...${NC}"
    
    PIDS=$(ps aux | grep "[p]oints_monitor_hyperspace.sh" | awk '{print $2}')
    if [ -z "$PIDS" ]; then
        echo -e "${RED}Monitor not found${NC}"
        return
    fi
    
    for PID in $PIDS; do
        kill -9 $PID
    done
    
    echo -e "${GREEN}✅ Monitoring stopped${NC}"
}

check_monitor_status() {
    echo -e "${GREEN}Monitoring status:${NC}"
    
    MONITOR_PID=$(ps aux | grep "[p]oints_monitor_hyperspace.sh" | awk '{print $2}')
    if [ -z "$MONITOR_PID" ]; then
        echo -e "${RED}❌ Monitor inactive${NC}"
    else
        echo -e "${GREEN}✅ Monitor active (PID: $MONITOR_PID)${NC}"
    fi
    
    if [ -f "$HOME/smart_monitor.log" ]; then
        LAST_LOGS=$(tail -n 10 $HOME/smart_monitor.log)
        CURRENT_DATE=$(date +%Y-%m-%d)
        LAST_CHECK=$(echo "$LAST_LOGS" | grep "$CURRENT_DATE" | tail -n 1)
        
        echo -e "\n${YELLOW}Recent logs:${NC}"
        echo "$LAST_LOGS"
        
        if [ ! -z "$LAST_CHECK" ]; then
            echo -e "\n${GREEN}✅ Active logging confirmed${NC}"
        else
            echo -e "\n${RED}❌ No recent logs today${NC}"
            echo -e "${YELLOW}System date: $(date)${NC}"
        fi
    else
        echo -e "${RED}❌ Log file missing${NC}"
    fi
    
    echo -e "\n${YELLOW}Node status:${NC}"
    if pgrep -f "aios" > /dev/null; then
        echo -e "${GREEN}✅ aios running${NC}"
    else
        echo -e "${RED}❌ aios not running${NC}"
    fi
    
    if lsof -i :50051 | grep LISTEN > /dev/null; then
        echo -e "${GREEN}✅ Port 50051 listening${NC}"
    else
        echo -e "${RED}❌ Port 50051 not listening${NC}"
    fi
    
    create_check_script
    echo -e "${YELLOW}Running check script...${NC}"
    $HOME/check_hyperspace.sh
}

create_check_script() {
    cat > $HOME/check_hyperspace.sh << 'EOL'
#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Current time: $(date)${NC}"
echo -e "${YELLOW}PATH: $PATH${NC}"

echo -e "${YELLOW}Running: $HOME/.aios/aios-cli hive points${NC}"
POINTS_OUTPUT=$($HOME/.aios/aios-cli hive points 2>&1)
echo -e "${YELLOW}Command output:${NC}\n$POINTS_OUTPUT"

if echo "$POINTS_OUTPUT" | grep -q "Points:"; then
    CURRENT_POINTS=$(echo "$POINTS_OUTPUT" | grep "Points:" | awk '{print $2}')
    MULTIPLIER=$(echo "$POINTS_OUTPUT" | grep "Multiplier:" | awk '{print $2}')
    TIER=$(echo "$POINTS_OUTPUT" | grep "Tier:" | awk '{print $2}')
    UPTIME=$(echo "$POINTS_OUTPUT" | grep "Uptime:" | awk '{print $2}')
    ALLOCATION=$(echo "$POINTS_OUTPUT" | grep "Allocation:" | awk '{print $2}')
    
    echo -e "${GREEN}✅ Points: $CURRENT_POINTS${NC}"
    echo -e "${GREEN}✅ Multiplier: $MULTIPLIER${NC}"
    echo -e "${GREEN}✅ Tier: $TIER${NC}"
    echo -e "${GREEN}✅ Uptime: $UPTIME${NC}"
    echo -e "${GREEN}✅ Allocation: $ALLOCATION${NC}"
else
    echo -e "${RED}❌ Points check failed${NC}"
    echo -e "${YELLOW}Checking status:${NC}"
    $HOME/.aios/aios-cli status
    echo -e "${YELLOW}Checking Hive connection:${NC}"
    $HOME/.aios/aios-cli hive connect
    echo -e "${YELLOW}Checking Hive login:${NC}"
    $HOME/.aios/aios-cli hive login
fi
EOL
    chmod +x $HOME/check_hyperspace.sh
}

# Main loop
while true; do
    print_header
    echo -e "${GREEN}Select action:${NC}"
    echo "1) Install node"
    echo "2) View logs"
    echo "3) Check points"
    echo "4) Check status"
    echo "5) Remove node"
    echo "6) Restart node"
    echo "7) Enable smart monitor"
    echo "8) Disable smart monitor"
    echo "9) Check monitoring"
    echo "0) Exit"
    
    read -p "Your choice: " choice

    case $choice in
        1) install_node ;;
        2) check_logs ;;
        3) check_points ;;
        4) check_status ;;
        5) remove_node ;;
        6) restart_node ;;
        7) smart_monitor ;;
        8) stop_monitor ;;
        9) check_monitor_status ;;
        0) exit 0 ;;
        *) echo -e "${RED}Invalid choice${NC}" ;;
    esac

    read -p "Press Enter to continue..."
done
