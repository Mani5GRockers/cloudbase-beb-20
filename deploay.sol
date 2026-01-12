// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
    FIXED SUPPLY TOKEN
    - Total Supply: 1,000,000,000,000 (1 Trillion)
    - Minting: DISABLED (no mint function)
    - Buy Tax: 0% (locked)
    - Sell Tax: 3% (max 5%)
*/

/* ===================== BEP20 INTERFACE ===================== */
interface IBEP20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/* ===================== OWNABLE ===================== */
contract Ownable {
    address public owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), owner);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }
}

/* ===================== TOKEN ===================== */
contract CBI is IBEP20, Ownable {

    /* ---------- TOKEN INFO ---------- */
    string private constant _name = "CLOUDBASEINDIA.COM";
    string private constant _symbol = "CBI";
    uint8  private constant _decimals = 18;

    // FIXED SUPPLY — CANNOT CHANGE
    uint256 private constant _totalSupply =
        1_000_000_000_000 * 10 ** _decimals; // 1 TRILLION

    /* ---------- STORAGE ---------- */
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    /* ---------- TAX (SELL ONLY) ---------- */
    uint256 public sellTax = 3;          // 3% default
    uint256 public constant MAX_TAX = 5; // Max 5%
    address public taxWallet;

    mapping(address => bool) public isDEXPair;
    mapping(address => bool) public isExcludedFromTax;

    /* ---------- CONSTRUCTOR ---------- */
    constructor() {
        _balances[msg.sender] = _totalSupply;
        taxWallet = msg.sender;

        isExcludedFromTax[msg.sender] = true;
        isExcludedFromTax[address(this)] = true;

        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    /* ---------- VIEW FUNCTIONS ---------- */
    function name() external pure returns (string memory) { return _name; }
    function symbol() external pure returns (string memory) { return _symbol; }
    function decimals() external pure returns (uint8) { return _decimals; }
    function totalSupply() external pure returns (uint256) { return _totalSupply; }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner_, address spender) external view returns (uint256) {
        return _allowances[owner_][spender];
    }

    /* ---------- TRANSFERS ---------- */
    function transfer(address recipient, uint256 amount) external returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        uint256 allowed = _allowances[sender][msg.sender];
        require(allowed >= amount, "Allowance exceeded");

        _allowances[sender][msg.sender] = allowed - amount;
        _transfer(sender, recipient, amount);
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0) && recipient != address(0), "Zero address");
        require(_balances[sender] >= amount, "Insufficient balance");

        uint256 taxAmount = 0;

        // SELL TAX ONLY (applies when recipient is a DEX pair)
        if (
            isDEXPair[recipient] &&
            !isExcludedFromTax[sender] &&
            sellTax > 0
        ) {
            taxAmount = (amount * sellTax) / 100;
        }

        uint256 sendAmount = amount - taxAmount;

        _balances[sender] -= amount;
        _balances[recipient] += sendAmount;

        if (taxAmount > 0) {
            _balances[taxWallet] += taxAmount;
            emit Transfer(sender, taxWallet, taxAmount);
        }

        emit Transfer(sender, recipient, sendAmount);
    }

    /* ---------- ADMIN ---------- */
    function setSellTax(uint256 _sell) external onlyOwner {
        require(_sell <= MAX_TAX, "Tax too high");
        sellTax = _sell;
    }

    function setTaxWallet(address wallet) external onlyOwner {
        require(wallet != address(0), "Zero address");
        taxWallet = wallet;
    }

    function addDEXPair(address pair) external onlyOwner {
        require(pair != address(0), "Zero address");
        isDEXPair[pair] = true;
    }

    function removeDEXPair(address pair) external onlyOwner {
        isDEXPair[pair] = false;
    }

    function excludeFromTax(address account, bool excluded) external onlyOwner {
        isExcludedFromTax[account] = excluded;
    }
}
