# DLUQuickstart
Automates the DLU (Darkflame LEGO Universe) dedicated server installation.

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
 - Step 3: Generating configuration file
 - Step 4: Installation using config file
 - Step 5: Operations/Production

## Step 0: What do you want?

See the disclaimer above. Do you want to host a server? Do you want to open that up to others? Do you want to manage that risk and pay for the costs, be it hardware, electricity, cloud service fees, or domain hosting costs? **If you just want to play the game, it's a lot easier to find a server someone else is hosting.**

## Step 1: Provisioning Infrastructure

I mostly deploy via AWS, but that's my choice for my specific situation. You can host this on nearly anything. If you choose to create something disposable in the cloud, please be mindful that cloud services cost money over time, and you manage your costs accordingly. **This is not a tutorial on using cloud services most efficiently.**

### Recommendations

#### Hardware Specs

If you are running your game server and web frontend on the same machine as your database, I recommend at least 2 vcpus and 4GB of RAM. If you are separating your database to a different server, you can get away with 2vcpus and 2GB of RAM. On AWS, that would be a t3a.medium for a single instance, or a t3a.small instance for the game server with a RDS-managed db.t3.micro instance for the database. 

Either way, 12gb of storage is the bare minimum I would recommend. I do not believe that paying more for SSD storage is necessary for this use case.

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

If you intend to run your server on a domain, make sure you point that domain to the IP address of your server infrastructure before running a `--install`

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

Also, if you are importing from a previously existing server, make sure you have copied over your database dump file to your infrastructure.

## Step 3: Generate server configuration

All server configuration and management has been consolidated into a single script, `servermanager.sh`. It generates a configuration file, installs based on the information in said file, and is used for common tasks like starting, stopping, or backing up the data from your DLU server.

To install, you must first define your server configuration

```bash
./servermanager.sh --generate
```

It will prompt you for many things and save these choices to a file of your choosing. You can use this file in step 4.

*Key Caveats*: If you pick the 'remote' database option, the script assumes you are using the same database name and user name specified at the top of the script, and all of that already exists in the database it tries to connect to. I don't expect most people to do that option, but if you are then you probably can figure that out.

## Step 4: Server Installation

When you have the config file generated in step 3, you can install your DLU server with the following command:

```bash
./servermanager.sh --install config.json
```

Some important notes:
 - If you are using a local database and did not import from a pre-existing server, the script will prompt you to create the admin user during install. This admin user is required to manage the server with nexus dashboard
 - If you are building an internet server and you didn't specify an email for your SSL certificate renewal, the script will prompt you for this during the install

*Tip:* If you change the details of your configuration file, you can run ```./servermanager.sh --configure file.json``` and it will re-configure your server based on that configuration. This will regenerate local database passwords

## Step 5: Operations/Production

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
  - *TIP:* you can also use standard `systemctl` commands to manage the server such as `systemctl --user start dlu.service` or `systemctl --user stop nexus.service`

- Go to your domain in a web browser to access Nexus Dashboard
  - Log in with that admin account to generate keys
    - Tip: keys can have multiple uses, or be disabled
  - Give players a valid play key you generated and then direct them to that website to create their accounts
  - Direct players to 'https://[your domain]/static/boot.cfg' to download the boot.cfg file they need to tell their client to connect to your server. They can also download this from the link at the bottom of the 'about' page in nexus dashboard.

# Good luck!
