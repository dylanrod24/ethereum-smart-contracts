pragma solidity ^0.5.0;

import "./erc20.sol";

contract Token is ERC20 {
    string public name = "Token";
    string public symbol = "TKN";
    uint public decimals = 0; // There's usually 18 decimal places

    uint public supply;
    address public founder;

    mapping(address => uint) public balances;

    mapping(address => mapping(address => uint)) allowed;

    constructor() public {
        supply = 1000000;
        founder = msg.sender;
        balances[founder] = supply;
    }

    function allowance(address tokenOwner, address spender) public view returns (uint) {
        return allowed[tokenOwner][spender];
    }

    function approve(address spender, uint tokens) public returns (bool) {
        require(balances[msg.sender] >= tokens);
        require(tokens > 0);

        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        return true;
    }

    function transferFrom(address from, address to, uint tokens) public returns (bool) {
        require(allowed[from][to] >= tokens);
        require(balances[from] >= tokens);

        balances[from] -= tokens;
        balances[to] += tokens;

        return true;
    }

    function totalSupply() public view returns (uint) {
        return supply;
    }

    function balanceOf(address tokenOwner) public view returns (uint balance) {
        return balances[tokenOwner];
    }

    function transfer(address to, uint tokens) public returns (bool success) {
        require(balances[msg.sender] >= tokens && tokens > 0);

        balances[to] += tokens;
        balances[msg.sender] -= tokens;
        emit Transfer(msg.sender, to, tokens);
        return true;
    }

}

contract TokenIco is Token {
    address public admin;
    address payable public deposit;

// Token price in wei: 1TKN = 0.001 Ether, 1 Ether = 1000 TKN
    uint tokenPrice = 1000000000000000;

    // 300 Ether in wei
    uint hardCap = 300000000000000000000;

    uint public raisedAmount;

    uint public saleStart = now;
    uint public saleEnd = now + 604800; // One week
    uint public tokenTradeStart = saleEnd + 604800; // Transferable in a week after saleEnd

    uint public maxInvestment = 5000000000000000000;
    uint public minInvestment = 10000000000000000;

    enum State { beforeStart, running, afterEnd, halted }
    State public icoState;

    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    modifier tokensLocked() {
        require(block.timestamp > tokenTradeStart);
        _;
    }

    event Invest(address investor, uint value, uint tokens);

    constructor(address payable _deposit) public {
        deposit = _deposit;
        admin = msg.sender;
        icoState = State.beforeStart;
    }

    // Emergency stop
    function halt() public onlyAdmin {
        icoState = State.halted;
    }

    // Restart
    function unhalt() public onlyAdmin {
        icoState = State.running;
    }

    function changeDepositAddress(address payable newDeposit) public onlyAdmin {
        deposit = newDeposit;
    }

    function getCurrentState() public view returns (State) {
        if(icoState == State.halted) {
            return State.halted;
        } else if(block.timestamp < saleStart) {
            return State.beforeStart;
        } else if(block.timestamp >= saleStart && block.timestamp <= saleEnd) {
            return State.running;
        } else {
            return State.afterEnd;
        }
    }

    function invest() public payable returns (bool) {
        // Invest only in running state
        icoState = getCurrentState();
        require(icoState == State.running);

        require(msg.value >= minInvestment && msg.value <= maxInvestment);

        uint tokens = msg.value / tokenPrice;

        // Hardcap not reached
        require(raisedAmount + msg.value <= hardCap);

        raisedAmount += msg.value;

        // Add tokens to investor balance from founder balance
        balances[msg.sender] += tokens;
        balances[founder] -= tokens;

        deposit.transfer(msg.value); // Transfer eth to the deposit address

        emit Invest(msg.sender, msg.value, tokens);

        return true;
    }

    function burn() public returns (bool) {
        icoState = getCurrentState();
        require(icoState == State.afterEnd);
        balances[founder] = 0;
    }

    function () external payable {
        invest();
    }

    function transfer(address to, uint value) public tokensLocked returns (bool) {
        super.transfer(to, value);
    }

    function transferFrom(address _from, address _to, uint _value) public tokensLocked returns (bool) {
        super.transferFrom(_from, _to, _value);
    }
}