# Postfix Gmail SMTP Setup on Ubuntu/Debian

## 1. Install Required Packages
```bash
sudo apt update -y
sudo apt install postfix -y
sudo apt install mailutils -y

2. Enable and Start Postfix
sudo systemctl enable postfix
sudo systemctl start postfix

3. Configure Postfix

Edit the main configuration file:
sudo nano /etc/postfix/main.cf

Add or update the following settings:
relayhost = [smtp.gmail.com]:587
smtp_sasl_auth_enable = yes
smtp_sasl_security_options = noanonymous
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_tls_security_level = encrypt
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
inet_protocols = ipv4

Note: Ensure there is only one definition for each setting.

4. Create User Credentials
sudo nano /etc/postfix/sasl_passwd

Add the following line (replace with your details):
[smtp.gmail.com]:587 your_email@gmail.com:your_app_password

Set permissions and generate the hash:
sudo chmod 600 /etc/postfix/sasl_passwd
sudo postmap /etc/postfix/sasl_passwd
sudo systemctl restart postfix
sudo systemctl status postfix

5. Setup Database File
sudo postmap /etc/postfix/sasl_passwd
ls -l /etc/postfix/sasl_passwd*
sudo chmod 600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db
sudo systemctl restart postfix

6. Send a Test Mail
echo "This is a test email from Postfix on Ubuntu" | mail -s "Test Email" recipient@example.com

7. To check Logs
sudo tail -f /var/log/mail.log
