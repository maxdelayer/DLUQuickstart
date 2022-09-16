# DLUQuickstart
Various jank resources slapped together in <24hrs to make running your own Darkflame Universe server easier. Automates *some* parts of the DLU dedicated server installation.

I'm writing this pretty late and on short notice so forgive any mistakes as I'm sure there are many.

# Disclaimer

This is intended to make it much **easier** for someone **with some prior unix command line experience** to set up their own DLU server for themselves and their friends. I would not necessarily recommend this as a plug-and-play solution to a nontechnical audience. 

If you want to google esoteric problems and learn and problem solve and have the time to waste doing it? Awesome, I hope this helps you in your journey. If you just want to play the game and aren't very tech-savvy, just find someone who already has something hosted, or find a friend who *is* tech-savvy in terms of prior knowledge or the willingness to learn the things to host a server such as this.

In the event where things aren't explained here, check DarkflameServer's readme, it may elaborate, or it may just confuse you further.

## Table of Contents:

 - Step 1: Provisioning Infrastructure
 - Step 2: Installing Darkflame Universe & Dependencies
 - Step 3: Acquiring & Extracting Client
 - Step 4: Linking Client Files To Server
 - Step 5: Server Configuration
 - Step 5: Operations/Production

## Step 1: Provisioning Infrastructure

I may update this for a more detailed guide later, but the quick answer is: use AWS or GCP. GCP is easier to learn and work with than AWS if you have no cloud experience, although nowadays I mostly deploy via AWS. The point is, do something disposable in the cloud, please be careful when you're, but also be mindful that cloud services cost money and you when to destroy your infrastructure. **This is not a tutorial on using cloud services properly.**

### Specs

On AWS, a t3.Small instance has worked fine for me thus far, and a t3.micro instance was causing problems. So, whatever you do, probably best to have at least 2GB of RAM. 20gb of storage gives you some wiggle room.

This repository is built for debian-derived linux distributions such as Ubuntu.

### AWS Tutorial

Coming soon:tm: (Maybe)

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

Now you need to actually configure the server in the way that you want. AKA - set your passwords. This part has some automation but also lots of manual work.

- **Edit** `createcreds.sh` **and change the password to something that isn't the default**
  - Please... don't forget to do this.
- Run `createcreds.sh`
  - Instead of having you edit the same information for every server config file, this script does it all for you, as well as adds the database user to MySQL and to `config/credentials.py`
- **Edit the "SECRET_KEY" value in `config/credentials.py` according to the instructions within**
  - Look, that's what they said to do, and it seems like a pretty good idea.
- **Edit `DarkflameServer/build/masterconfig.ini` manually**
  - Change the `external_ip` value to the ip address of your server

## Step 5: Operations/Production

Now you've edited the file you need, you can begin to run things and follow DLU's documentation a bit more closely.

- Generate an admin account
```bash
# From within DarkflameServer/build/
sudo ./MasterServer -a
```
- Run the AccountManager webserver
```bash
# From within AccountManager/
python3 app.py
```
- Go to your server's IP address, port 5000 in your web browser (https://127.0.0.1:5000)
  - Log in with that admin account and generate keys
  - Direct players to that website's `/activate` page to use those keys to create an account
- Use `servermanager.sh` to run your server:
  - Run the server: `./servermanager.sh -r`
  - Turn off the server: `./servermanager.sh -k`
  - Recompile and restart the server with the latest updates: `./servermanager.sh -R`
  - Consider using servermanager.sh as a cron job for scheduled server reboots

# Good luck!
