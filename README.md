# Project Overview

Eragon is all-in-one development & distribution platform for Web3 Mobile Games. It include many common feature which useful for many Game studio such as quest,loyalty,asset mangament...so that Game studio only focus for game core.

Now It has launched on Aptos mainnet on Q2 2024

## Description

This is source code smart contract on Aptos blockchain.It provide common on-chain features such as import/export asset to platform, set/unset asset for specifice features such as Avatar and daily check-in and lucky wheel

## Getting Started

### Dependencies

* Nodejs version > 14
* Install Aptos CLI version > 3.4 -> detail here: https://aptos.dev/en/build/cli

### Installing

* clone repository: git clone https://github.com/eragon-gg/eragon-move-contracts.git
* install packages: npm install
* initial Aptos account for deploy: 
    * aptos init --profile deployer
    * aptos init --profile operator
    * aptos init --profile player

### Compiles
```
aptos move compile --named-addresses eragon=deployer
```
### Deploy
```
aptos move publish --named-addresses eragon=deployer
```
### Initial config
```
cd scripts
./all.sh
```
Now this smart contract ready to use

## Socials

Twitter - [@ERAGON_GG](https://twitter.com/Eragon_gg)

Telegram - [@ERAGON_GG](https://t.me/eragongg)

Medium - [@ERAGON_GG](https://medium.com/@eragon_gg)

Linktree - [@ERAGON_GG](https://linktr.ee/ERAGON_GG)

## Website

Product: [@ERAGON_GG](https://eragon.gg)

## Contact

Email: info@crescentshine.studio
