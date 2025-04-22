Here's how to rollout a new Vaultwarden instance for a client. This documentation makes a few assumptions:

- This will be running in Docker on a host machine already setup with Docker, Traefik, etc.
- You have set the subdomain DNS in our Cloudflare account: client.vault.daileycomputer.com

1. Copy compose.yaml and .env to the host machine in the appropriate folder. Our standard location is:
    /opt/docker/vaultwarden/<client>

2. Update the .env file with the appropriate information:
        a. CLIENT=<client> - This should be the client-specific part of the URL for this intance of Vaultwarden. For instance, setting this to dcci would expect the URL dcci.vault.daileycomputer.com - this should also match /opt/docker/vaultwarden/<client>
        b. SMTP_PASS - This is the password for noreply@daileycomputer.com hosted with MXRoute. You shouldn't have to change it. Double check the password if needed, or change it if you are using a diffeent SMTP account.
        c. ADMIN_TOKEN - See instructions below

3. In the compose.yaml, make sure SIGNUPS_ALLOWED=true so you can create our admin account. You'll turn this off before we're done.

4. Run docker compose up -d

5. It takes a few minutes for the container to come online. Once it does, browse to the URL and create our admin user. Use support@daileycomputer.com and MAKE SURE to document the info in IT Glue. Setup MFA, click the link in the confirmation email.

6. Once the admin user exists and is documented, take down the container - docker compose down - update SIGNUPS_ALLOWED=false and start the conatainer back up - docker compose up -daileycomputer.com

ADMIN_TOKEN:
Generate a 36+ character password without special characters because some of them break things. Run one of the commands below and enter the password when prompted. You'll get 2 versions of the resulting hash; the standard version, and one that uses 2 $s in place of one which you need for your compose file. The system requires argon2

bash:
read -sp "Password: " PW && echo && HASH=$(echo -n "$PW" | argon2 somesalt -id -t 2 -m 16 -p 1) && echo -e "🔐 Argon2 Hash:\n$HASH\n\n🧪 .env Safe:\n${HASH//\$/\$\$}"

Powershell:
$pw = Read-Host -AsSecureString "Password" | ForEach-Object { [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($_)) }; $hash = & argon2.exe $pw -id -t 2 -m 16 -p 1 -e -s somesalt; Write-Host "`n🔐 Argon2 Hash:`n$hash`n`n🧪 .env Safe:`n$($hash -replace '\$', '$$')"
