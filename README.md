# DLUQuickstart
Automates *most* parts of the DLU (Darkflame LEGO Universe) dedicated server installation.

# Disclaimer

This is intended to make it much **easier** for someone **with some prior unix command line experience** to set up their own DLU server for themselves and their friends. I would not necessarily recommend this as a plug-and-play solution to a nontechnical audience.  If you just want to play the game and aren't very tech-savvy, just find someone who already has something hosted, or find a friend who *is* tech-savvy in terms of prior knowledge or the willingness to learn the things to host a server such as this.

This project is built around some core assumptions:
 - You want to run your LEGO Universe server over an extended period of time
 - You will to run your LEGO Universe server on dedicated hardware (ideally via some cloud service provider)
 - You will run your LEGO Universe server on a debian-derived linux distribution (I've tested this on Ubuntu) that has the `apt` package manager installed
 
If you break from any of these assumptions, don't fret, just keep in mind the perspective from which this was written, and potentially you may want to adapt how you run things to better suit your purposes. At it's core, if you are running this on any other configuration of infrastructure, be it hardware or software, you may gain a be able to reverse-engineer an understanding of how to manually perform a similar install.

In the event where things aren't explained here, check [DarkflameServer's readme](https://github.com/DarkflameUniverse/DarkflameServer#readme) because it may elaborate on the subject. In addition, recognize that any upstream changes to the default installation process may cause unexpected behavior. If issues arise you can always reach out to me, and I will reply when I can. If you have suggestions, please make an issue or raise it with me directly.

## Table of Contents:

 - Step 0: What do you want?
 - Step 1: Provisioning Infrastructure
 - Step 2: Cloning this repo to said infrastructure
 - Step 3: Installing Dependencies & Compiling Server
 - Step 4: Generating Configuration Files
 - Step 5: Set up web proxy
 - Step 6: Initialization
 - Step 7: Operations/Production

## Step 0: What do you want?

See the disclaimer above. Do you want to host a server? Do you want to open that up to others? Do you want to manage that risk and pay for the costs, be it hardware, electricity, cloud service fees, or domain hosting costs? **If you just want to play the game, it's a lot easier to find a server someone else is hosting.**

## Step 1: Provisioning Infrastructure

I mostly deploy via AWS, but that's my choice for my specific situation. You can host this on nearly anything. If you choose to create something disposable in the cloud, please be mindful that cloud services cost money over time, and you manage your costs accordingly. **This is not a tutorial on using cloud services most efficiently.**

### Recommendations

#### Hardware Specs

If you are running your game server and web frontend on the same machine as your database, I recommend at least 2 vcpus and 4GB of RAM. If you are separating your database to a different server, you can get away with 2vcpus and 2GB of RAM. On AWS, that would be a t3a.medium for a single instance, or a t3a.small instance for the game server with a RDS-managed db.t3.micro instance for the database. 

Either way, 22gb of storage is the bare minimum I would recommend. I do not believe that paying more for SSD storage is necessary for this use case.

#### Networking

Ensure that inbound traffic from ports 80, 443, 1001, 2005, and 3000-3300 is allowed, and everything else is denied. 

| Ports Open | Reason |
| :---: | :--- |
| 80 | Nexus Dashboard HTTP |
| 443 | Nexus Dashboard HTTPS |
| 1001 | Auth Server |
| 2005 | Chat Server |
| 3000-3300 | World Servers |

By default, port 22 must have open in order to SSH into your server for management, but it is recommended to limit access to port 22 to your IP address as a best practice. 

If you intend to run your server on a domain, make sure you point that domain to the IP address of your server infrastructure before running the installation scripts (DNS setup is *recommended* for the ```configure``` **required** for the ```--install-proxy``` subcommand)

### AWS Tutorial

Coming eventually:tm: (Maybe)

#### Set up a VPC
#### Set up EC2 instance
#### Allocate Elastic IP Address
#### Configure security group
#### Long-Term Recommendations

### GCP Tutorial

Coming eventually:tm: (Maybe)

## Step 2: Clone Repo To Infrastructure

So, you have some linux server up and running that you have access to. Great. Here is how you start: clone this repository on said server. This has the requisite folder structure that you need for the following step.

```bash
git clone https://github.com/maxdelayer/DLUQuickstart
```

For future steps, make sure you are in the directory of the cloned repository:

```bash
cd DLUQuickstart
```

## Step 3: Install Server

All server configuration and management has been consolidated into a single script, `servermanager.sh`. It has four key installation stages which you can run all at once *or* individually. For the sake of explanation I will go over each individually.

The first step is:

```bash
./servermanager.sh --install
```

This will install most prerequesite software and compile the DLU server. This compilation process may take several minutes.

## Step 4: Server Configuration

This step generates the configuration files for both DLU and NexusDashboard. 

```bash
./servermanager.sh --configure
```

It will prompt you for:
 - The password to use on your database
 - Whether or not to create the database locally or connect to a remote database
   - If you are connecting to a remote database, it will ask for the address of that database
 - The domain name of your server for the website configuration. 
   - It will use this DNS name to grab the public IP address of the server, **however you can also set the MasterServer IP manually. **
   - It is highly recommended to register and configure a domain for a multitude of reasons.

If you made a mistake in your configuration such as a mistyped password, or you didn't have your domain pointed to your server before this, then you can re-run this step to reset those configuration files without editing them directly.

**NOTE:** *If* you already are migrating a pre-existing server's database to a new DLUQuickstart installation, this point of the install process is the time to import your backed up database file

## Step 5: Initialization

The next stage of the installation is the longest: initialization. It downloads and extracts other files needed to run the server and sets them up in the right spots. You may need to specify or change this portion of the script later down the line if the link embedded is no longer accurate. At the time of writing, it should work out of the box.

```bash
./servermanager.sh --initialize
```

After setting up those files, it does a first-time run of the DLU server and Nexus Dashboard to make any necessary changes to the database are set up.

This will also ask whether or not to create a DLU admin account. 
  - If you plan on migrating an existing database, you do not need to create a new admin account.
  - If you are creating the database for the first time, an admin account is necessary.

If you are running this at the same time as ```--configure```, it will remember your database connection information. If you run this on its own, it will ask for it again.

## Step 6: Apache2 Proxy

The last step is to set up the apache webserver proxy. This is used to more easily manage HTTPS, and provide better errors in the event Nexus Dashboard isn't running.

The only user input is for certbot to get an SSL cert. You must enter an email address and agree to the certbot terms of service.

```bash
./servermanager.sh --install-proxy
```

## Step 7: Operations/Production

Now that the server is ready to go, you can begin to run things and follow DLU's documentation a bit more closely.

- Use `servermanager.sh` to run your server:
  - View `servermanager.sh` commands: `./servermanager.sh`
  - Game server commands:
    - Run/restart the server: `./servermanager.sh -r`
    - Turn off the server: `./servermanager.sh -k`
    - Recompile server with the latest updates: `./servermanager.sh -R`
  - Dashboard commands:
    - Run/Restart Nexus Dashboard: `./servermanager.sh -d`
    - Turn off Nexus Dashboard: `./servermanager.sh -dk`
  - Get the status of the server and dashboard `./servermanager.sh -s`
  - TIP: you can also use standard `systemctl` commands to manage the server such as `systemctl --user start dlu.service` or `systemctl --user stop nexus.service`

- Go to your domain in a web browser to access Nexus Dashboard
  - Log in with that admin account to generate keys
    - Tip: Making one key with an absurd number of uses will reduce the amount of times you need to generate keys for new players since you can re-use that key
  - Give players a valid play key you generated and then direct them to that website to create their accounts
  - Direct players to 'https://[your domain]/static/boot.cfg' to download the boot.cfg file they need to tell their client to connect to your server. They can also download this from the link at the bottom of the 'about' page in nexus dashboard.

# Good luck!
