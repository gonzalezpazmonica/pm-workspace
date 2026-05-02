#!/bin/bash
# SaviaClaw daily backup — zips local memory and emails to saviaclaw@gmail.com
# Scheduled: daily at 22:30 via systemd timer
set -uo pipefail

BACKUP_DIR="/tmp/savia-backups"
TIMESTAMP=$(date +%Y%m%d-%H%M)
ZIPFILE="$BACKUP_DIR/savia-memory-$TIMESTAMP.zip"
LOG="$HOME/.savia/zeroclaw/backup.log"

mkdir -p "$BACKUP_DIR"

echo "[$(date)] Starting backup..." >> "$LOG"

# Critical files only — not caches, not models, not logs
zip -r -q -1 "$ZIPFILE" \
  "$HOME/.savia/nextcloud-config" \
  "$HOME/.savia/deepseek-api-key" \
  "$HOME/.savia/mail-accounts.json" \
  "$HOME/.savia/google-config" \
  "$HOME/.savia/confidentiality-key" \
  "$HOME/.savia/preferences.yaml" \
  "$HOME/.savia/zeroclaw" \
  "$HOME/.savia/sovereignty-provider" \
  "$HOME/.savia/nidos" \
  "$HOME/.savia-memory" \
  "$HOME/.config/opencode/opencode.json" \
  -x "*.log" "*.pid" "*.db" "*.png" "*/tmp/*" "*/cache/*" 2>>"$LOG"

SIZE=$(du -h "$ZIPFILE" | cut -f1)
echo "[$(date)] Zip created: $ZIPFILE ($SIZE)" >> "$LOG"

python3 -c "
import smtplib, ssl, os, json
from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase
from email import encoders

cfg = os.path.expanduser('~/.savia/mail-accounts.json')
with open(cfg) as f:
    mail = json.load(f)
gmail = mail.get('saviaclaw', {})

msg = MIMEMultipart()
msg['From'] = gmail.get('user', 'saviaclaw@gmail.com')
msg['To'] = 'saviaclaw@gmail.com'
msg['Subject'] = f'SaviaClaw Backup $TIMESTAMP ($SIZE)'
part = MIMEBase('application', 'zip')
with open('$ZIPFILE', 'rb') as f:
    part.set_payload(f.read())
encoders.encode_base64(part)
part.add_header('Content-Disposition', 'attachment', filename=f'savia-memory-$TIMESTAMP.zip')
msg.attach(part)

ctx = ssl.create_default_context()
with smtplib.SMTP_SSL('smtp.gmail.com', 465, context=ctx) as s:
    s.login(gmail['user'], gmail['pass'])
    s.send_message(msg)
print('Email sent')
" >>"$LOG" 2>&1

echo "[$(date)] Done" >> "$LOG"
ls -t "$BACKUP_DIR"/*.zip 2>/dev/null | tail -n +8 | xargs -r rm
