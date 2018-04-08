pragma solidity 0.4.21;

interface RevToken {
    function swap(uint256 _tokenAmount, address _tokenHolder) external returns(bool success);
}

// Safe Math library that automatically checks for overflows and underflows
library SafeMath {
    // Safe multiplication
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a * b;
        require(a == 0 || c / a == b);
        return c;
    }
    // Safe subtraction
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        return a - b;
    }
    // Safe addition
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c>=a && c>=b);
        return c;
    }
}

// Basic ERC20 functions
contract Token {

    using SafeMath for uint256;

    event Transfer(address indexed from, address indexed to, uint256 value);

    // mapping of all balances
    mapping (address => uint256) public balanceOf;
    // The total supply of the token
    uint256 public totalSupply;

    // Some variables for nice wallet integration
    string public name;          // name of token
    string public symbol;        // symbol of token
    uint8 public decimals;       // decimals of token
}

contract Owned is Token {
    // address of the developers
    address public owner;
    // modifiers: only allows Owner/Pool/Contract to call certain functions
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
    modifier onlyTokenHolder {
        require(balanceOf[msg.sender] > 0);
        _;
    }
}

// DevToken functions which are active during development phase
contract Funding is Owned {

    // maximum supply of the token
    uint256 public maxSupply;
    // maximum stake someone can have of all tokens (in percent)
    uint256 public maxStake;
    // tokens that are being sold per ether
    uint256 public tokensPerEther;

    // lock ETH in contract and return DevTokens
    function () public payable {
        // adds the amount of ETH sent as DevToken value and increases total supply
        balanceOf[msg.sender].add(msg.value.mul(tokensPerEther));
        totalSupply = totalSupply.add(msg.value.mul(tokensPerEther));

        // fails if total supply surpasses maximum supply
        require(totalSupply <= maxSupply);
        // user cannot deposit more than "maxStake"% of the total supply
        require(balanceOf[msg.sender] < totalSupply.mul(maxStake)/100);

        // transfer event
        emit Transfer(address(this), msg.sender, msg.value.mul(tokensPerEther));
    }

    // constant function: return maximum possible investment per person
    function maxInvestment() public view returns(uint256) {
        return totalSupply.mul(maxStake)/100;
    }


    // Get the number of DevTokens that will be sold for 1 ETH
    function getTokenPrice() view public returns(uint _tokensPerEther) {
        // Adjust the token value to variable decimal-counts
        return tokensPerEther.mul(10**(18-uint256(decimals)));
    }

}

contract OwnerAllowance is Funding {
    // time since last use of allowance
    uint256 public allowanceTimeCounter;
    // interval how often allowance is reset
    uint256 public allowanceInterval;
    // allowance amount per interval
    uint256 public allowanceValue;
    // current allowance balance
    uint256 public allowanceBalance;

    // allows owner to withdraw ether in an interval
    function allowanceWithdrawal(uint256 _value) public onlyOwner {
        if (now.sub(allowanceTimeCounter) > allowanceInterval) {
            allowanceBalance = allowanceValue;
            allowanceTimeCounter = now;
        }
        allowanceBalance = allowanceBalance.sub(_value);
        owner.transfer(_value);
    }
}

contract Voting_X is Owned {
    // allows one proposal at a time per person
    mapping(address => uint256) lastProposal_X;
    // duration of voting on a proposal
    uint256 proposalDuration_X;
    // percentage of minimum votes for proposal to get accepted
    uint256 minVotes_X;
    // constructor
    function Voting_X(uint256 _proposalDuration_X, uint256 _minVotes_X) public {}
    // Events
    // creation event
    event ProposalCreation_X(uint256 indexed ID, string indexed description);
    // vote event
    event UserVote_X(uint256 indexed ID, address indexed user, bool indexed value);
    // successful proposal event
    event SuccessfulProposal_X(uint256 indexed ID, string indexed description, uint256 indexed value);
    // rejected proposal event
    event RejectedProposal_X(uint256 indexed ID, string indexed description, string indexed reason);
    // proposal structure
    struct Proposal_X {
        // ID of proposal
        uint256 ID;
        // short name
        string name;
        // description of proposal
        string description;
        // timestamp when poll started
        uint256 start;
        // collects votes
        uint256 yes;
        uint256 no;
        // mapping that saves if user voted
        mapping(address => bool) voted;
        // bool if poll is active
        bool active;
        // bool if proposal was accepted
        bool accepted;
    }
    // array of polls
    Proposal_X[] public proposals_X;
    // propose a new development task
    // appends proposal struct to array
    // emits ProposalCreation_X event
    function propose_X(string _name, string _description) public onlyTokenHolder {}
    // vote on a development task
    // emits UserVote_X event
    function vote(uint256 _ID, bool _vote) public onlyTokenHolder {}
    // end voting for a development task
    // emits SuccessfulProposal_X or RejectedProposal_X Event
    function end(uint256 _ID) public onlyTokenHolder {}

}

// task voting implementation
contract Voting_Task is OwnerAllowance {

    mapping(address => uint256) lastProposal_Task;
    uint256 proposalDuration_Task;
    uint256 minVotes_Task;

    event ProposalCreation_Task(uint256 indexed ID, string indexed description);
    event UserVote_Task(uint256 indexed ID, address indexed user, bool indexed value);
    event SuccessfulProposal_Task(uint256 indexed ID, string indexed description, uint256 indexed value);
    event RejectedProposal_Task(uint256 indexed ID, string indexed description, string indexed reason);

    struct Proposal_Task {
        uint256 ID;
        string name;
        string description;
        // (optional) amount of ETH-reward for development tasks
        uint256 value;
        uint256 start;
        uint256 yes;
        uint256 no;
        mapping(address => bool) voted;
        bool active;
        bool accepted;
        // (optional) bool if proposal was rewarded
        bool rewarded;
    }

    // array of polls
    Proposal_Task[] public proposals_Task;

    function propose(string _name, string _description, uint256 _value) public onlyTokenHolder {

        require(_value > address(this).balance);
        // allows one proposal per week and resets value after successful proposal
        require(now.sub(lastProposal_Task[msg.sender]) > proposalDuration_Task);
        lastProposal_Task[msg.sender] = now;

        // saves ID of proposal which is equal to the array index
        uint256 ID = proposals_Task.length;

        // initializes new proposal as a struct and pushes it into the proposal array
        proposals_Task.push(Proposal_Task({ID: ID, name: _name, description: _description, value: _value, start: now, yes: 0, no: 0, active: true, accepted: false, rewarded: false}));

        // event generated for proposal creation
        emit ProposalCreation_Task(ID, _description);

    }

    // vote on a development task
    function vote(uint256 _ID, bool _vote) public onlyTokenHolder {

        // proposal has to be active
        require(proposals_Task[_ID].active);

        // proposal has to be active less than one week
        if (now.sub(proposals_Task[_ID].start) >= proposalDuration_Task) {
            end(_ID);
        }

        // checks if tokenholder has already voted
        require(!proposals_Task[_ID].voted[msg.sender]);
        // registers vote
        proposals_Task[_ID].voted[msg.sender] = true;

        // if the value is 0 it's considered no
        if (_vote) {
            // registers the balance of msg.sender as a yes vote
            proposals_Task[_ID].yes = proposals_Task[_ID].yes.add(balanceOf[msg.sender]);
        } else {
            // registers the balance of msg.sender as a no vote
            proposals_Task[_ID].no = proposals_Task[_ID].no.add(balanceOf[msg.sender]);
        }
        // event generated for tokenholder vote
        emit UserVote_Task(_ID, msg.sender, _vote);

    }


    // end voting for a development task
    function end(uint256 _ID) public onlyTokenHolder {

        // requires proposal to be running for a week
        require(now.sub(proposals_Task[_ID].start) >= proposalDuration_Task);

        // requires proposal to be active
        require(proposals_Task[_ID].active);
        proposals_Task[_ID].active = false;

        // rejects proposal if not enough people voted on it
        if (proposals_Task[_ID].no.add(proposals_Task[_ID].yes) < (minVotes_Task.mul(totalSupply))/100) {
            // event generation
            emit RejectedProposal_Task(_ID, proposals_Task[_ID].description, "Participation too low");

        // compares yes and no votes
        } else if (proposals_Task[_ID].yes > proposals_Task[_ID].no) {
            proposals_Task[_ID].accepted = true;
            // event generation
            emit SuccessfulProposal_Task(_ID, proposals_Task[_ID].description, proposals_Task[_ID].value);

        } else {
            // event generation
            emit RejectedProposal_Task(_ID, proposals_Task[_ID].description, "Proposal rejected by vote");
        }
    
    }

    function getProposalLength() public view returns(uint256 length) {
        return proposals_Task.length;
    }

    function getProposalName(uint256 _ID) public view returns(string name) {
        return proposals_Task[_ID].name;
    }

    function getProposalDescription(uint256 _ID) public view returns(string description) {
        return proposals_Task[_ID].description;
    }

    function getProposalValue(uint256 _ID) public view returns(uint256 value) {
        return proposals_Task[_ID].value;
    }

    function getProposalStart(uint256 _ID) public view returns(uint256 start) {
        return proposals_Task[_ID].start;
    }

    function getProposalYes(uint256 _ID) public view returns(uint256 yes) {
        return proposals_Task[_ID].yes;
    }

    function getProposalNo(uint256 _ID) public view returns(uint256 no) {
        return proposals_Task[_ID].no;
    }

    function getProposalActive(uint256 _ID) public view returns(bool active) {
        return proposals_Task[_ID].active;
    }

    function getProposalAccepted(uint256 _ID) public view returns(bool accepted) {
        return proposals_Task[_ID].accepted;
    }

    function getProposalRewarded(uint256 _ID) public view returns(bool rewarded) {
        return proposals_Task[_ID].rewarded;
    }
}

contract DevRev is Voting_Task {
    // bool to see if RevToken was set
    bool private set = false;
    address public RevTokenAddress;

    function setRevContract(address _contractAddress) public onlyOwner {
        require(!set && _contractAddress != 0x0);
        set = true;
        RevTokenAddress = _contractAddress;
    }

    function swap(uint256 _tokenAmount) public onlyTokenHolder {
        require(set);
        balanceOf[msg.sender] = balanceOf[msg.sender].sub(_tokenAmount);
        totalSupply = totalSupply.sub(_tokenAmount);
        maxSupply = maxSupply.sub(_tokenAmount);
        require(RevToken(RevTokenAddress).swap(_tokenAmount, msg.sender));
        emit Transfer(msg.sender, RevTokenAddress, _tokenAmount);
    }

}

// DevRevToken combines DevToken and RevToken into one token
contract DevToken is DevRev {
    function DevToken() public {

        // constructor Token
        name = "TEST DEV";
        symbol = "TT";
        require(decimals <= 18);
        decimals = 18;
        // constructor Funding
        owner = msg.sender;
        allowanceTimeCounter = now;
        maxSupply = 100;
        // Adjust the token value to variable decimal-counts
        tokensPerEther = 5/(10**(18 - uint256(decimals)));  //5 ist Token per Ether
        totalSupply = 0;
        require(maxSupply >= totalSupply);
        maxStake = 25;
        // constructor TaskVoting
        proposalDuration_Task = 3600;
        minVotes_Task = 51;
    }
}