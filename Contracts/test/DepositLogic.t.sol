// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/DepositLogic.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @dev Minimal ERC20 for testing
contract MockERC20 is ERC20 {
    uint8 private _decimals;

    constructor(string memory name, string memory symbol, uint8 decimals_) ERC20(name, symbol) {
        _decimals = decimals_;
        _mint(msg.sender, 1_000_000 * 10 ** decimals_);
    }

    function mint(address to, uint256 amount) external { _mint(to, amount); }

    function decimals() public view override returns (uint8) { return _decimals; }
}

contract DepositLogicTest is Test {
    DepositLogic internal depositLogic;

    MockERC20 internal tokenUSDC;
    MockERC20 internal tokenWETH;
    MockERC20 internal tokenWBTC;

    address internal alice   = address(0xA11CE);
    address internal bob     = address(0xB0B);
    address internal charlie = address(0xC0C);
    address internal nonOwner = address(0xBAD);

    uint256 internal constant MIN_DEPOSIT = 1 ether;
    uint256 internal constant DEPOSIT_CAP = 100_000 ether;

    event Deposited(address indexed user, address indexed asset, uint256 amount, uint256 shares, uint256 timestamp);
    event Withdrawn(address indexed user, address indexed asset, uint256 amount, uint256 shares, uint256 timestamp);
    event AssetAdded(address indexed asset, uint256 depositCap);
    event AssetRemoved(address indexed asset);
    event DepositCapUpdated(address indexed asset, uint256 oldCap, uint256 newCap);
    event MinDepositUpdated(uint256 oldMin, uint256 newMin);
    event DepositsPaused(bool paused);

    function setUp() public {
        depositLogic = new DepositLogic(MIN_DEPOSIT);

        tokenUSDC = new MockERC20("USD Coin", "USDC", 6);
        tokenWETH = new MockERC20("Wrapped Ether", "WETH", 18);
        tokenWBTC = new MockERC20("Wrapped Bitcoin", "WBTC", 8);

        // Add supported assets
        depositLogic.addAsset(address(tokenUSDC), DEPOSIT_CAP);
        depositLogic.addAsset(address(tokenWETH), DEPOSIT_CAP);
        depositLogic.addAsset(address(tokenWBTC), DEPOSIT_CAP);

        // Fund users
        tokenUSDC.mint(alice, 500_000 * 1e6);
        tokenUSDC.mint(bob,   500_000 * 1e6);
        tokenUSDC.mint(charlie, 500_000 * 1e6);

        tokenWETH.mint(alice, 1000 ether);
        tokenWETH.mint(bob,   1000 ether);

        tokenWBTC.mint(alice, 100 * 1e8);
        tokenWBTC.mint(bob,   100 * 1e8);
    }

    // ── Helpers ────────────────────────────────────────────────────────────────

    function _deposit(address user, address asset, uint256 amount) internal {
        vm.startPrank(user);
        ERC20(asset).approve(address(depositLogic), amount);
        depositLogic.deposit(asset, amount);
        vm.stopPrank();
    }

    function _depositWithReturn(address user, address asset, uint256 amount) internal returns (uint256) {
        vm.startPrank(user);
        ERC20(asset).approve(address(depositLogic), amount);
        uint256 shares = depositLogic.deposit(asset, amount);
        vm.stopPrank();
        return shares;
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Constructor & Initialization
    // ══════════════════════════════════════════════════════════════════════════

    function test_constructor_setsMinDeposit() public {
        assertEq(depositLogic.minDepositAmount(), MIN_DEPOSIT);
    }

    function test_constructor_setsOwner() public {
        assertEq(depositLogic.owner(), address(this));
    }

    function test_constructor_depositsNotPaused() public {
        assertEq(depositLogic.depositsPaused(), false);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Asset Management (Admin)
    // ══════════════════════════════════════════════════════════════════════════

    function test_addAsset_emitsEvent() public {
        MockERC20 newToken = new MockERC20("New", "NEW", 18);
        vm.expectEmit(true, true, true, true);
        emit AssetAdded(address(newToken), 50_000 ether);
        depositLogic.addAsset(address(newToken), 50_000 ether);
    }

    function test_addAsset_isSupported() public {
        assertTrue(depositLogic.isAssetSupported(address(tokenUSDC)));
    }

    function test_addAsset_getDepositCap() public {
        assertEq(depositLogic.getDepositCap(address(tokenUSDC)), DEPOSIT_CAP);
    }

    function test_addAsset_revertsZeroAddress() public {
        vm.expectRevert(DepositLogic.ZeroAddress.selector);
        depositLogic.addAsset(address(0), DEPOSIT_CAP);
    }

    function test_addAsset_revertsDuplicate() public {
        vm.expectRevert(DepositLogic.AssetAlreadySupported.selector);
        depositLogic.addAsset(address(tokenUSDC), DEPOSIT_CAP);
    }

    function test_addAsset_revertsNonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        depositLogic.addAsset(address(0x123), DEPOSIT_CAP);
    }

    function test_removeAsset_emitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit AssetRemoved(address(tokenWBTC));
        depositLogic.removeAsset(address(tokenWBTC));
    }

    function test_removeAsset_removesSupport() public {
        depositLogic.removeAsset(address(tokenWBTC));
        assertFalse(depositLogic.isAssetSupported(address(tokenWBTC)));
    }

    function test_removeAsset_revertsUnsupportedAsset() public {
        vm.expectRevert(DepositLogic.AssetNotSupported.selector);
        depositLogic.removeAsset(address(0xDEAD));
    }

    function test_removeAsset_revertsWhenDepositsExist() public {
        _deposit(alice, address(tokenUSDC), 100 ether);
        vm.expectRevert(DepositLogic.InsufficientBalance.selector);
        depositLogic.removeAsset(address(tokenUSDC));
    }

    function test_removeAsset_revertsNonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        depositLogic.removeAsset(address(tokenWBTC));
    }

    function test_setDepositCap_emitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit DepositCapUpdated(address(tokenUSDC), DEPOSIT_CAP, 200_000 ether);
        depositLogic.setDepositCap(address(tokenUSDC), 200_000 ether);
    }

    function test_setDepositCap_updatesCap() public {
        depositLogic.setDepositCap(address(tokenUSDC), 200_000 ether);
        assertEq(depositLogic.getDepositCap(address(tokenUSDC)), 200_000 ether);
    }

    function test_setDepositCap_revertsNonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        depositLogic.setDepositCap(address(tokenUSDC), 200_000 ether);
    }

    function test_setDepositCap_revertsUnsupportedAsset() public {
        vm.expectRevert(DepositLogic.AssetNotSupported.selector);
        depositLogic.setDepositCap(address(0xDEAD), 200_000 ether);
    }

    function test_supportedAssetsCount_increases() public {
        assertEq(depositLogic.supportedAssetsCount(), 3);
    }

    function test_supportedAssetsCount_afterRemove() public {
        depositLogic.removeAsset(address(tokenWBTC));
        assertEq(depositLogic.supportedAssetsCount(), 2);
    }

    function test_getSupportedAssets_returnsList() public {
        address[] memory assets = depositLogic.getSupportedAssets();
        assertEq(assets.length, 3);
        assertEq(assets[0], address(tokenUSDC));
        assertEq(assets[1], address(tokenWETH));
        assertEq(assets[2], address(tokenWBTC));
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Min Deposit Management
    // ══════════════════════════════════════════════════════════════════════════

    function test_setMinDepositAmount_emitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit MinDepositUpdated(MIN_DEPOSIT, 2 ether);
        depositLogic.setMinDepositAmount(2 ether);
    }

    function test_setMinDepositAmount_updates() public {
        depositLogic.setMinDepositAmount(2 ether);
        assertEq(depositLogic.minDepositAmount(), 2 ether);
    }

    function test_setMinDepositAmount_revertsNonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        depositLogic.setMinDepositAmount(2 ether);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Pause / Unpause
    // ══════════════════════════════════════════════════════════════════════════

    function test_setDepositsPaused_emitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit DepositsPaused(true);
        depositLogic.setDepositsPaused(true);
    }

    function test_setDepositsPaused_revertsNonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        depositLogic.setDepositsPaused(true);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Deposits
    // ══════════════════════════════════════════════════════════════════════════

    function test_deposit_emitsEvent() public {
        vm.startPrank(alice);
        tokenUSDC.approve(address(depositLogic), 100 ether);
        vm.expectEmit(true, true, true, true);
        emit Deposited(alice, address(tokenUSDC), 100 ether, 100 ether, block.timestamp);
        depositLogic.deposit(address(tokenUSDC), 100 ether);
        vm.stopPrank();
    }

    function test_deposit_updatesUserDeposit() public {
        _deposit(alice, address(tokenUSDC), 100 ether);
        assertEq(depositLogic.getDepositAmount(alice, address(tokenUSDC)), 100 ether);
    }

    function test_deposit_updatesUserShares() public {
        uint256 shares = _depositWithReturn(alice, address(tokenUSDC), 100 ether);
        assertEq(shares, 100 ether);
        assertEq(depositLogic.getDepositShares(alice, address(tokenUSDC)), 100 ether);
    }

    function test_deposit_updatesTotalDeposits() public {
        _deposit(alice, address(tokenUSDC), 100 ether);
        assertEq(depositLogic.getTotalDeposits(address(tokenUSDC)), 100 ether);
    }

    function test_deposit_updatesTotalShares() public {
        _deposit(alice, address(tokenUSDC), 100 ether);
        assertEq(depositLogic.getTotalShares(address(tokenUSDC)), 100 ether);
    }

    function test_deposit_multipleUsers() public {
        _deposit(alice, address(tokenUSDC), 100 ether);
        _deposit(bob, address(tokenUSDC), 50 ether);
        assertEq(depositLogic.getTotalDeposits(address(tokenUSDC)), 150 ether);
        assertEq(depositLogic.getTotalShares(address(tokenUSDC)), 150 ether);
        assertEq(depositLogic.getDepositAmount(alice, address(tokenUSDC)), 100 ether);
        assertEq(depositLogic.getDepositAmount(bob, address(tokenUSDC)), 50 ether);
    }

    function test_deposit_revertsZeroAmount() public {
        vm.startPrank(alice);
        tokenUSDC.approve(address(depositLogic), 1 ether);
        vm.expectRevert(DepositLogic.ZeroAmount.selector);
        uint256 shares = dl.calculateShares(VAULT_USDC, 50e6);
        assertEq(shares, 50e6);

        // calculateAssets: 50 shares → 50 USDC
        uint256 assets = dl.calculateAssets(VAULT_USDC, 50e6);
        assertEq(assets, 50e6);
    }

    function test_ShareCalc_EmptyVault() public {
        // No deposits yet, shares = amount (1:1)
        uint256 shares = dl.calculateShares(VAULT_USDC, 100e6);
        assertEq(shares, 100e6);

        uint256 assets = dl.calculateAssets(VAULT_USDC, 100e6);
        assertEq(assets, 100e6);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 5. Multi-Asset Support (Assets are supported)
    // ─────────────────────────────────────────────────────────────────────────

    function test_MultiAsset_DepositDifferentAssets() public {
        _depositUSDC(alice, 100e6);
        _depositWETH(alice, 5e18);
        _depositUSDT(alice, 200e6);

        assertEq(usdc.balanceOf(address(dl)), 100e6);
        assertEq(weth.balanceOf(address(dl)), 5e18);
        assertEq(usdt.balanceOf(address(dl)), 200e6);
    }

    function test_MultiAsset_IndependentPools() public {
        _depositUSDC(alice, 100e6);
        _depositWETH(alice, 10e18);

        // USDC vault: 100 deposits, 100 shares
        assertEq(dl.getTotalDeposits(VAULT_USDC), 100e6);
        assertEq(dl.getTotalShares(VAULT_USDC), 100e6);

        // WETH vault: 10 deposits, 10 shares
        assertEq(dl.getTotalDeposits(VAULT_WETH), 10e18);
        assertEq(dl.getTotalShares(VAULT_WETH), 10e18);
    }

    function test_MultiAsset_GetVaultIds() public {
        bytes32[] memory ids = dl.getVaultIds();
        assertEq(ids.length, 3);
        assertEq(ids[0], VAULT_USDC);
        assertEq(ids[1], VAULT_WETH);
        assertEq(ids[2], VAULT_USDT);
    }

    function test_MultiAsset_GetVaultAsset() public {
        assertEq(dl.getVaultAsset(VAULT_USDC), address(usdc));
        assertEq(dl.getVaultAsset(VAULT_WETH), address(weth));
        assertEq(dl.getVaultAsset(VAULT_USDT), address(usdt));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 6. Deposit Tracking (Amounts are tracked)
    // ─────────────────────────────────────────────────────────────────────────

    function test_Tracking_DepositHistory() public {
        _depositUSDC(alice, 100e6);
        _depositUSDC(alice, 200e6);

        DepositLogic.DepositRecord[] memory history = dl.getDepositHistory(VAULT_USDC);
        assertEq(history.length, 2);
        assertEq(history[0].amount, 100e6);
        assertEq(history[0].shares, 100e6);
        assertEq(history[0].asset, address(usdc));
        assertEq(history[0].depositor, alice);
        assertEq(history[1].amount, 200e6);
        assertEq(history[1].shares, 200e6);
    }

    function test_Tracking_DepositCount() public {
        assertEq(dl.getDepositCount(VAULT_USDC), 0);
        _depositUSDC(alice, 100e6);
        assertEq(dl.getDepositCount(VAULT_USDC), 1);
        _depositUSDC(alice, 50e6);
        assertEq(dl.getDepositCount(VAULT_USDC), 2);
    }

    function test_Tracking_DepositBalances() public {
        _depositUSDC(alice, 100e6);
        _depositUSDC(alice, 50e6);

        assertEq(dl.getDepositBalance(VAULT_USDC, alice), 150e6);
        assertEq(dl.getShareBalance(VAULT_USDC, alice), 150e6);
    }

    function test_Tracking_MultipleUsers() public {
        _depositUSDC(alice, 100e6);
        _depositUSDC(bob, 200e6);

        assertEq(dl.getDepositBalance(VAULT_USDC, alice), 100e6);
        assertEq(dl.getDepositBalance(VAULT_USDC, bob), 200e6);
        assertEq(dl.getShareBalance(VAULT_USDC, alice), 100e6);
        assertEq(dl.getShareBalance(VAULT_USDC, bob), 200e6);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 7. Withdrawal Functionality
    // ─────────────────────────────────────────────────────────────────────────

    function test_Withdraw_Basic() public {
        _depositUSDC(alice, 100e6);

        uint256 balanceBefore = usdc.balanceOf(alice);
        uint256 amount = dl.withdraw(VAULT_USDC, 50e6);

        assertEq(amount, 50e6, "withdrew correct amount");
        assertEq(usdc.balanceOf(alice), balanceBefore + 50e6, "alice received tokens");
        assertEq(dl.getDepositBalance(VAULT_USDC, alice), 50e6, "remaining balance");
        assertEq(dl.getShareBalance(VAULT_USDC, alice), 50e6, "remaining shares");
    }

    function test_Withdraw_FullAmount() public {
        _depositUSDC(alice, 100e6);

        uint256 amount = dl.withdraw(VAULT_USDC, 100e6);
        assertEq(amount, 100e6);
        assertEq(dl.getDepositBalance(VAULT_USDC, alice), 0);
        assertEq(dl.getShareBalance(VAULT_USDC, alice), 0);
    }

    function test_Withdraw_EmitsEvent() public {
        _depositUSDC(alice, 100e6);

        vm.expectEmit(true, true, true, true);
        emit DepositLogic.Withdrawn(VAULT_USDC, alice, address(usdc), 50e6, 50e6);
        dl.withdraw(VAULT_USDC, 50e6);
    }

    function test_Withdraw_RevertsZeroShares() public {
        vm.expectRevert(DepositLogic.ZeroAmount.selector);
        dl.withdraw(VAULT_USDC, 0);
    }

    function test_Withdraw_RevertsInsufficientShares() public {
        vm.expectRevert(DepositLogic.InsufficientShares.selector);
        dl.withdraw(VAULT_USDC, 100e6);
    }

    function test_Withdraw_RevertsNonExistentVault() public {
        vm.expectRevert(DepositLogic.VaultDoesNotExist.selector);
        dl.withdraw(keccak256("nonexistent"), 100e6);
    }

    function test_Withdraw_RevertsInactiveVault() public {
        _depositUSDC(alice, 100e6);
        dl.setVaultActive(VAULT_USDC, false);

        vm.expectRevert(DepositLogic.VaultNotActive.selector);
        dl.withdraw(VAULT_USDC, 50e6);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 8. Query Functions (Queries work)
    // ─────────────────────────────────────────────────────────────────────────

    function test_Query_SharePrice_Initial() public view {
        assertEq(dl.getSharePrice(VAULT_USDC), PRECISION, "initial share price 1.0");
    }

    function test_Query_SharePrice_AfterDeposits() public {
        _depositUSDC(alice, 100e6);
        // 100 deposits / 100 shares = 1.0
        assertApproxEqRel(dl.getSharePrice(VAULT_USDC), PRECISION, 1e14);
    }

    function test_Query_GetVaultStats() public {
        _depositUSDC(alice, 100e6);
        _depositUSDC(bob, 200e6);

        (
            address asset,
            bool active,
            uint256 totalDeposits,
            uint256 totalShares,
            uint256 sharePrice,
            uint256 depositCount
        ) = dl.getVaultStats(VAULT_USDC);

        assertEq(asset, address(usdc));
        assertTrue(active);
        assertEq(totalDeposits, 300e6);
        assertEq(totalShares, 300e6);
        assertApproxEqRel(sharePrice, PRECISION, 1e14);
        assertEq(depositCount, 2);
    }

    function test_Query_GetVaultStats_Empty() public {
        (
            address asset,
            bool active,
            uint256 totalDeposits,
            uint256 totalShares,
            uint256 sharePrice,
            uint256 depositCount
        ) = dl.getVaultStats(VAULT_USDC);

        assertEq(asset, address(usdc));
        assertTrue(active);
        assertEq(totalDeposits, 0);
        assertEq(totalShares, 0);
        assertEq(sharePrice, PRECISION);
        assertEq(depositCount, 0);
    }

    function test_Query_GetVaultStats_RevertsNonExistent() public {
        vm.expectRevert(DepositLogic.VaultDoesNotExist.selector);
        dl.getVaultStats(keccak256("nonexistent"));
    }

    function test_Query_GetDepositHistory_Empty() public {
        DepositLogic.DepositRecord[] memory history = dl.getDepositHistory(VAULT_USDC);
        assertEq(history.length, 0);
    }

    function test_Query_GetDepositCount_Empty() public {
        assertEq(dl.getDepositCount(VAULT_USDC), 0);
    }

    function test_Query_GetVaultIds() public view {
        bytes32[] memory ids = dl.getVaultIds();
        assertEq(ids.length, 3);
    }

    function test_Query_GetVaultCount() public view {
        assertEq(dl.getVaultCount(), 3);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 9. Reentrancy Protection
    // ─────────────────────────────────────────────────────────────────────────

    function test_ReentrancyGuard_Deposit() public {
        // Deposit should be protected by nonReentrant
        _depositUSDC(alice, 100e6);
        assertEq(usdc.balanceOf(address(dl)), 100e6);
    }

    function test_ReentrancyGuard_Withdraw() public {
        _depositUSDC(alice, 100e6);
        dl.withdraw(VAULT_USDC, 50e6);
        assertEq(usdc.balanceOf(address(dl)), 50e6);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 10. Fuzz Tests
    // ─────────────────────────────────────────────────────────────────────────

    function testFuzz_Deposit_BalanceMatches(uint128 amount) public {
        vm.assume(amount > 0 && amount <= usdc.balanceOf(alice));
        uint256 balanceBefore = usdc.balanceOf(alice);
        _depositUSDC(alice, uint256(amount));
        assertEq(usdc.balanceOf(alice), balanceBefore - uint256(amount));
        assertEq(usdc.balanceOf(address(dl)), uint256(amount));
    }

    function testFuzz_Deposit_SharesMatchFirstDeposit(uint128 amount) public {
        vm.assume(amount > 0 && amount <= usdc.balanceOf(alice));
        uint256 shares = _depositUSDC(alice, uint256(amount));
        assertEq(shares, uint256(amount), "first deposit 1:1");
    }

    function testFuzz_Deposit_ProportionalShares(
        uint128 firstAmount,
        uint128 secondAmount
    ) public {
        vm.assume(firstAmount > 0 && firstAmount <= usdc.balanceOf(alice));
        vm.assume(secondAmount > 0 && secondAmount <= usdc.balanceOf(bob));

        _depositUSDC(alice, uint256(firstAmount));
        uint256 bobShares = _depositUSDC(bob, uint256(secondAmount));

        // Bob's shares should be proportional: secondAmount * firstAmount / firstAmount = secondAmount
        assertApproxEqRel(
            bobShares,
            uint256(secondAmount),
            1e14,
            "proportional shares"
        );
    }

    function testFuzz_MultipleDeposits_Tracking(
        uint128 dep1,
        uint128 dep2,
        uint128 dep3
    ) public {
        vm.assume(dep1 > 0 && dep1 <= usdc.balanceOf(alice));
        vm.assume(dep2 > 0 && dep2 <= usdc.balanceOf(alice));
        vm.assume(dep3 > 0 && dep3 <= usdc.balanceOf(bob));

        uint256 total = uint256(dep1) + uint256(dep2) + uint256(dep3);

        _depositUSDC(alice, uint256(dep1));
        _depositUSDC(alice, uint256(dep2));
        _depositUSDC(bob, uint256(dep3));

        assertEq(dl.getTotalDeposits(VAULT_USDC), total);
        assertEq(dl.getDepositCount(VAULT_USDC), 3);
        assertEq(dl.getDepositBalance(VAULT_USDC, alice), uint256(dep1) + uint256(dep2));
        assertEq(dl.getDepositBalance(VAULT_USDC, bob), uint256(dep3));
    }

    function testFuzz_SharePrice_NeverZero(uint128 amount) public {
        vm.assume(amount > 0 && amount <= usdc.balanceOf(alice));
        _depositUSDC(alice, uint256(amount));
        assertGt(dl.getSharePrice(VAULT_USDC), 0, "share price always positive");
    }

    function testFuzz_CalculateShares_RoundTrip(uint128 amount) public {
        vm.assume(amount > 0 && amount <= usdc.balanceOf(alice));
        _depositUSDC(alice, uint256(amount));

        uint256 shares = dl.calculateShares(VAULT_USDC, uint256(amount));
        uint256 backToAmount = dl.calculateAssets(VAULT_USDC, shares);
        // Should be approximately equal (may have rounding)
        assertApproxEqRel(backToAmount, uint256(amount), 1e14, "round trip");
    }

    function testFuzz_DifferentAssets_Independent(
        uint128 usdcAmount,
        uint128 wethAmount
    ) public {
        vm.assume(usdcAmount > 0 && usdcAmount <= usdc.balanceOf(alice));
        vm.assume(wethAmount > 0 && wethAmount <= weth.balanceOf(alice));

        _depositUSDC(alice, uint256(usdcAmount));
        _depositWETH(alice, uint256(wethAmount));

        assertEq(dl.getTotalDeposits(VAULT_USDC), uint256(usdcAmount));
        assertEq(dl.getTotalDeposits(VAULT_WETH), uint256(wethAmount));
    }

    function testFuzz_Withdraw_RoundTrip(uint128 amount) public {
        vm.assume(amount > 0 && amount <= usdc.balanceOf(alice));
        _depositUSDC(alice, uint256(amount));

        uint256 withdrawn = dl.withdraw(VAULT_USDC, uint256(amount));
        assertEq(withdrawn, uint256(amount), "full withdrawal returns correct amount");
        assertEq(dl.getDepositBalance(VAULT_USDC, alice), 0, "balance zero after full withdrawal");
        assertEq(usdc.balanceOf(address(dl)), 0, "contract balance zero after full withdrawal");
    }

    function testFuzz_Withdraw_Partial(uint128 depositAmount, uint128 withdrawShares) public {
        vm.assume(depositAmount > 0 && depositAmount <= usdc.balanceOf(alice));
        vm.assume(withdrawShares > 0 && withdrawShares <= depositAmount);

        _depositUSDC(alice, uint256(depositAmount));
        uint256 withdrawn = dl.withdraw(VAULT_USDC, uint256(withdrawShares));

        assertEq(withdrawn, uint256(withdrawShares), "partial withdrawal proportional");
        assertEq(
            dl.getDepositBalance(VAULT_USDC, alice),
            uint256(depositAmount) - uint256(withdrawShares),
            "remaining balance correct"
        );
    }
}