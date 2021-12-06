# DLUQuickstart
Various jank resources slapped together in <24hrs to make running your own Darkflame Universe server easier. Automates *some* parts of the DLU dedicated server installation.

I'm writing this pretty late and on short notice so forgive any mistakes as I'm sure there are many.

# Disclaimer

This is intended to make it much **easier** for someone **with some prior unix command line experience** to set up their own DLU server for themselves and their friends. I would not necessarily recommend this as a plug-and-play solution to a nontechnical audience. 

If you want to google esoteric problems and learn and problem solve and have the time to waste doing it? Awesome, I hope this helps you in your journey. If you just want to play the game and aren't very tech-savvy, just find someone who already has something hosted, or find a friend who *is* tech-savvy in terms of prior knowledge or the willingness to learn the things to host a server such as this.

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

## Step 2: Installing Darkflame Universe & Dependencies

So, you have some linux server up and running that you have access to. Great. Here is how you start

- Clone this repository on said server.

```bash
git clone https://github.com/maxdelayer/DLUQuickstart
```

- **Edit the `DLUQSREPO` variable at the top of `install_dependencies.sh` and `hook_client.sh`**
  - Change to be the FULL PATH to where this repository is installed
  - This variable is used for more reliable paths
  - This should be the only thing you need to edit in this script
- **Run `install_dependencies.sh`**
  - What does this do for you?
  - 1. Clones DLU's DarkflameServer Repository
  - 2. Installs necessary tools via apt
  - 3. Compiles DLU with DLU's `build.sh` script
  - 4. Creates a MySQL Database
  - 5. Inserts the necessary files for said database
  - 6. Clones the DLU AccountManager repository
  - 7. Installs AccountManager's python dependencies
  - 8. Links the `credentials.py` and `resources.py` of this repository to AccountManager
  - 9. Clones lcdr's utils repo, used for linking the client later

## Step 3: Acquire & Extract client

There are several useful resources for finding a Lego Universe client out in the community. The thing that matters here is that **your life (and the life of your users!) will be much easier if all of you use an 'unpacked' client**. This means that assets are extracted in a way that is necessary for your server to run and for users to modify their client to not fall victim to a game breaking bug in the 2nd level. More on that later.

If your client is stored as a .rar, such as, say, one with the SHA256 hash of `0d862f71eedcadc4494c4358261669721b40b2131101cbd6ef476c5a6ec6775b`, then you'll probably want to extract it with `unrar`

Move your ???.rar into the `client` folder of this repository and then uncompress by running
```bash
unrar x filename.rar
```
with `filename.rar` being the name of your rar file. This should extract the contents of the .rar while keeping their folder structure.

**Double check that there is a `res/` folder immediately inside of the `client` folder of this repository. If this is the case you're doing great.**

## Step 4: Linking Client Files To Server

Next, you need to link the files of that client to where the freshly built DLU server keeps it's resources.

- Run `hook_client.sh`
  - This symbolically links files the server needs from where the client is in this repository, presuming you've followed prior instructions correctly.
  - It also uses the `fdb_to_sqlite.py` tool in the utils repo to convert one of these files to a different type that is subsequently patched with various SQL files from DLU

**When you're done with this phase, you should be able to see many files in** `DarkflameServer/build/res/`

## Step 5: Server Configuration

Now you need to actually configure the server in the way that you want. This part has some automation but also lots of manual work.

- **Edit** `createcreds.sh` **and change the password to something that isn't the default**
  - Please... don't forget to do this.
- Run `createcreds.sh`
  - Instead of having you edit the same information for every server config file, this script does it all for you, as well as adds the database user to MySQL and to `config/credentials.py`
- **Edit the "SECRET_KEY" value in `config/credentials.py` according to the instructions within**
  - Look, that's what they said to do, and it seems like a pretty good idea.
- **Edit `DarkflameServer/build/masterconfig.ini` manually**
  - Change the `external_ip` value to the ip address of your server

## Step 6: Operations/Production

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
- Run your server
```
sudo ./MasterServer
```
you can also add a & to make it run in the background (if you want to disconnect your session but keep the server running
```
sudo ./MasterServer &
```
