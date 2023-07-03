import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { TypedDataEncoder, BigNumberish, parseEther, AddressLike, Addressable, keccak256 } from "ethers";
import { Credits, Credits__factory, ERC20 } from "../../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { randomBytes } from "crypto";

describe("Credits", function () {
  async function deployCredits() {
    // Contracts are deployed using the first signer/account by default
    const [deployer, ...users] = await ethers.getSigners();
    const Credits: Credits__factory = await ethers.getContractFactory("Credits");
    const credits = await Credits.deploy();
    const ERC20 = await ethers.getContractFactory("TestERC20");
    const currency1 = await ERC20.deploy();
    const currency2 = await ERC20.deploy();

    return { deployer, users, currency1, currency2, credits };
  }

  async function approveCurrencyAndFillWallets(params: {
    users: SignerWithAddress[];
    currency: ERC20;
    credits: Credits;
  }) {
    const { users, currency, credits } = params;
    for (let i = 0; i < users.length; i++) {
      const userCurrency = currency.connect(users[i]);
      await userCurrency.approve(credits, parseEther("1000000000"));
      await currency.transfer(users[i].address, parseEther("10"));
    }
  };

  async function setupPrizePoolTest(params: {
    users: SignerWithAddress[];
    credits: Credits;
    pool_id: number;
    currency: ERC20;
    cost: BigNumberish;
    poolWeights: number[];
    boost: BigNumberish;
    addCredits: BigNumberish;
    royaltyPercentage: number;
  }) {
    const { credits, pool_id, currency, cost, poolWeights, boost, users, addCredits, royaltyPercentage } =
      params;

    await credits.setRoyaltyPercentage(royaltyPercentage);

    const wallets = [];
    for (let i = 0; i < users.length; i++) {
      await credits.addCredits(users[i].address, currency, addCredits);
      wallets.push(users[i].address);
    }

    await credits.startPrizePool(
      pool_id,
      currency,
      poolWeights,
      wallets,
      cost,
      boost
    );
  }

  it("Add credits simple", async function () {
    const {credits, currency1, users} = await loadFixture(deployCredits);
    await credits.setRoyaltyPercentage(10);
    await approveCurrencyAndFillWallets({
      users: [users[0]],
      currency: currency1,
      credits,
    });

    await credits.addCredits(users[0].address, currency1, parseEther("10"));

    const bal = await credits.getCreditBalance(
      users[0].address,
      currency1
    );

    expect(bal).to.equal(
      parseEther("9"),
      "should be able to add credits"
    );

    const profits = await credits.getProfits(currency1);

    expect(profits).to.equal(parseEther("1"), "should have profits");
  });

  it("Add credits with referral", async function () {
    const { currency1, credits, users } =
      await loadFixture(deployCredits);

    await approveCurrencyAndFillWallets({
      users: [users[0], users[1]],
      currency: currency1,
      credits,
    });

    await credits.setRoyaltyPercentage(10);

    await credits.addCreditsAndSetReferralReceiver(
      users[0].address,
      currency1,
      parseEther("10"),
      users[1].address,
      50
    );

    const bal = await credits.getCreditBalance(
      users[0].address,
      currency1
    );

    expect(bal).to.equal(
      parseEther("9"),
      "should be able to add credits"
    );

    const profits = await credits.getProfits(currency1);
    const refferalRecipientCredis = await credits.getProfits(currency1);

    expect(profits).to.equal(parseEther("0.5"), "should have profits");
    expect(refferalRecipientCredis).to.equal(parseEther("0.5"), "should distribute referral credits");
  });

  it("Prize Pool [3,2,1] weights with 10 users", async function () {
    const { users, currency1, credits } = await loadFixture(deployCredits);
    await approveCurrencyAndFillWallets({
      users: users.slice(0, 10),
      currency: currency1,
      credits,
    });

    await setupPrizePoolTest({
      users: users.slice(0, 10),
      credits,
      pool_id: 1,
      currency: currency1,
      cost: parseEther("1"),
      poolWeights: [3, 2, 1],
      boost: parseEther("0"),
      addCredits: parseEther("10"),
      royaltyPercentage: 0
    });

    const user0Before = await credits.getCreditBalance(users[0].address, currency1);
    expect(user0Before).to.be.eq(parseEther("9"));

    await credits.payoutPrizePool(1, users.slice(0, 10).map((user) => user.address));
    const user0After = await credits.getWinningBalance(users[0].address, currency1);
    const user1After = await credits.getWinningBalance(users[1].address, currency1);
    const user2After = await credits.getWinningBalance(users[2].address, currency1);
    expect(user0After).to.be.eq(parseEther("30") / BigInt(6));
    expect(user1After).to.be.eq(parseEther("20") / BigInt(6));
    expect(user2After).to.be.eq(parseEther("10") / BigInt(6));

    await credits.takeWinnings(users[0].address, currency1); 
    const user0BalanceAfterTakingWinnings = await currency1.balanceOf(users[0].address);
    expect(user0BalanceAfterTakingWinnings).to.be.eq(parseEther("30") / BigInt(6));
  });

  it("Prize Pool [3,2,1] weights with 2 users", async function () {
    const { users, currency1, credits } = await loadFixture(deployCredits);
    await approveCurrencyAndFillWallets({
      users: users.slice(0, 2),
      currency: currency1,
      credits,
    });

    await setupPrizePoolTest({
      users: users.slice(0, 2),
      credits,
      pool_id: 1,
      currency: currency1,
      cost: parseEther("1"),
      poolWeights: [3, 2, 1],
      boost: parseEther("0"),
      addCredits: parseEther("10"),
      royaltyPercentage: 0
    });

    const user0Before = await credits.getCreditBalance(users[0].address, currency1);
    expect(user0Before).to.be.eq(parseEther("9"));

    await credits.payoutPrizePool(1, users.slice(0, 2).map((user) => user.address));
    const user0After = await credits.getWinningBalance(users[0].address, currency1);
    const user1After = await credits.getWinningBalance(users[1].address, currency1);
    expect(user0After).to.be.eq(parseEther("6") / BigInt(5));
    expect(user1After).to.be.eq(parseEther("4") / BigInt(5));
  });

  it("Refund prize pool with 10 users", async function () {
    const { users, currency1, credits } = await loadFixture(deployCredits);
    await approveCurrencyAndFillWallets({
      users: users.slice(0, 2),
      currency: currency1,
      credits,
    });

    await setupPrizePoolTest({
      users: users.slice(0, 2),
      credits,
      pool_id: 1,
      currency: currency1,
      cost: parseEther("1"),
      poolWeights: [3, 2, 1],
      boost: parseEther("0"),
      addCredits: parseEther("10"),
      royaltyPercentage: 0
    });

    const user0Before = await credits.getCreditBalance(users[0].address, currency1);
    expect(user0Before).to.be.eq(parseEther("9"));
    await credits.refundPool(1);
    const user0After = await credits.getCreditBalance(users[0].address, currency1);
    expect(user0After).to.be.eq(parseEther("9"));
    const user0Winnings = await credits.getWinningBalance(users[0].address, currency1);
    expect(user0Winnings).to.be.eq(parseEther("0"));
  });

});