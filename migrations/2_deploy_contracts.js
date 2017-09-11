var ROKToken = artifacts.require("./ROKToken.sol");
var Crowdsale = artifacts.require("./Crowdsale.sol");
var SafeMath = artifacts.require("./SafeMath.sol");
var MultiSigWallet = artifacts.require("./MultiSigWallet.sol");

module.exports = function(deployer, network){

	var owner = web3.eth.accounts[0];
	var accounts = web3.eth.accounts.slice(0,3);
  var signaturesRequired = 2;

	console.log("Owner address: " + owner);
	if (network = 'development') {
		deployer.deploy(SafeMath);
		deployer.link(SafeMath, ROKToken);
		deployer.deploy(ROKToken);
		deployer.link(ROKToken, Crowdsale);
		deployer.deploy(Crowdsale);
	}
  if (network == 'ropsten') {
		deployer.deploy(SafeMath, { from: owner });
    console.log("SafeMath deploy");

    deployer.link(SafeMath, ROKToken);
    return deployer.deploy(ROKToken, { from: owner }).then(function(){
			console.log("ROKToken address: " + ROKToken.address);

				return deployer.deploy(MultiSigWallet, accounts, signaturesRequired).then(function(){
					console.log("MultiSigWallet address: " + MultiSigWallet.address);

						return deployer.deploy(Crowdsale, ROKToken.address, MultiSigWallet.address, { from: owner }).then(function(){
							console.log("Crowdsale address: " + Crowdsale.address);
								return ROKToken.deployed().then(function(rok){
									return rok.owner.call().then(function(owner){
										console.log("ROKToken owner : " + owner);
											return rok.transferOwnership(Crowdsale.address, {from: owner}).then(function(txn){
												console.log("ROKToken  owner was changed: " + Crowdsale.address);
											});
										});
									});
								});
							});
						});
				}
			};
