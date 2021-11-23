const { expect } = require("chai");
const { ethers } = require("hardhat");

BN = ethers.BigNumber.from;

abi = ethers.utils.defaultAbiCoder

describe("ERC721Loanable", function () {
  it("LoanNFT Deploy", async function () {
    const [owner, receiver, observer] = await ethers.getSigners();
    zeroAddr = ethers.constants.AddressZero;

    supply = BN("1000000000000000000000000000");
    payment = BN("10000000000000000000000000");

    const LoanNFT = await ethers.getContractFactory("LoanNFT");
    const loanNFT = await LoanNFT.deploy("LoanNFT", "LNFT");

    const PayToken = await ethers.getContractFactory("PayToken");
    const token = await PayToken.deploy()

    await loanNFT.deployed();

    await loanNFT.mint();

    expect(await loanNFT.totalSupply()).to.equal(1);

    expect(await token.balanceOf(owner.address))
          .to.equal(supply);
    expect(await token.balanceOf(receiver.address))
          .to.equal(BN("0"));

    expect(await token.transfer(receiver.address, payment))
          .to.emit(token, 'Transfer')
          .withArgs(owner.address, receiver.address, payment)

    expect(await loanNFT.mint())
          .to.emit(loanNFT, 'Transfer')
          .withArgs(zeroAddr, owner.address, 2);

    var LoanOffer = {
        from: owner.address,
        to: receiver.address,
        premiumToken: token.address,
        tokenId: 1,
        premiumAmount: payment,
        loanExpiry: 1668449326,
        closeFeeReward: 0,
        offerDeadline: 1668449326,
        nonce: 1,
    };

    var LoanType = [ "tuple(address from, address to, address premiumToken, uint256 tokenId, uint256 premiumAmount, uint256 loanExpiry, uint256 closeFeeReward, uint256 offerDeadline, uint256 nonce) LoanTerms" ]

    var encodedLoan = abi.encode(LoanType, [LoanOffer]);

    var loanHash = ethers.utils.keccak256(encodedLoan)

    var offerSignature = await owner.signMessage(ethers.utils.arrayify(loanHash));

    expect(await token.connect(receiver).approve(loanNFT.address, payment))
          .to.emit(token, 'Approval')
          .withArgs(receiver.address, loanNFT.address, payment); 

    const loanTx = await loanNFT.connect(receiver).takeSignedLoan(LoanOffer, offerSignature);

    expect(loanTx)
          .to.emit(loanNFT, 'Loan')
          .withArgs(owner.address, receiver.address, 1);

    expect(loanTx)
          .to.emit(token, 'Transfer')
          .withArgs(receiver.address, owner.address, payment);

    await expect(loanNFT.connect(receiver).transferFrom(receiver.address, observer.address, 1))
        .to.be.revertedWith("Loaned tokens cannot be transferred");

  });
});
