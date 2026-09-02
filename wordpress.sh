#!/data/data/com.termux/files/usr/bin/bash

# ============================================
# Termux WordPress Setup - VERBOSE
# Version: 1.1.0
# ============================================

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'; N='\033[0m'

WP_DIR="$PREFIX/share/nginx/html/wordpress"
DB_NAME="wordpress"
DB_USER="wpuser"
DB_PASS="password"

ok() { echo -e "${G}[✓]${N} $1"; }
err() { echo -e "${R}[✗]${N} $1"; exit 1; }
inf() { echo -e "${Y}[→]${N} $1"; }
warn() { echo -e "${R}[!]${N} $1"; }

# ============================================
# Setup Storage Permission
# ============================================

setup_storage() {
    inf "Setting up storage permissions..."
    termux-setup-storage 2>&1
    sleep 2
    
    if [ -d "$HOME/storage/shared" ]; then
        ok "Storage permission granted"
    else
        warn "Storage permission not granted. Some features may not work."
    fi
}

# ============================================
# Acquire Wake Lock
# ============================================

acquire_wakelock() {
    inf "Acquiring wake lock..."
    termux-wake-lock 2>&1
    if [ $? -eq 0 ]; then
        ok "Wake lock acquired"
    else
        warn "Could not acquire wake lock"
    fi
}

# ============================================
# Install Packages (Verbose)
# ============================================

install_packages() {
    inf "Installing packages..."
    echo ""
    echo -e "${C}Running: pkg update -y${N}"
    pkg update -y 2>&1 | tail -5
    echo ""
    echo -e "${C}Running: pkg upgrade -y${N}"
    pkg upgrade -y 2>&1 | tail -5
    echo ""
    echo -e "${C}Running: pkg install -y nginx php mariadb wget unzip${N}"
    pkg install -y nginx php mariadb wget unzip 2>&1 | tail -10
    ok "Packages installed"
}

# ============================================
# Create Directories
# ============================================

create_directories() {
    inf "Creating directories..."
    mkdir -p "$PREFIX/var/run/mysqld" "$PREFIX/var/run" "$PREFIX/share/nginx/html"
    ok "Directories created"
}

# ============================================
# Check WordPress
# ============================================

check_wordpress() {
    inf "Checking WordPress installation..."
    if [ -d "$WP_DIR" ]; then
        ok "WordPress already installed"
        WORDPRESS_INSTALLED=true
    else
        warn "WordPress not found. Will download."
        WORDPRESS_INSTALLED=false
    fi
}

# ============================================
# Download WordPress (Verbose)
# ============================================

download_wordpress() {
    inf "Downloading WordPress..."
    echo ""
    echo -e "${C}Running: wget https://wordpress.org/latest.zip${N}"
    cd "$PREFIX/share/nginx/html"
    
    # Show download progress
    wget --show-progress https://wordpress.org/latest.zip 2>&1
    
    echo ""
    echo -e "${C}Running: unzip latest.zip${N}"
    unzip -q latest.zip 2>&1
    rm latest.zip
    ok "WordPress installed"
}

# ============================================
# Start MariaDB (Verbose)
# ============================================

start_mariadb() {
    inf "Starting MariaDB..."
    
    # Kill any existing MariaDB
    pkill -9 -f mariadbd 2>/dev/null
    sleep 2
    
    # Create socket directory
    mkdir -p "$PREFIX/var/run/mysqld"
    chmod 755 "$PREFIX/var/run/mysqld"
    
    # Try starting MariaDB
    echo -e "${C}Running: mariadbd --datadir=$PREFIX/var/lib/mysql${N}"
    mariadbd --datadir="$PREFIX/var/lib/mysql" --socket="$PREFIX/var/run/mysqld/mysqld.sock" &
    sleep 5
    
    # If corrupted, reinitialize
    if ! mariadb -u root -h 127.0.0.1 -e "SELECT 1;" >/dev/null 2>&1; then
        warn "MariaDB corrupted. Reinitializing..."
        pkill -9 -f mariadbd 2>/dev/null
        sleep 2
        rm -rf "$PREFIX/var/lib/mysql"
        mkdir -p "$PREFIX/var/lib/mysql"
        echo -e "${C}Running: mariadb-install-db${N}"
        mariadb-install-db --user=root --auth-root-authentication-method=normal --datadir="$PREFIX/var/lib/mysql" 2>&1 | tail -5
        mariadbd --datadir="$PREFIX/var/lib/mysql" --socket="$PREFIX/var/run/mysqld/mysqld.sock" &
        sleep 5
    fi
    
    # Final check
    if mariadb -u root -h 127.0.0.1 -e "SELECT 1;" >/dev/null 2>&1; then
        ok "MariaDB running"
    else
        err "Unable to start MariaDB"
    fi
}

# ============================================
# Create Database (Verbose)
# ============================================

create_database() {
    inf "Creating database..."
    echo ""
    echo -e "${C}Creating database: wordpress${N}"
    echo -e "${C}Creating user: wpuser@localhost${N}"
    echo -e "${C}Granting privileges...${N}"
    
    mariadb -u root -h 127.0.0.1 << SQL
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
SQL
    ok "Database ready"
}

# ============================================
# Start PHP Server (Verbose)
# ============================================

start_php_server() {
    inf "Starting PHP server..."
    
    # Kill any existing PHP servers
    pkill -9 -f "php -S" 2>/dev/null
    pkill -9 -f "php -d opcache" 2>/dev/null
    sleep 3
    
    # Check if port 8080 is free
    PORT=8080
    if ss -tlnp | grep -q ":8080"; then
        warn "Port 8080 is busy. Using 8081 instead..."
        PORT=8081
    fi
    
    # Start PHP server with OPcache disabled
    echo -e "${C}Running: php -d opcache.enable=0 -S 127.0.0.1:$PORT -t $WP_DIR${N}"
    php -d opcache.enable=0 -d opcache.enable_cli=0 -S 127.0.0.1:$PORT -t $WP_DIR >/dev/null 2>&1 &
    sleep 3
    
    # Verify
    if curl -s http://127.0.0.1:$PORT/ >/dev/null 2>&1; then
        ok "PHP server running on port $PORT"
        SERVER_PORT=$PORT
    else
        err "PHP server failed"
    fi
}

# ============================================
# Create wp-config.php
# ============================================

create_wp_config() {
    inf "Creating wp-config.php..."
    
    if [ ! -f "$WP_DIR/wp-config.php" ]; then
        cp "$WP_DIR/wp-config-sample.php" "$WP_DIR/wp-config.php"
        sed -i "s/database_name_here/$DB_NAME/" "$WP_DIR/wp-config.php"
        sed -i "s/username_here/$DB_USER/" "$WP_DIR/wp-config.php"
        sed -i "s/password_here/$DB_PASS/" "$WP_DIR/wp-config.php"
        sed -i "s/localhost/127.0.0.1/" "$WP_DIR/wp-config.php"
        ok "wp-config.php created"
    else
        ok "wp-config.php already exists"
    fi
}

# ============================================
# Create Start/Stop Scripts
# ============================================

create_scripts() {
    inf "Creating start/stop scripts..."
    
    cat > "$HOME/start-all.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
termux-wake-lock 2>/dev/null
pkill -9 -f mariadbd 2>/dev/null; sleep 2
mariadbd --datadir="$PREFIX/var/lib/mysql" --socket="$PREFIX/var/run/mysqld/mysqld.sock" &
sleep 5
pkill -9 -f "php -S" 2>/dev/null; sleep 2
php -d opcache.enable=0 -d opcache.enable_cli=0 -S 127.0.0.1:8080 -t "$PREFIX/share/nginx/html/wordpress" &
sleep 3
echo "All services started"
echo "Visit: http://127.0.0.1:8080/"
EOF
    chmod +x "$HOME/start-all.sh"
    
    cat > "$HOME/stop-all.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
pkill -9 -f mariadbd 2>/dev/null
pkill -9 -f "php -S" 2>/dev/null
echo "All services stopped"
EOF
    chmod +x "$HOME/stop-all.sh"
    
    ok "Start/stop scripts created"
}

# ============================================
# Test WordPress
# ============================================

test_wordpress() {
    inf "Testing WordPress..."
    echo ""
    if curl -s http://127.0.0.1:$SERVER_PORT/ >/dev/null 2>&1; then
        ok "WordPress accessible"
    else
        warn "WordPress may need manual check"
        warn "Try: http://127.0.0.1:$SERVER_PORT/wp-admin/install.php"
    fi
}

# ============================================
# Main Setup
# ============================================

clear
echo ""
echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e "${C}  Termux WordPress Setup${N}"
echo -e "${C}  Version: 1.1.0${N}"
echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo ""

setup_storage
acquire_wakelock
install_packages
create_directories
check_wordpress

if [ "$WORDPRESS_INSTALLED" = false ]; then
    download_wordpress
fi

start_mariadb
create_database
create_wp_config
start_php_server
test_wordpress
create_scripts

echo ""
echo -e "${G}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e "${G}  Setup Complete!${N}"
echo -e "${G}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo ""
echo -e "  URL: ${C}http://127.0.0.1:$SERVER_PORT/${N}"
echo -e "  Install: ${C}http://127.0.0.1:$SERVER_PORT/wp-admin/install.php${N}"
echo ""
echo -e "  Database: ${C}wordpress${N}"
echo -e "  Username: ${C}wpuser${N}"
echo -e "  Password: ${C}password${N}"
echo ""
echo -e "  To upload theme:"
echo -e "  1. Log in to wp-admin"
echo -e "  2. Go to Appearance → Themes"
echo -e "  3. Click 'Add New' → 'Upload Theme'"
echo -e "  4. Upload your theme ZIP"
echo ""
echo -e "${Y}  Start: ~/start-all.sh${N}"
echo -e "${Y}  Stop: ~/stop-all.sh${N}"
echo ""
