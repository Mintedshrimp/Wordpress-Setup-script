#!/data/data/com.termux/files/usr/bin/bash

# ============================================
# Termux WordPress Setup - AUTO-FIX EDITION
# Version: 2.0.0
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
    termux-setup-storage 2>&1 | head -1
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
    ok "Wake lock acquired"
}

# ============================================
# Install Packages
# ============================================

install_packages() {
    inf "Installing packages..."
    pkg update -y >/dev/null 2>&1
    pkg install -y nginx php mariadb wget unzip >/dev/null 2>&1
    ok "Packages installed"
}

# ============================================
# Create Directories
# ============================================

create_directories() {
    inf "Creating directories..."
    mkdir -p "$PREFIX/var/run/mysqld" "$PREFIX/var/run" "$PREFIX/share/nginx/html"
    chmod 755 "$PREFIX/var/run/mysqld"
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
# Download WordPress
# ============================================

download_wordpress() {
    inf "Downloading WordPress..."
    cd "$PREFIX/share/nginx/html"
    wget --show-progress https://wordpress.org/latest.zip 2>&1 | tail -3
    unzip -q latest.zip
    rm latest.zip
    ok "WordPress installed"
}

# ============================================
# AUTO-FIX: MariaDB (Clear Cache, Fix Corruption, Restart)
# ============================================

fix_mariadb() {
    inf "Checking MariaDB health..."
    
    # Step 1: Kill any stuck processes
    pkill -9 -f mariadbd 2>/dev/null
    pkill -9 -f mysqld 2>/dev/null
    sleep 2
    
    # Step 2: Clear corrupt cache files
    if [ -f "$PREFIX/var/lib/mysql/aria_log_control" ]; then
        warn "Aria corruption detected. Clearing cache..."
        rm -f "$PREFIX/var/lib/mysql/aria_log_control"
        rm -f "$PREFIX/var/lib/mysql/aria_log.00000001" 2>/dev/null
        rm -f "$PREFIX/var/lib/mysql/aria_log.00000002" 2>/dev/null
        rm -f "$PREFIX/var/lib/mysql/ib_logfile0" 2>/dev/null
        rm -f "$PREFIX/var/lib/mysql/ib_logfile1" 2>/dev/null
        rm -f "$PREFIX/var/lib/mysql/ib_buffer_pool" 2>/dev/null
        rm -f "$PREFIX/var/lib/mysql/ibtmp1" 2>/dev/null
        ok "Cache cleared"
    fi
    
    # Step 3: Check for corrupted tables
    if [ -d "$PREFIX/var/lib/mysql" ]; then
        warn "Checking for corrupted tables..."
        if mariadb -u root -h 127.0.0.1 -e "CHECK TABLE mysql.user;" >/dev/null 2>&1; then
            ok "Tables are healthy"
        else
            warn "Table corruption detected. Reinitializing database..."
            rm -rf "$PREFIX/var/lib/mysql"
            mkdir -p "$PREFIX/var/lib/mysql"
            mariadb-install-db --user=root --auth-root-authentication-method=normal --datadir="$PREFIX/var/lib/mysql" >/dev/null 2>&1
            ok "Database reinitialized"
        fi
    fi
    
    # Step 4: Clean socket
    rm -f "$PREFIX/var/run/mysqld/mysqld.sock" 2>/dev/null
    
    #step 5 Start MariaDB
    inf "Starting MariaDB..."
    mariadbd --datadir="$PREFIX/var/lib/mysql" --socket="$PREFIX/var/run/mysqld/mysqld.sock" &
    
    # Wait loop (up to 15 seconds)
    inf "Waiting for MariaDB to start..."
    for i in $(seq 1 15); do
        sleep 1
        if mariadb -u root -h 127.0.0.1 -e "SELECT 1;" >/dev/null 2>&1; then
            ok "MariaDB running (after ${i}s)"
            return 0
        fi
    done
    
    # If still failing, reinitialize
    warn "MariaDB still failing. Reinitializing..."
    pkill -9 -f mariadbd 2>/dev/null
    sleep 2
    rm -rf "$PREFIX/var/lib/mysql"
    mkdir -p "$PREFIX/var/lib/mysql"
    mariadb-install-db --user=root --auth-root-authentication-method=normal --datadir="$PREFIX/var/lib/mysql" >/dev/null 2>&1
    mariadbd --datadir="$PREFIX/var/lib/mysql" --socket="$PREFIX/var/run/mysqld/mysqld.sock" &
    
    # Wait again (up to 15 seconds)
    inf "Waiting for MariaDB to start (attempt 2)..."
    for i in $(seq 1 15); do
        sleep 1
        if mariadb -u root -h 127.0.0.1 -e "SELECT 1;" >/dev/null 2>&1; then
            ok "MariaDB recovered (after ${i}s)"
            return 0
        fi
    done
    
    err "Unable to start MariaDB"
}

# ============================================
# Create Database
# ============================================

create_database() {
    inf "Creating database..."
    mariadb -u root -h 127.0.0.1 << SQL >/dev/null 2>&1
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
SQL
    ok "Database ready"
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
# AUTO-FIX: PHP Server (Clear Cache, Restart)
# ============================================

fix_php_server() {
    inf "Checking PHP server health..."
    
    # Step 1: Kill any stuck processes
    pkill -9 -f "php -S" 2>/dev/null
    pkill -9 -f "php -d opcache" 2>/dev/null
    sleep 2
    
    # Step 2: Clear PHP cache
    rm -f /tmp/php-fpm.pid 2>/dev/null
    rm -f /tmp/php-fpm.log 2>/dev/null
    rm -f "$PREFIX/var/run/php-fpm.pid" 2>/dev/null
    
    # Step 3: Check port
    PORT=8080
    if ss -tlnp | grep -q ":8080"; then
        warn "Port 8080 is busy. Using 8081 instead..."
        PORT=8081
    fi
    
    # Step 4: Start PHP server with OPcache disabled
    inf "Starting PHP server on port $PORT..."
    php -d opcache.enable=0 -d opcache.enable_cli=0 -S 127.0.0.1:$PORT -t $WP_DIR >/dev/null 2>&1 &
    sleep 3
    
    # Step 5: Verify
    if curl -s http://127.0.0.1:$PORT/ >/dev/null 2>&1; then
        ok "PHP server running on port $PORT"
        SERVER_PORT=$PORT
    else
        err "PHP server failed"
    fi
}

# ============================================
# Create Start/Stop Scripts
# ============================================

create_scripts() {
    inf "Creating start/stop scripts..."
    
    # Start script with auto-fix
    cat > "$HOME/start-all.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
termux-wake-lock 2>/dev/null

# Auto-fix MariaDB
pkill -9 -f mariadbd 2>/dev/null
sleep 2
rm -f "$PREFIX/var/run/mysqld/mysqld.sock" 2>/dev/null
rm -f "$PREFIX/var/lib/mysql/aria_log_control" 2>/dev/null
mariadbd --datadir="$PREFIX/var/lib/mysql" --socket="$PREFIX/var/run/mysqld/mysqld.sock" &
sleep 5

# Auto-fix PHP server
pkill -9 -f "php -S" 2>/dev/null
sleep 2
php -d opcache.enable=0 -d opcache.enable_cli=0 -S 127.0.0.1:8080 -t "$PREFIX/share/nginx/html/wordpress" &
sleep 3

echo "All services started"
echo "Visit: http://127.0.0.1:8080/"
EOF
    chmod +x "$HOME/start-all.sh"
    
    # Stop script
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
# Main Setup
# ============================================

clear
echo ""
echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e "${C}  Termux WordPress Setup${N}"
echo -e "${C}  Version: 2.0.0${N}"
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

fix_mariadb
create_database
create_wp_config
fix_php_server
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