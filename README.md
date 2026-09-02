Here's a clean README.md for your GitHub repo:

---

📄 README.md

```markdown
# Termux WordPress Setup Script

One-click WordPress setup for Termux on Android. No manual configuration needed.

## Quick Install

Run this command in Termux:
```

```bash
curl -L https://raw.githubusercontent.com/Mintedshrimp/Wordpress-Setup-script/refs/heads/main/wordpress.sh -o wordpress.sh && bash wordpress.sh
```

That's it! The script will:

· ✅ Request storage permissions
· ✅ Acquire wake lock (prevents Termux from being killed)
· ✅ Install required packages (PHP, MariaDB, etc.)
· ✅ Download WordPress
· ✅ Set up MariaDB database
· ✅ Create wp-config.php
· ✅ Start the PHP built-in server
· ✅ Create start/stop scripts

---

What You Get

After the script finishes, you'll have:

Service Status
WordPress Installed at $PREFIX/share/nginx/html/wordpress
Database wordpress (user: wpuser, pass: password)
Server PHP built-in server running on http://127.0.0.1:8080

---

How to Use WordPress

1. Open your browser and go to:
   ```
   http://127.0.0.1:8080/wp-admin/install.php
   ```
2. Complete WordPress installation with these database details:
   Field Value
   Database Name wordpress
   Username wpuser
   Password password
   Database Host 127.0.0.1
   Table Prefix wp_
3. Log in to wp-admin
4. Upload your theme:
   · Go to Appearance → Themes
   · Click Add New → Upload Theme
   · Upload your theme ZIP file
   · Click Activate

---

Managing Services

Start Services

```bash
bash ~/start-all.sh
```

Stop Services

```bash
bash ~/stop-all.sh
```

Check Services

```bash
ps aux | grep -E "mariadbd|php -S"
```

---

Troubleshooting

WordPress shows "Error establishing a database connection"

```bash
# Check if MariaDB is running
ps aux | grep mariadbd

# Restart MariaDB
pkill -9 -f mariadbd
sleep 2
mariadbd --datadir="$PREFIX/var/lib/mysql" --socket="$PREFIX/var/run/mysqld/mysqld.sock" &
sleep 5
```

Port 8080 already in use

The script automatically switches to port 8081. Visit:

```
http://127.0.0.1:8081/
```

Services stop when Termux closes

Make sure you have the wake lock:

```bash
termux-wake-lock
```

PHP errors

The script uses -d opcache.enable=0 to prevent permission issues.

---

Requirements

· Termux (from F-Droid - recommended)
· Android 7+
· 1GB+ RAM recommended
· Storage permission (requested automatically)

---

Files Created

File Purpose
~/start-all.sh Starts all services
~/stop-all.sh Stops all services
$PREFIX/share/nginx/html/wordpress WordPress installation
$PREFIX/var/lib/mysql MariaDB data

---

License

MIT License

---

Support

· Issues: Open an issue on GitHub
· Questions: Join the Termux community on Reddit or Discord

---

Disclaimer

This script is for development and testing purposes only. It uses the PHP built-in server, which is not suitable for production. For production, use a proper web server setup.

---

Credits

Built for the Termux community. Contributions welcome!

```

---

### 📁 GitHub Repo Structure

```

Wordpress-Setup-script/
├── wordpress.sh          # Main setup script
├── README.md             # This documentation
└── LICENSE               # MIT License

```

---

### 🚀 How to Publish

1. **Create GitHub repo**: `Wordpress-Setup-script`
2. **Upload files**: `wordpress.sh`, `README.md`, `LICENSE`
3. **Make sure `wordpress.sh` is executable**:
   ```bash
   chmod +x wordpress.sh
```

---

✅ Final Check

The installation command in your README is:

```bash
curl -L https://raw.githubusercontent.com/Mintedshrimp/Wordpress-Setup-script/refs/heads/main/wordpress.sh -o wordpress.sh && bash wordpress.sh
```

This will:

1. Download wordpress.sh from your GitHub repo
2. Run it with bash
