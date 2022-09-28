# Degobbleable Turkey NFTs: An ERC721 token designed to be gobbled and de-gobbled via Paradigm's Art Gobblers mechanics

## By Robriks / 👦🏻👦🏻.eth
### Forked from the ArtGobblers Code 4rena repo, as I spent the past few days there searching for bugs and it was convenient.

Gobble Gobble! It's been discovered that the alien species Art Gobblers are very fond of turkeys. Good thing it's almost Thanksgiving! Nothing like ringing in the fall season with a new NFT project specifically designed for $TURKEY-loving alien Art Gobblers!

Degobbleable Turkeys, ticker $TURKEY, are special NFTs that are designed to form a simple on-chain game around the mechanics of Paradigm's highly anticipated Art Gobblers. They are meant to be gobbled whole by Art Gobblers; but since Art Gobblers are aliens who evolved to possess gastrointestinal systems unfathomable by humans, strange things happen when Art Gobblers gobble turkeys! For reasons unknown, what to a human would normally be a run-of-the-mill delicious holiday meal is a reversible cloning process for Art Gobblers' digestive systems. That's right, after being gobbled (via the cook() function), Degobbleable Turkey NFTs can be resurrected by being de-gobbled: burned and reminted (via the deCook() function)! 

Get it, Gobble-deCook? ;)

## Overview

A few quick facts about the Degobbleable Turkey NFT contract are worth discussing:

1. Only Art Gobbler holders are able to mint a Turkey NFT
2. Only one Turkey NFT may be minted per Gobbler. This maintains a 1:1 ratio of gobblers to non-clone turkeys
3. There is no limit to cloning _original_ turkey NFTs, resulting in a theoretical uncapped supply. However, turkey clones cannot be cloned, preventing recursive/exponential supply inflation
4. Art Gobbler holders must individually claim their Gobbler's Turkey NFT. (Not an airdrop!)
5. The Turkey NFT may be gobbled/degobbled at will, to suit the artistic/financial preference of its holder
6. The contract is not ownable or upgradeable in any capacity, to match the hyperstructure aspects of the Art Gobblers project

Keep in mind that this contract is NOT audited and was spun up in one day, so be wary of bugs (and please report them to me to be fixed)!

## How it works: Proof of Burn

What exactly happens when a gobbled Turkey nft is un-gobbled, you ask? Great question! Naturally, its tokenURI is updated to reflect a different image reflecting its new resurrected state, duh. But more importantly, the Art Gobblers alien physiology thereby produces a cloned Turkey NFT, which is the only way by which new Degobbleable Turkeys can be minted. I call it proof of burn!

Under the hood, the cook() hook uses SolMate's handy _burn and _mint functions, which delete the gobbled tokenId, burn it to the 0x00 address, and then immediately remint the deleted tokenId within the same transaction. In addition to recovering the Turkey's tokenId to the caller's address, a second additional Turkey NFT is minted to the caller: a clone of the original! This adds a cost to creating new turkeys (ie gas).

This process is very user-friendly as it happens automatically when an Art Gobbler owner calls gobble() on their Turkey NFT. This of course requires the user to also own a Degobbleable Turkey NFT, which only requires a simple claim to mint. Again, it's worth noting Turkey NFTs are only mintable by Art Gobblers holders.

As previously mentioned, cooking + deCooking is the only way that Turkeys can be minted. This effectively prevents rapid supply inflation, because cloned turkeys cannot be gobbled. This is enforced in a simple manner: tokenIds for cloned turkey NFTs are pushed beyond the ArtGobblerSupply. This is achieved additively by using a 10000 multiplier, causing every subsequent clone to have a tokenId 10000 higher than the last (ie Degobbleable Turkey #1's clones will have tokenId #10001, #20001, #30001 etc.)

## Working with this repo

To compile, run:

```forge build```

To run the Turkey NFT tests with plenty of verbose output from the test file:

```forge test --match-contract TurkeyTest -vvvv```

Feel free to mess around with the contracts!

## Open to suggestions!

If you have ideas about how to make this game more interesting, let me know! A limited time window element for gobbling/degobbling or other additional mechanic could be engaging. Ways to incorporate Goo, Pages, or Legendary Gobblers are also ideas with potential. Feel free to reach out on GitHub or Twitter with ideas. :)

Gobble Gobble!!

