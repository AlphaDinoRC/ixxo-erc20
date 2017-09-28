pragma solidity ^0.4.11;


import './ERC20.sol';
import './Ownable.sol';
import './SafeMath.sol';


contract ROKToken is ERC20, Ownable {
    using SafeMath for uint256;
    /* Public variables of the token */
    string public constant name = 'ROK Token';

    string public constant symbol = 'ROK';

    uint public constant decimals = 18;

    uint public totalSupply;

    mapping (address => uint) balances;

    mapping (address => mapping (address => uint)) allowed;

    /*event Burn(address indexed burner, uint indexed value);*/
    event Transfer(address indexed from, address indexed to, uint value);

    event Approval(address indexed owner, address indexed spender, uint value);

    event Burn(address indexedburner, uint value);

    function ROKToken() {
        //100,000,000 ROK tokens
        totalSupply = 100000000;
        // Give the creator all initial tokens
        balances[msg.sender] = totalSupply;
    }

    function burn(uint256 _value) returns (bool){
        require(_value > 0);

        address burner = msg.sender;
        balances[burner] = balances[burner].sub(_value);
        totalSupply = totalSupply.sub(_value);
        Burn(burner, _value);
        return true;
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        require(_to != address(0));
        require(_value <= balances[msg.sender]);

        // SafeMath.sub will throw if there is not enough balance.
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(_to != address(0));
        require(_value <= balances[_from]);
        require(_value <= allowed[_from][msg.sender]);

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        Transfer(_from, _to, _value);
        return true;
    }

    function balanceOf(address _owner) constant returns (uint balance) {
        return balances[_owner];
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) constant returns (uint remaining) {
        return allowed[_owner][_spender];
    }
}
