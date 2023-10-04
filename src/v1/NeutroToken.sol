// SPDX-License-Identifier: MIT
// UNSAFE: TESTING PURPOSE ONLY
pragma solidity =0.7.6;

import "@openzeppelin/contracts/drafts/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract NeutroToken is ERC20Burnable, ERC20Permit, AccessControl, Pausable {
    using SafeERC20 for IERC20;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant RESCUER_ROLE = keccak256("RESCUER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    uint256 internal constant MAX_TOTAL_SUPPLY = 1000000000 ether; //1 billion

    constructor() ERC20("Neutro Token", "NEUTRO") ERC20Permit("Neutro") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(RESCUER_ROLE, msg.sender);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        require(
            amount + totalSupply() <= MAX_TOTAL_SUPPLY,
            "NeutroToken: Max total supply exceeded"
        );
        _mint(to, amount);
    }

    function getMaxTotalSupply() external view returns (uint256) {
        return MAX_TOTAL_SUPPLY;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }

    function rescueTokens(IERC20 token, uint256 value)
        external
        onlyRole(RESCUER_ROLE)
    {
        token.transfer(msg.sender, value);
    }

    /**
     * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `_msgSender()`
     * is missing `role`. Overriding this function changes the behavior of the {onlyRole} modifier.
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `account`
     * is missing `role`.
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert("NO ROLE");
        }
    }

    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }
    
}
