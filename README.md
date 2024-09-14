# Run A Tucana Fullnode

**How to run a fullnode on the Tucana Testnet**

*(tucana_712-1)*

> Genesis file [Published](https://github.com/TucanaProtocol/Tucana/raw/tucana/develop/Networks/Testnet/tucana_712-1/genesis.json)
> Peers list [Published](https://github.com/TucanaProtocol/Tucana/raw/tucana/develop/Networks/Testnet/tucana_712-1/peers.txt)

## Hardware Requirements

### Minimum:
* 16 GB RAM
* 100 GB NVME SSD
* 3.2 GHz x4 CPU

### Recommended:
* 32 GB RAM
* 500 GB NVME SSD
* 4.2 GHz x6 CPU

### Operating System:
* Linux (x86_64) or Linux (amd64)
* Recommended Ubuntu or Arch Linux

## Install dependencies 

**If using Ubuntu:**

Install all dependencies:

`sudo snap install go --classic && sudo apt-get install git && sudo apt-get install gcc && sudo apt-get install make`

Or install individually:

* go1.18+: `sudo snap install go --classic`
* git: `sudo apt-get install git`
* gcc: `sudo apt-get install gcc`
* make: `sudo apt-get install make`

**If using Arch Linux:**

* go1.18+: `pacman -S go`
* git: `pacman -S git`
* gcc: `pacman -S gcc`
* make: `pacman -S make`

## Install `tucd`

### Clone git repository and install

```bash
git clone https://github.com/TucanaProtocol/Tucana.git
cd Tucana/cmd/tucd
go install -tags ledger ./...
sudo mv $HOME/go/bin/tucd /usr/bin/
```

## Set up fullnode

Initialize the node. Replace `<moniker>` with whatever you'd like to name your validator.

`tucd init <moniker> --chain-id tucana_712-1`

If this runs successfully, it should dump a blob of JSON to the terminal.

Download the Genesis file: 

`wget https://github.com/TucanaProtocol/Tucana/raw/tucana/develop/Networks/Testnet/tucana_712-1/genesis.json -P $HOME/.tucd/config/` 

> _**Note:** If you later get `Error: couldn't read GenesisDoc file: open /root/.tucd/config/genesis.json: no such file or directory` put the genesis.json file wherever it wants instead, such as:
> 
> `sudo wget https://github.com/TucanaProtocol/Tucana/raw/tucana/develop/Networks/Testnet/tucana_712-1/genesis.json -P/root/.tucd/config/`

Edit the minimum-gas-prices in `${HOME}/.tucd/config/app.toml`:

`sed -i 's/minimum-gas-prices = "0atuc"/minimum-gas-prices = "1000000000atuc"/g' $HOME/.tucd/config/app.toml`

Add seeds to `$HOME/.tucd/config/config.toml`:
`sed -i 's/seeds = ""/seeds = "c12dbad41880b077207c92a2b12a1ae1301c5ceb@54.87.220.124:26656,998cae4ace4f646fbd18ad24504d7b0d10d0a772@52.4.39.41:26656"/g' $HOME/.tucd/config/config.toml`

### Set `tucd` to run automatically

* Start `tucd` by creating a systemd service to run the node in the background: 
* Edit the file: `sudo nano /etc/systemd/system/tucd.service`
* Then copy and paste the following text into your service file. Be sure to edit as you see fit.

```bash
[Unit]
Description=Tucana Node
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/
ExecStart=/root/go/bin/tucd start --chain-id tucana_712-1
Restart=on-failure
StartLimitInterval=0
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
```

## Start the node

Reload the service files: 

`sudo systemctl daemon-reload`

Create the symlink: 

`sudo systemctl enable tucd.service`

Start the node: 

`sudo systemctl start tucd && journalctl -u tucd -f`
