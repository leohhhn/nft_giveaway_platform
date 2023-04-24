import {ethers} from 'hardhat';
import {GiveawayCollection} from '../typechain-types';

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log('Deploying from: ' + deployer.address);

    let goldCollection: GiveawayCollection;
    let silverCollection: GiveawayCollection;
    let bronzeCollection: GiveawayCollection;

    let giveawayCollectionFactory = await ethers.getContractFactory('GiveawayCollection');

    goldCollection = await giveawayCollectionFactory.deploy('Gold 3327', 'G3327');
    silverCollection = await giveawayCollectionFactory.deploy('Silver 3327', 'S3327');
    bronzeCollection = await giveawayCollectionFactory.deploy('Bronze 3327', 'B3327');

    await goldCollection.deployed();
    await silverCollection.deployed();
    await bronzeCollection.deployed();

    console.log(goldCollection.address, silverCollection.address, bronzeCollection.address);
}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
