# DLUQuickstart
Automates *most* parts of the DLU (Darkflame LEGO Universe) dedicated server installation.

# Disclaimer

This is intended to make it much **easier** for someone **with some prior unix command line experience** to set up their own DLU server for themselves and their friends. I would not necessarily recommend this as a plug-and-play solution to a nontechnical audience. 

If you want to google esoteric problems and learn and problem solve and have the time to waste doing it? Awesome, I hope this helps you in your journey. This repository is built for debian-derived linux distributions such as Ubuntu, and as such relies on `apt` as a package manager. I've tried to keep it comprehensible enough to read, so if you want you use it as a living reference for your own scripts or troubleshooting your own manual installation, keep that perspective in mind. This repository is also tailored towards running a server in the long term on a dedicated system, hence the Nexus Dashboard installation through an Apache2 proxy that tries to configure with https on a domain.

If you just want to play the game and aren't very tech-savvy, just find someone who already has something hosted, or find a friend who *is* tech-savvy in terms of prior knowledge or the willingness to learn the things to host a server such as this.

In the event where things aren't explained here, check DarkflameServer's readme, it may elaborate on the subject, and be advised that any upstream changes may cause unexpected behavior.

## Table of Contents:

 - Step 1: Provisioning Infrastructure
 - Step 2: Installing Darkflame Universe & Dependencies
 - Step 3: Acquiring & Extracting Client
 - Step 4: Linking Client Files To Server
 - Step 5: Server Configuration
 - Step 6: Operations/Production

## Step 1: Provisioning Infrastructure

I may update this for a more detailed guide later, but the quick answer is: use AWS or GCP. GCP is easier to learn and work with than AWS if you have no cloud experience, although nowadays I mostly deploy via AWS. The point is, do something disposable in the cloud, please be careful when you're, but also be mindful that cloud services cost money and you when to destroy your infrastructure. **This is not a tutorial on using cloud services properly.**

If you intend to run your server on a domain, make sure you point that domain to the IP address of your server infrastructure before running the installation scripts (DNS setup is required for the ```--install-proxy``` subcommand)

### Recommendations

#### Hardware Specs

On AWS, a t3.Medium instance is recommended for it's 4GB of RAM. 20gb of storage gives you some wiggle room.

#### Networking

Ensure that inbound traffic from ports 80, 443, 1001, 2005, and 3000-3300 is allowed. These are for the Nexus Dashboard Website and it's HTTPS proxy, the authentication server, chat server, and any world servers. By default, port 22 will be necessary to have open by default in order to SSH into your server for management, but it is recommended to limit access to port 22 to your IP address as a best practice. 

### AWS Tutorial

Coming soon:tm: (Maybe)

1. Set up a VPC
2. Set up EC2 instance
3. Elastic IP Address
4. Configure security group
5. Long-Term Recommendations

### GCP Tutorial

Coming soon:tm: (Maybe)

## Step 2: Clone Repo To Infrastructure

So, you have some linux server up and running that you have access to. Great. Here is how you start: clone this repository on said server. This has the requisite folder structure that you need for the following step.

```bash
git clone https://github.com/maxdelayer/DLUQuickstart
```

## Step 3: Install Server

All server configuration and management has been consolidated into a single script, `servermanager.sh`. To install your server, you run:

```bash
sudo ./servermanager.sh --install
```

## Step 4: Server Configuration

*If* you already are migrating a pre-existing server's database to a new DLUQuickstart installation, now is the time to import your backed up database file:

```bash
sudo mysql DLU < filename.sql
```

Either way, you will need to configure your database. It will prompt you to set up a password for the database, as well as create an admin user account if you wish to. If you migrated an existing database, you do not need to create a new admin account. If you are creating the database for the first time, an admin account is necessary.

```bash
./servermanager --configure-database
```

In order to run Nexus Dashboard, you must run servermanager one more time. This will prompt you for your domain that the server will be running on. It is highly recommended to register and configure a domain to enable HTTPS and prevent users from needing to edit their `boot.cfg` file in the event your server's IP address changes.

```bash
./servermanager --install-proxy
```

## Step 5: Operations/Production

Now you've edited the file you need, you can begin to run things and follow DLU's documentation a bit more closely.

- Use `servermanager.sh` to run your server:
  - Run/restart the server: `./servermanager.sh -r`
  - Turn off the server: `./servermanager.sh -k`
  - Recompile and restart the server with the latest updates: `./servermanager.sh -R`
    - Consider using servermanager.sh as a cron job for scheduled server reboots
  - Run/Restart Nexus Dashboard: `./servermanager.sh -d`
  - Turn off Nexus Dashboard: `./servermanager.sh -dk`
- Go to your domain in a web browser to access Nexus Dashboard
  - Log in with that admin account to generate keys
    - Tip: Making one key with an absurd number of uses will reduce the amount of times you need to generate keys, if you are opening up your server to the public.
  - Direct players to that website to create their accounts

# Good luck!
