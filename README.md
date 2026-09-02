# Termux WordPress Setup Script

> One-click WordPress setup for Termux on Android.

## 🚀 Quick Install

```bash
curl -L https://raw.githubusercontent.com/Mintedshrimp/Wordpress-Setup-script/refs/heads/main/wordpress.sh -o wordpress.sh && bash wordpress.sh
```

✨ Features

· ✅ Auto-fixes MariaDB corruption
· ✅ Auto-clears cache files
· ✅ Auto-restarts stuck services
· ✅ OPcache disabled (fixes permission issues)
· ✅ Port conflict handling (auto-switches to 8081)
· ✅ Storage permission setup
· ✅ Wake lock acquisition
· ✅ Works on clean installs

📖 How to Use

1. Run the script (see above)
2. Install WordPress: Visit http://127.0.0.1:8080/wp-admin/install.php
3. Log in to wp-admin
4. Upload your theme: Appearance → Themes → Add New → Upload Theme

🛠️ Managing Services

Start Services

```bash
bash ~/start-all.sh
```

Stop Services

```bash
bash ~/stop-all.sh
```

🔧 Troubleshooting

Issue Fix
Port 8080 busy Script auto-switches to 8081
Database connection error Run script again - it auto-fixes
Services stop when Termux closes Run termux-wake-lock

📦 Requirements

· Termux from F-Droid
· Android 7+
· 1GB+ RAM recommended

📄 License

MIT License

👥 Contributing

Pull requests are welcome! For major changes, please open an issue first.

⚠️ Disclaimer

This script is for development and testing purposes only. The PHP built-in server is not suitable for production use.

```

