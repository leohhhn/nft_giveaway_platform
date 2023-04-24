import {expect} from 'chai';
import {ethers} from 'hardhat';
import {Giveaway, GiveawayCollection} from '../typechain-types';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {Contract} from 'ethers';
import {LINK_TOKEN_GOERLI, VRF_WRAPPER_GOERLI} from '../helpers/consts';

describe('Giveaway', function () {

    let goldCollection: Contract;
    let silverCollection: Contract;
    let bronzeCollection: Contract;
    let giveaway: Giveaway;
    let admin: SignerWithAddress, user: SignerWithAddress;

    let testToken: Contract;

    beforeEach('Setup', async () => {
        [admin, user] = await ethers.getSigners();

        let testTokenFactory = await ethers.getContractFactory('TestERC20');
        let giveawayCollectionFactory = await ethers.getContractFactory('GiveawayCollection');
        let giveawayFactory = await ethers.getContractFactory('Giveaway')

        goldCollection = await giveawayCollectionFactory.connect(admin)
            .deploy('Gold 3327', 'G3327');
        silverCollection = await giveawayCollectionFactory.connect(admin)
            .deploy('Silver 3327', 'S3327');
        bronzeCollection = await giveawayCollectionFactory.connect(admin)
            .deploy('Bronze 3327', 'B3327');

        testToken = await testTokenFactory.deploy();

        await goldCollection.deployed();
        await silverCollection.deployed();
        await bronzeCollection.deployed();

        await testToken.deployed();

        giveaway = await giveawayFactory.connect(admin)
            .deploy(
                goldCollection.address,
                silverCollection.address,
                bronzeCollection.address,
                LINK_TOKEN_GOERLI,
                VRF_WRAPPER_GOERLI
            );

        await giveaway.deployed();

        await goldCollection.transferOwnership(giveaway.address);
        await silverCollection.transferOwnership(giveaway.address);
        await bronzeCollection.transferOwnership(giveaway.address);

        await giveaway.addAllowedToken(testToken.address);
    });

    it('Should deploy correctly', async () => {
        expect(await giveaway.goldCollection()).to.be.eq(goldCollection.address);
        expect(await giveaway.silverCollection()).to.be.eq(silverCollection.address);
        expect(await giveaway.bronzeCollection()).to.be.eq(bronzeCollection.address);
    });

    it('Should allow admin to create a new giveaway correctly', async () => {
        let currentTimestamp = (await ethers.provider.getBlock(await ethers.provider.getBlockNumber())).timestamp;
        let deadline = currentTimestamp + 1000;
        let desc = ethers.utils.formatBytes32String('Giveaway #1!');
        await giveaway.connect(admin).createGiveaway(deadline, desc);

        expect((await giveaway.getLatestGiveaway())['deadline']).to.be.eq(deadline);
        expect((await giveaway.getLatestGiveaway())['description']).to.be.eq(desc);
        expect((await giveaway.getLatestGiveaway())['treasurySize']).to.be.eq(0);
    });

    it('Should not allow a user to participate in a closed giveaway', async () => {
        let currentTimestamp = (await ethers.provider.getBlock(await ethers.provider.getBlockNumber())).timestamp;
        let deadline = currentTimestamp + 1; // giveaway will expire immediately
        let desc = ethers.utils.formatBytes32String('Giveaway #1!');
        await giveaway.connect(admin).createGiveaway(deadline, desc);

        await expect(giveaway.connect(user).participate(ethers.constants.AddressZero, 0))
            .to.be.revertedWith('Giveaway::onlyActive: This giveaway is not active.');
    });

    it('Should add new allowed tokens', async () => {
        await giveaway.addAllowedToken(admin.address);
        expect(await giveaway.allowedTokens(admin.address)).to.be.eq(true);
    });

    it('Should participate correctly', async () => {
        // create giveaway
        let currentTimestamp = (await ethers.provider.getBlock(await ethers.provider.getBlockNumber())).timestamp;
        let deadline = currentTimestamp + 1000;
        let desc = ethers.utils.formatBytes32String('Giveaway #1!');
        await giveaway.connect(admin).createGiveaway(deadline, desc);
        await giveaway.addAllowedToken(testToken.address);

        // get test tokens & approve giveaway
        await testToken.connect(user).mint(ethers.utils.parseEther('100'));
        await testToken.connect(user).approve(giveaway.address, ethers.utils.parseEther('100'));

        await giveaway.connect(user).participate(testToken.address, 0);
        let latestGiveaway = await giveaway.getLatestGiveaway();

        expect(latestGiveaway['participants'][0]).to.be.eq(user.address);
        expect(latestGiveaway['treasurySize']).to.be.eq(1);

        await giveaway.connect(user).participate(testToken.address, 0);
        latestGiveaway = await giveaway.getLatestGiveaway();

        expect(latestGiveaway['treasurySize']).to.be.eq(2);
    });


});
