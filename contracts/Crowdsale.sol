pragma solidity ^0.4.17;


import './SafeMath.sol';
import './ROKToken.sol';
import './Pausable.sol';
import './PullPayment.sol';


/*
*  Crowdsale Smart Contract for the Rockchain project
*  Author: Yosra Helal yosra.helal@rockchain.org
*  Contributor: Christophe Ozcan christophe.ozcan@crypto4all.com
*/

contract Crowdsale is Pausable, PullPayment {
    using SafeMath for uint256;

    address public owner;

    ROKToken public rok;

    address public escrow;                                                                             // Address of Escrow Provider Wallet
    address public bounty ;                      						      // Address dedicated for bounty services
    address public team;                       							     // Adress for ROK token allocated to the team
    uint256 public rateETH_ROK;                                                        		    // Rate Ether per ROK token
    uint256 public constant minimumPurchase = 0.1 ether;                                           // Minimum purchase size of incoming ETH
    uint256 public constant maxFundingGoal = 100000 ether;                                        // Maximum goal in Ether raised
    uint256 public constant minFundingGoal = 18000 ether;                                        // Minimum funding goal in Ether raised
    uint256 public constant startDate = 1509534000;                                                // epoch timestamp representing the start date (1st november 2017 11:00 gmt)
    uint256 public constant deadline = 1512126000;                                                // epoch timestamp representing the end date (1st december 2017 11:00 gmt)
    uint256 public constant refundeadline = 1515927600;                                          // epoch timestamp representing the end date of refund period (14th january 2018 11:00 gmt)
    uint256 public savedBalance = 0;                                                            // Total amount raised in ETH
    uint256 public savedBalanceToken = 0;                                                      // Total ROK Token allocated

    mapping (address => uint256) balances;                                                   // Balances in incoming Ether

    // Events to record new contributions
    event Contribution(address indexed _contributor, uint256 indexed _value, uint256 indexed _tokens);

    // Event to record each time Ether is paid out
    event PayEther(
    address indexed _receiver,
    uint256 indexed _value,
    uint256 indexed _timestamp
    );

    // Event to record when tokens are burned.
    event BurnTokens(
    uint256 indexed _value,
    uint256 indexed _timestamp
    );

    // Initialization
    function Crowdsale(address _roktoken, address _escrow, address _bounty, address _team){
        owner = msg.sender;
        // add address of the specific contract
        rok = ROKToken(_roktoken);
        escrow = _escrow;
        bounty = _bounty;
        team = _team;
        rateETH_ROK = 1000;
    }

    // Default Function, delegates to contribute function (for ease of use)
    // WARNING: Not compatible with smart contract invocation, will exceed gas stipend!
    // Only use from external accounts
    function() payable whenNotPaused{
        contribute(msg.sender);
    }

    // Contribute Function, accepts incoming payments and tracks balances for each contributors
    function contribute(address contributor) internal{
        // Has the crowdsale even started yet?
        assert(isStarted());
        // Does this payment send us over the max?
        assert(this.balance <= maxFundingGoal);
        // Require that the incoming amount is at least the minimum purchase size
        assert(msg.value >= minimumPurchase);
        // If all checks good, then accept contribution and record new balance
        balances[contributor] = balances[contributor].add(msg.value);
        // add the new total balance in Ether
        savedBalance = savedBalance.add(msg.value);
        // Calcul of the ROk tokens amount
        uint256 Roktoken = (rateETH_ROK.mul(msg.value))/(1 ether) + getBonus((rateETH_ROK.mul(msg.value)) / (1 ether));
        uint256 RokToSend = (Roktoken.mul(80)).div(100);
        // And transfer the tokens to contributor
        rok.transfer(contributor, RokToSend);
        // Add the new total balance in ROK
        savedBalanceToken = savedBalanceToken.add(Roktoken);
        // Log the new contribution!
        Contribution(contributor, msg.value, RokToSend);
    }


    // Function to check if crowdsale has started yet
    function isStarted() constant returns (bool) {
        return now >= startDate;
    }

    // Function to check if crowdsale is complete (
    function isComplete() constant returns (bool) {
        return (savedBalance >= maxFundingGoal) || (now >= deadline) || (savedBalanceToken >= rok.totalSupply());
    }

    // Function to view current token balance of the crowdsale contract
    function tokenBalance() constant returns (uint256 balance) {
        return rok.balanceOf(address(this));
    }

    // Function to check if crowdsale has been successful (has incoming contribution balance met, or exceeded the minimum goal?)
    function isSuccessful() constant returns (bool) {
        return (savedBalance >= minFundingGoal);
    }

    // Function to check the Ether balance of a contributor
    function checkEthBalance(address _contributor) constant returns (uint256 balance) {
        return balances[_contributor];
    }

    // Function to check the current Tokens Sold in the ICO
    function checkRokSold() constant returns (uint256 total) {
        return (savedBalanceToken);
        // Function to check the current Tokens Sold in the ICO
    }

    // Function to check the current Tokens affected to the team
    function checkRokTeam() constant returns (uint256 totalteam) {
        return (savedBalanceToken.mul(19).div(100));
        // Function to check the current Tokens affected to the team
    }

    // Function to check the current Tokens affected to bounty
    function checkRokBounty() constant returns (uint256 totalbounty) {
        return (savedBalanceToken.div(100));
        // Function to check the current Tokens aFfected for bounty
    }

    // Function to check the refund period is over
    function refundPeriodOver() returns (bool){
        return (now > refundeadline);
    }

    // Function to check the refund period is over
    function refundPeriodStart() returns (bool){
        return (now > deadline);
    }

    // function to check percentage of goal achieved
    function percentOfGoal() constant returns (uint16 goalPercent) {
        return uint16((savedBalance * 100) / minFundingGoal);
    }

    // Calcul the ROK bonus according to the investment period
    function getBonus(uint256 amount) internal constant returns (uint256) {
        uint bonus = 0;
        //   5 November 2017 11:00:00 GMT
        uint firstbonusdate = 1509879600;
        //  10 November 2017 11:00:00 GMT
        uint secondbonusdate = 1510311600;

        //  if investment date is on the 10% bonus period then return bonus
        if (now <= firstbonusdate) {bonus = amount.div(10);}
        //  else if investment date is on the 5% bonus period then return bonus
        else if (now <= secondbonusdate && now >= firstbonusdate) {bonus = amount.div(20);}
        //  return amount without bonus

        return bonus;
    }

    // Function to pay out
    function payout() onlyOwner {
        if (isSuccessful() && isComplete()) {
            // We were successful, so transfer the balance to the escrow address
            escrow.transfer(this.balance);
            // Log the payout to escrow
            PayEther(escrow, this.balance, now);
            // And since successful, send Bounty tokens to the dedicated address
            rok.transfer(bounty, checkRokBounty());
            //  Pay team members
            payTeam();
        }
        else {
            if (refundPeriodOver()) {
                // Transfer the balance to the escrow address
                escrow.transfer(this.balance);
                // Log the payout to escrow
                PayEther(escrow, this.balance, now);
                // Send Bounty tokens to the dedicated address
                rok.transfer(bounty, checkRokBounty());
                // Pay team members
                payTeam();
            }
        }
    }

    //Function to pay Team
    function payTeam() internal {
        require(checkRokTeam() > 0);
        uint rok_final_team = checkRokTeam();

        // Transfert the amount of ROK to the team
        rok.transfer(team, rok_final_team);

        if (checkRokSold() < rok.totalSupply()) {
            // burn the rest of ROK
            rok.burn(rok.totalSupply().sub(checkRokSold()));
            //Log burn of tokens
            BurnTokens(rok.totalSupply().sub(checkRokSold()), now);
        }
    }

    /* When MIN_CAP is not reach:
     * 1) backer call the "refund" function of the Crowdsale contract with the same amount of ETH sent
     * 2) backer call the "withdrawPayments" function of the Crowdsale contract to get a refund in ETH
     */
    function refund() public {
        // if the min cap is not reached
        require(!isSuccessful());
        // Refund start period for 45 days
        require(refundPeriodStart());
        // Refund period is not still reached
        require(!refundPeriodOver());
        //  Check if the sender is already a contributor
        require(balances[msg.sender] != 0);
        // Check ETH to send
        uint ETHToSend = checkEthBalance(msg.sender);
        balances[msg.sender] = 0;

        if (ETHToSend > 0) {
            //  pull payment to get refund in ETH
            asyncSend(msg.sender, ETHToSend);
        }
    }
}
