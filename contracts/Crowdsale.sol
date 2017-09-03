pragma solidity ^0.4.11;


import './SafeMath.sol';
import './ROKToken.sol';
import './Pausable.sol';
import './PullPayment.sol';

/*
*  Crowdsale Smart Contract for the Rockchain project
*  Author: Yosra Helal helal.yosra@gmail.com
*  Contributor: Christophe Ozcan christophe.ozcan@crypto4all.com
*/

contract Crowdsale is Pausable, PullPayment{
  using SafeMath for uint256;

  ROKToken public rok;
  address public owner;
  address public escrow;                  // Address of Escrow Provider Wallet
  address public bounty;                      // Address dedicated for bounty services
  address public team;                        // Adress for ROK token allocated to the team
  uint public rok_team;                       // ROK amount dedicated to the team
  uint public rateETH_USD;                    // final rate based on the ratio described on our White paper
  uint public rateETH_ROK;                   // rate Ether per ROK token
  uint public maxFundingGoal;                // Maximum goal in Ether raised
  uint public minFundingGoal;               // Minimum funding goal in Ether raised
  uint public startDate;			       //Starting time of Crowsd Sale
  uint public maxROKsupply;
  uint public deadline;
  uint public savedBalance;           //  Total amount raised in ETH
  uint public savedBalanceToken;      // Total ROK Token allocated
  bool public ownerPaid = false;     //Has the owner been paid?

  mapping(address => uint) balances;			//Balances in incoming Ether
  mapping(address => uint) savedBalances;		//Saved Balances in incoming Ether (for after withdrawl validation)
  mapping(address => uint) savedBalancesTokens;		//Saved BalancesTokens in ROK for each coming Ether

  //Events to record new contributions
  event Contribution(address indexed _contributor, uint indexed _value, uint indexed _tokens);

  //Event to record each time tokens are paid out
	event PayTokens(
	    address indexed _receiver,
	    uint indexed _value,
	    uint indexed _timestamp
	    );

	//Event to record each time Ether is paid out
	event PayEther(
	    address indexed _receiver,
	    uint indexed _value,
	    uint indexed _timestamp
	    );

	//Event to record when tokens are burned.
	event BurnTokens(
	    uint indexed _value,
	    uint indexed _timestamp
	    );

  //Initialization
  function Crowdsale(uint rate){
    owner = msg.sender;
    rok = ROKToken(0x0);                           //add address of the specific contract -- to Replace
    escrow = 0x0;                          //add address of the multisg wallet
    bounty = 0x0;                               //add address of the bounty wallet
    team = 0x0;                                 //add address of the team wallet
    rateETH_USD = rate;                         //Set 48H before ICO launch
    rateETH_ROK = rateETH_USD.mul(1000);        // Rate allowing to calculate the number of ETH per ROK
    maxFundingGoal = rateETH_USD.mul(100000);   // maximum amount of Ether raised depending on the final rate and respecting the minimum goal to reach 6.3M $
    minFundingGoal = rateETH_USD.mul(18000);    // minimum amount of Ether raised depending on the final rate and respecting the minimum goal to reach 35M $
    maxROKsupply = 100000000;				// Maximum supply of ROK Tokens
    startDate = 1509534000;               // epoch timestamp representing the start date (1st november 2017 11:00 gmt)
    deadline = 1512126000;               // epoch timestamp representing the end date (1st december 2017 11:00 gmt)
    savedBalanceToken = 0;
    savedBalance = 0;
  }

	//Default Function, delegates to contribute function (for ease of use)
	//WARNING: Not compatible with smart contract invocation, will exceed gas stipend!
	//Only use from full wallets.
	function () payable {
		contribute();
	}

    //Contribute Function, accepts incoming payments and tracks balances for each contributors
	function contribute() payable {
		require(isStarted());                      //Has the crowdsale even started yet?
		require(this.balance <= maxFundingGoal);   //Does this payment send us over the max?
		require(msg.value > 0);                    //Require that the incoming amount is different to 0
		require(!isComplete()); 				   //Has the crowdsale completed? We only want to accept payments if we're still active.
		balances[msg.sender] += msg.value;         //If all checks good, then accept contribution and record new balance.
		savedBalances[msg.sender] += msg.value;    //Save contributors balance in Ether for later in case of pay back
		savedBalance += msg.value;				   //add the new total balance in Ether
		uint Roktoken = rateETH_ROK.mul(msg.value) + getBonus(rateETH_ROK.mul(msg.value));   //Calcul of the ROk tokens amount
 		savedBalancesTokens[msg.sender] = Roktoken.mul(80).div(100);     // Save the balance in Rok for each contributor (only 80% of calculated tokens are allocated as decribed in the WP)
		savedBalanceToken += Roktoken;             //Add the new total balance in ROK
		Contribution(msg.sender,msg.value,savedBalancesTokens[msg.sender]); //Log the new contribution!
	}


    //Function to check if crowdsale has started yet
	function isStarted() constant returns(bool) {
		return now >= startDate ;
	}

    //Function to check if crowdsale is complete (
	function isComplete() constant returns(bool) {
	return (savedBalance >= maxFundingGoal) || (now >= deadline) || (savedBalanceToken >= maxROKsupply);
	}

    //Function to view current token balance of the crowdsale contract
	function tokenBalance() constant returns(uint balance) {
		return rok.balanceOf(address(this));
	}

	//Function to check if crowdsale has been successful (has incoming contribution balance met, or exceeded the minimum goal?)
	function isSuccessful() constant returns(bool) {
		return (savedBalance >= minFundingGoal);
	}

    //Function to check the Ether balance of a contributor
	function checkEthBalance(address _contributor) constant returns(uint balance) {
		return balances[_contributor];
	}

	//Function to check the Saved Ether balance of a contributor
	function checkSavedEthBalance(address _contributor) constant returns(uint balance) {
		return savedBalances[_contributor];
	}

	//Function to check the Token balance of a contributor
	function checkRokBalance(address _contributor) constant returns(uint balance) {
		return savedBalancesTokens[_contributor];	//Function to check the Token balance of a contributor
	}

	//Function to check the current Tokens Sold in the ICO
	function checkRokSold() constant returns(uint total) {
		return (savedBalanceToken);	//Function to check the current Tokens Sold in the ICO
	}

    //Function to check the current Tokens affected to the team
	function checkRokTeam() constant returns(uint totalteam) {
		return (savedBalanceToken.mul(19).div(100));	//Function to check the current Tokens affected to the team
	}

	//Function to check the current Tokens affected to bounty
	function checkRokBounty() constant returns(uint totalbounty) {
		return (savedBalanceToken.div(100));	//Function to check the current Tokens aFfected for bounty
	}

	//function to check percentage of goal achieved
	function percentOfGoal() constant returns(uint16 goalPercent) {
		return uint16((savedBalance*100)/minFundingGoal);
	}

    //Calcul the ROK bonus according to the investment period
   function getBonus(uint amount) internal constant returns (uint) {
       uint bonus = 0;
	   uint firstbonusdate = 1509879600;   //  5 November 2017 11:00:00 GMT
	   uint secondbonusdate = 1510311600;  // 10 November 2017 11:00:00 GMT

     if (now <= firstbonusdate) { bonus = amount.div(10);  }  // if investment date is on the 10% bonus period then return bonus
	 if (now <= secondbonusdate && now >= firstbonusdate) { bonus = amount.div(20); } // else if investment date is on the 5% bonus period then return bonus

	   return bonus; // else return amount without bonus
	  }

	//Function to pay out
	function payout() onlyOwner {
		require(isComplete());									//Only request payout once ICO is complete
    require(!ownerPaid);									//Require that the owner hasn't already been paid
		ownerPaid = true;										//Set flag to show owner has been paid.

    if(isSuccessful()){
		require(escrow.transfer(this.balance));							//We were successful, so transfer the balance to the escrow address
    PayEther(escrow,this.balance,now);      				//Log the payout to escrow
		require(rok.transfer(bounty,checkRokBounty()));			//And since successful, send Bounty tokens to the dedicated address
    PayTokens(bounty,checkRokBounty(),now);       			//Log payout of tokens to bounty
	  payTokens();                                            // Pay all contributors
	  payTeam();												// Pay team members
		}else{                                                  //Once the refund is done
        require(deadline + 45 days);            //Refund period to respect before finalizing
        require(rok.transfer(owner,tokenBalance()));			//We were not successful, so send ALL tokens back to owner.
        PayTokens(owner,tokenBalance(),now);       			    //Log payout of tokens to owner
        require(team.transfer(this.balance));              //transfer the unrequested tokens to the team for vesting
        PayEther(team,this.balance,now);      				//Log the payout to team
		}
	}

    //Function to pay Contributors
	function payTokens() internal {
		require(balances[msg.sender]>0);					//Does the requester have a balance?
		uint tokenAmount = checkRokBalance(msg.sender);		// Check Tokens per contributors
		balances[msg.sender] = 0;							//Zero their balance ahead of transfer to avoid re-entrance (even though re-entrance here should be zero risk)
		require(rok.transfer(msg.sender,tokenAmount));				//And transfer the tokens to them
		PayTokens(msg.sender,tokenAmount,now);          	//Log payout of tokens to contributor
	}

    //Function to pay Team
	function payTeam() internal {
	  require(checkRokTeam()>0);
    uint rok_final_team = checkRokTeam();

    require(rok.transfer(team,rok_final_team));         //Transfert the amount of ROK to the team
		PayTokens(team,rok_final_team,now);       			//Log payout of tokens to creator

    if (checkRokSold() < rok.totalSupply()){
      rok.burn(rok.totalSupply().sub(checkRokSold()));	// burn the rest of ROK
      BurnTokens(rok.totalSupply().sub(checkRokSold()),now); //Log burn of tokens
    }
	}

  /*
   * Refund function
   * When mincap is not reach Investors can call the approveRefund function of the ROK token contract
   * with this crowdsale contract on parameter with all the ROK they get in order to be refund
   */
  function refund (address _from, address _token, bytes _extraData) public {
    require (_token == address(rok));             //require @ sender == rok token @
    require (now <= deadline + 45 days);                          //Refund period = 45 days
    uint ETHToSend = checkSavedEthBalance(_from);                 //Check ETH to send
    savedBalancesTokens[_from] = 0;
    savedBalances[_from] = 0;
    if (ETHToSend > 0) {
      asyncSend(_from,ETHToSend);									// pull payment to get refund in ETH
    }
  }

}
