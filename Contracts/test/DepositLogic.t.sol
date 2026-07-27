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
        depositLogic.deposit(address(tokenUSDC), 0);
        vm.stopPrank();
    }

    function test_deposit_revertsBelowMin() public {
        vm.startPrank(alice);
        tokenUSDC.approve(address(depositLogic), 1 ether);
        vm.expectRevert(DepositLogic.DepositTooSmall.selector);
        depositLogic.deposit(address(tokenUSDC), 0.5 ether);
        vm.stopPrank();
    }

    function test_deposit_revertsUnsupportedAsset() public {
        vm.startPrank(alice);
        tokenUSDC.approve(address(depositLogic), 100 ether);
        vm.expectRevert(DepositLogic.AssetNotSupported.selector);
        depositLogic.deposit(address(0xDEAD), 100 ether);
        vm.stopPrank();
    }

    function test_deposit_revertsWhenPaused() public {
        depositLogic.setDepositsPaused(true);
        vm.startPrank(alice);
        tokenUSDC.approve(address(depositLogic), 100 ether);
        vm.expectRevert(DepositLogic.DepositsPaused.selector);
        depositLogic.deposit(address(tokenUSDC), 100 ether);
        vm.stopPrank();
    }

    function test_deposit_revertsCapExceeded() public {
        depositLogic.setDepositCap(address(tokenUSDC), 200 ether);
        _deposit(alice, address(tokenUSDC), 150 ether);
        vm.startPrank(bob);
        tokenUSDC.approve(address(depositLogic), 100 ether);
        vm.expectRevert(DepositLogic.DepositCapExceeded.selector);
        depositLogic.deposit(address(tokenUSDC), 100 ether);
        vm.stopPrank();
    }

    function test_deposit_transfersTokens() public {
        uint256 before = tokenUSDC.balanceOf(alice);
        _deposit(alice, address(tokenUSDC), 100 ether);
        assertEq(tokenUSDC.balanceOf(alice), before - 100 ether);
        assertEq(tokenUSDC.balanceOf(address(depositLogic)), 100 ether);
    }

    function test_deposit_multipleAssets() public {
        _deposit(alice, address(tokenUSDC), 100 ether);
        _deposit(alice, address(tokenWETH), 10 ether);
        _deposit(alice, address(tokenWBTC), 1 * 1e8);

        assertEq(depositLogic.getDepositAmount(alice, address(tokenUSDC)), 100 ether);
        assertEq(depositLogic.getDepositAmount(alice, address(tokenWETH)), 10 ether);
        assertEq(depositLogic.getDepositAmount(alice, address(tokenWBTC)), 1 * 1e8);
    }

    function test_deposit_multipleDepositsAccumulate() public {
        _deposit(alice, address(tokenUSDC), 100 ether);
        _deposit(alice, address(tokenUSDC), 50 ether);
        assertEq(depositLogic.getDepositAmount(alice, address(tokenUSDC)), 150 ether);
        DepositLogic.AssetPosition memory bobPos = depositLogic.getAssetPosition(address(tokenUSDC), bob);
        assertEq(bobPos.totalDeposited, amount);
        assertEq(bobPos.shares, shares);
        DepositLogic.AssetPosition memory alicePos = depositLogic.getAssetPosition(address(tokenUSDC), alice);
        assertEq(alicePos.totalDeposited, 0);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // 4. Deposit Tracking (Amounts are tracked)
    // ══════════════════════════════════════════════════════════════════════════

    function test_tracking_depositRecordCreated() public {
        _deposit(alice, address(tokenUSDC), 1_000e6);
        DepositLogic.DepositRecord[] memory history = depositLogic.getDepositHistory(alice);
        assertEq(history.length, 1);
        assertEq(history[0].token, address(tokenUSDC));
        assertEq(history[0].assets, 1_000e6);
        assertEq(history[0].timestamp, block.timestamp);
    }

    function test_tracking_multipleRecords() public {
        _deposit(alice, address(tokenUSDC), 1_000e6);
        _deposit(alice, address(tokenWETH), 5 ether);
        _deposit(alice, address(tokenUSDC), 500e6);

        DepositLogic.DepositRecord[] memory history = depositLogic.getDepositHistory(alice);
        assertEq(history.length, 3);
        assertEq(history[0].assets, 1_000e6);
        assertEq(history[0].token, address(tokenUSDC));
        assertEq(history[1].assets, 5 ether);
        assertEq(history[1].token, address(tokenWETH));
        assertEq(history[2].assets, 500e6);
        assertEq(history[2].token, address(tokenUSDC));
    }

    function test_tracking_depositCount() public {
        assertEq(depositLogic.depositCount(alice), 0);
        _deposit(alice, address(tokenUSDC), 1_000e6);
        assertEq(depositLogic.depositCount(alice), 1);
        _deposit(alice, address(tokenUSDC), 500e6);
        assertEq(depositLogic.depositCount(alice), 2);
    }

    function test_tracking_assetPosition() public {
        DepositLogic.AssetPosition memory pos = depositLogic.getAssetPosition(address(tokenUSDC), alice);
        assertEq(pos.totalDeposited, 0);
        assertEq(pos.totalWithdrawn, 0);
        assertEq(pos.shares, 0);

        _deposit(alice, address(tokenUSDC), 1_000e6);
        pos = depositLogic.getAssetPosition(address(tokenUSDC), alice);
        assertEq(pos.totalDeposited, 1_000e6);
        assertEq(pos.shares, 1_000e6 - 1000);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // 5. Share Calculation (Shares are calculated)
    // ══════════════════════════════════════════════════════════════════════════

    function test_shares_firstDepositOneToOneMinusMinimum() public {
        uint256 shares = _deposit(alice, address(tokenUSDC), 1_000e6);
        // First deposit: 1:1 minus MINIMUM_SHARES (1000)
        assertEq(shares, 1_000e6 - 1000, "first deposit 1:1 minus minimum shares");
    }

    function test_shares_subsequentDepositsProRata() public {
        _deposit(alice, address(tokenUSDC), 1_000e6);
        uint256 bobShares = _deposit(bob, address(tokenUSDC), 500e6);
        // After first deposit: assetSupply = 1_000e6 - 1000, assetTVL = 1_000e6
        // bobShares = 500e6 * (1_000e6 - 1000) / 1_000e6 = 500e6 - 500
        assertEq(bobShares, 500e6 - 500, "subsequent deposit pro-rata");
    }

    function test_shares_previewDeposit() public {
        _deposit(alice, address(tokenUSDC), 1_000e6);
        uint256 previewed = depositLogic.previewDeposit(address(tokenUSDC), 500e6);
        // After first deposit: assetSupply = 1_000e6 - 1000, assetTVL = 1_000e6
        // preview = 500e6 * (1_000e6 - 1000) / 1_000e6 = 500e6 - 500
        assertEq(previewed, 500e6 - 500, "preview after deposits");
    }

    function test_shares_previewDeposit_firstDeposit() public {
        uint256 previewed = depositLogic.previewDeposit(address(tokenUSDC), 1_000e6);
        // First deposit: 1:1 minus MINIMUM_SHARES
        assertEq(previewed, 1_000e6 - 1000, "preview first deposit");
    }

    function test_shares_previewRedeem() public {
        _deposit(alice, address(tokenUSDC), 1_000e6);
        uint256 aliceShares = depositLogic.getAssetPosition(address(tokenUSDC), alice).shares;
        uint256 previewed = depositLogic.previewRedeem(address(tokenUSDC), aliceShares);
        assertEq(previewed, 1_000e6, "preview redeem returns original assets");
    }

    function test_shares_pricePerShare() public {
        // Before any deposits: pricePerShare = PRECISION (1e18)
        assertEq(depositLogic.pricePerShare(address(tokenUSDC)), 1e18);

        _deposit(alice, address(tokenUSDC), 1_000e6);
        // After deposit: supply = 1_000e6 - 1000, TVL = 1_000e6
        // pps = 1_000e6 * 1e18 / (1_000e6 - 1000) ≈ 1e18 + small
        assertGt(depositLogic.pricePerShare(address(tokenUSDC)), 1e18);
    }

    function test_shares_multipleAssetsIndependent() public {
        _deposit(alice, address(tokenUSDC), 1_000e6);
        _deposit(alice, address(tokenWETH), 10 ether);
        uint256 usdcPreview = depositLogic.previewDeposit(address(tokenUSDC), 500e6);
        uint256 wethPreview = depositLogic.previewDeposit(address(tokenWETH), 5 ether);
        assertTrue(usdcPreview > 0, "USDC preview independent");
        assertTrue(wethPreview > 0, "WETH preview independent");
    }

    // ══════════════════════════════════════════════════════════════════════════
    // 6. Multi-Asset Support (Assets are supported)
    // ══════════════════════════════════════════════════════════════════════════

    function test_multiAsset_depositUSDC() public {
        uint256 shares = _deposit(alice, address(tokenUSDC), 1_000e6);
        assertGt(shares, 0);
        DepositLogic.AssetPosition memory pos = depositLogic.getAssetPosition(address(tokenUSDC), alice);
        assertEq(pos.totalDeposited, 1_000e6);
    }

    function test_multiAsset_depositWETH() public {
        uint256 shares = _deposit(alice, address(tokenWETH), 5 ether);
        assertGt(shares, 0);
        DepositLogic.AssetPosition memory pos = depositLogic.getAssetPosition(address(tokenWETH), alice);
        assertEq(pos.totalDeposited, 5 ether);
    }

    function test_multiAsset_depositWBTC() public {
        uint256 wbtcAmount = 10 * 1e8;
        uint256 shares = _deposit(alice, address(tokenWBTC), wbtcAmount);
        assertGt(shares, 0);
        DepositLogic.AssetPosition memory pos = depositLogic.getAssetPosition(address(tokenWBTC), alice);
        assertEq(pos.totalDeposited, wbtcAmount);
    }

    function test_multiAsset_depositAllAssets() public {
        _deposit(alice, address(tokenUSDC), 1_000e6);
        _deposit(alice, address(tokenWETH), 5 ether);
        _deposit(alice, address(tokenWBTC), 10 * 1e8);

        assertEq(depositLogic.getAssetPosition(address(tokenUSDC), alice).totalDeposited, 1_000e6);
        assertEq(depositLogic.getAssetPosition(address(tokenWETH), alice).totalDeposited, 5 ether);
        assertEq(depositLogic.getAssetPosition(address(tokenWBTC), alice).totalDeposited, 10 * 1e8);
    }

    function test_multiAsset_assetTVL() public {
        _deposit(alice, address(tokenUSDC), 1_000e6);
        _deposit(bob, address(tokenUSDC), 500e6);
        assertEq(depositLogic.assetTVL(address(tokenUSDC)), 1_500e6);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // 7. Withdrawal Logic
    // ══════════════════════════════════════════════════════════════════════════

    function test_withdraw_fullWithdrawal() public {
        _deposit(alice, address(tokenUSDC), 1_000e6);
        uint256 aliceShares = depositLogic.getAssetPosition(address(tokenUSDC), alice).shares;
        uint256 balanceBefore = tokenUSDC.balanceOf(alice);

        vm.prank(alice);
        uint256 assets = depositLogic.withdraw(address(tokenUSDC), aliceShares, alice);

        assertEq(assets, 1_000e6);
        assertEq(tokenUSDC.balanceOf(alice), balanceBefore + 1_000e6);
        assertEq(tokenUSDC.balanceOf(address(depositLogic)), 0);
    }

    function test_withdraw_partialWithdrawal() public {
        _deposit(alice, address(tokenUSDC), 1_000e6);
        uint256 aliceShares = depositLogic.getAssetPosition(address(tokenUSDC), alice).shares;
        uint256 halfShares = aliceShares / 2;

        vm.prank(alice);
        uint256 assets = depositLogic.withdraw(address(tokenUSDC), halfShares, alice);

        assertEq(assets, 500e6);
        assertEq(tokenUSDC.balanceOf(address(depositLogic)), 500e6);
        DepositLogic.AssetPosition memory pos = depositLogic.getAssetPosition(address(tokenUSDC), alice);
        assertEq(pos.shares, halfShares);
    }

    function test_withdraw_updatesState() public {
        _deposit(alice, address(tokenUSDC), 1_000e6);
        uint256 aliceShares = depositLogic.getAssetPosition(address(tokenUSDC), alice).shares;

        vm.prank(alice);
        depositLogic.withdraw(address(tokenUSDC), aliceShares, alice);

        assertEq(depositLogic.assetTotalDeposited(address(tokenUSDC)), 0);
        assertEq(depositLogic.assetTotalShares(address(tokenUSDC)), 0);
        assertEq(depositLogic.totalValueLocked(), 0);
    }

    function test_withdraw_revertsInsufficientShares() public {
        _deposit(alice, address(tokenUSDC), 500e6);
        uint256 aliceShares = depositLogic.getAssetPosition(address(tokenUSDC), alice).shares;

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                DepositLogic.InsufficientShares.selector,
                alice, aliceShares + 1, aliceShares
            )
        );
        depositLogic.withdraw(address(tokenUSDC), aliceShares + 1, alice);
    }

    function test_withdraw_revertsZeroShares() public {
        vm.expectRevert(DepositLogic.ZeroShares.selector);
        depositLogic.withdraw(address(tokenUSDC), 0, alice);
    }

    function test_withdraw_revertsUnsupportedAsset() public {
        vm.expectRevert(
            abi.encodeWithSelector(DepositLogic.AssetNotSupported.selector, address(0x123))
        );
        depositLogic.withdraw(address(0x123), 100, alice);
    }

    function test_withdraw_revertsInvalidRecipient() public {
        _deposit(alice, address(tokenUSDC), 1_000e6);
        uint256 aliceShares = depositLogic.getAssetPosition(address(tokenUSDC), alice).shares;

        vm.prank(alice);
        vm.expectRevert(DepositLogic.InvalidRecipient.selector);
        depositLogic.withdraw(address(tokenUSDC), aliceShares, address(0));
    }

    function test_withdraw_emitsEvent() public {
        _deposit(alice, address(tokenUSDC), 1_000e6);
        uint256 aliceShares = depositLogic.getAssetPosition(address(tokenUSDC), alice).shares;

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit AssetWithdrawn(alice, address(tokenUSDC), 1_000e6, aliceShares);
        depositLogic.withdraw(address(tokenUSDC), aliceShares, alice);
    }

    function test_withdraw_revertsWhenPaused() public {
        _deposit(alice, address(tokenUSDC), 1_000e6);
        uint256 aliceShares = depositLogic.getAssetPosition(address(tokenUSDC), alice).shares;

        depositLogic.pause();
        vm.prank(alice);
        vm.expectRevert();
        depositLogic.withdraw(address(tokenUSDC), aliceShares, alice);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // 8. Pause/Unpause
    // ══════════════════════════════════════════════════════════════════════════

    function test_pause_onlyOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        depositLogic.pause();
    }

    function test_pause_preventsDeposits() public {
        depositLogic.pause();
        assertTrue(depositLogic.paused());
        vm.expectRevert();
        _deposit(alice, address(tokenUSDC), 100);
    }

    function test_unpause_allowsDeposits() public {
        depositLogic.pause();
        depositLogic.unpause();
        assertFalse(depositLogic.paused());
        _deposit(alice, address(tokenUSDC), 1_000e6);
        assertEq(tokenUSDC.balanceOf(address(depositLogic)), 1_000e6);
    }

    function test_unpause_onlyOwner() public {
        depositLogic.pause();
        vm.prank(nonOwner);
        vm.expectRevert();
        depositLogic.unpause();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // 9. Query Functions (Queries work)
    // ══════════════════════════════════════════════════════════════════════════

    function test_query_totalValueLocked() public {
        assertEq(depositLogic.totalValueLocked(), 0);
        _deposit(alice, address(tokenUSDC), 1_000e6);
        assertEq(depositLogic.totalValueLocked(), 1_000e6);
        _deposit(alice, address(tokenWETH), 5 ether);
        assertEq(depositLogic.totalValueLocked(), 1_000e6 + 5 ether);
    }

    function test_query_totalShares() public {
        assertEq(depositLogic.totalShares(), 0);
        uint256 shares = _deposit(alice, address(tokenUSDC), 1_000e6);
        assertEq(depositLogic.totalShares(), shares);
    }

    function test_query_isAssetSupported() public {
        assertTrue(depositLogic.isAssetSupported(address(tokenUSDC)));
        assertFalse(depositLogic.isAssetSupported(address(0x123)));
    }

    function test_query_getAssetConfig() public {
        DepositLogic.AssetConfig memory config = depositLogic.getAssetConfig(address(tokenUSDC));
        assertTrue(config.isActive);
        assertEq(config.depositCap, DEPOSIT_CAP);
        assertEq(config.minimumDeposit, MIN_DEPOSIT);
    }

    function test_query_getAssetPosition() public {
        DepositLogic.AssetPosition memory pos = depositLogic.getAssetPosition(address(tokenUSDC), alice);
        assertEq(pos.totalDeposited, 0);
        assertEq(pos.shares, 0);

        _deposit(alice, address(tokenUSDC), 1_000e6);
        pos = depositLogic.getAssetPosition(address(tokenUSDC), alice);
        assertEq(pos.totalDeposited, 1_000e6);
        assertGt(pos.shares, 0);
    }

    function test_query_getDepositHistory() public {
        DepositLogic.DepositRecord[] memory history = depositLogic.getDepositHistory(alice);
        assertEq(history.length, 0);

        _deposit(alice, address(tokenUSDC), 1_000e6);
        history = depositLogic.getDepositHistory(alice);
        assertEq(history.length, 1);
    }

    function test_query_depositCount() public {
        assertEq(depositLogic.depositCount(alice), 0);
        _deposit(alice, address(tokenUSDC), 1_000e6);
        assertEq(depositLogic.depositCount(alice), 1);
    }

    function test_query_previewDeposit() public {
        uint256 previewed = depositLogic.previewDeposit(address(tokenUSDC), 1_000e6);
        assertEq(previewed, 1_000e6 - 1000);
    }

    function test_query_previewRedeem() public {
        _deposit(alice, address(tokenUSDC), 1_000e6);
        uint256 aliceShares = depositLogic.getAssetPosition(address(tokenUSDC), alice).shares;
        uint256 previewed = depositLogic.previewRedeem(address(tokenUSDC), aliceShares);
        assertEq(previewed, 1_000e6);
    }

    function test_query_pricePerShare() public {
        assertEq(depositLogic.pricePerShare(address(tokenUSDC)), 1e18);
        _deposit(alice, address(tokenUSDC), 1_000e6);
        assertGt(depositLogic.pricePerShare(address(tokenUSDC)), 1e18);
    }

    function test_query_assetTVL() public {
        assertEq(depositLogic.assetTVL(address(tokenUSDC)), 0);
        _deposit(alice, address(tokenUSDC), 1_000e6);
        assertEq(depositLogic.assetTVL(address(tokenUSDC)), 1_000e6);
    }

    function test_query_getSupportedAssets() public view {
        address[] memory assets = depositLogic.getSupportedAssets();
        assertEq(assets.length, 3);
    }

    function test_query_supportedAssetsCount() public view {
        assertEq(depositLogic.supportedAssetsCount(), 3);
    }

    function test_query_getUserSummary() public {
        (uint256 totalDeposits, uint256 totalWithdrawals, uint256 positionCount) =
            depositLogic.getUserSummary(alice);
        assertEq(totalDeposits, 0);
        assertEq(totalWithdrawals, 0);
        assertEq(positionCount, 0);

        _deposit(alice, address(tokenUSDC), 1_000e6);
        _deposit(alice, address(tokenWETH), 5 ether);

        (totalDeposits, totalWithdrawals, positionCount) = depositLogic.getUserSummary(alice);
        assertEq(totalDeposits, 1_000e6 + 5 ether);
        assertEq(positionCount, 2);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // 10. Access Control
    // ══════════════════════════════════════════════════════════════════════════

    function test_accessControl_onlyOwner_addAsset() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        depositLogic.addAsset(address(1), DEPOSIT_CAP, 0);
    }

    function test_accessControl_onlyOwner_removeAsset() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        depositLogic.removeAsset(address(tokenUSDC));
    }

    function test_accessControl_onlyOwner_setDepositCap() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        depositLogic.setDepositCap(address(tokenUSDC), 200_000 ether);
    }

    function test_accessControl_onlyOwner_setMinimumDeposit() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        depositLogic.setMinimumDeposit(address(tokenUSDC), 2 ether);
    }

    function test_accessControl_onlyOwner_pause() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        depositLogic.pause();
    }

    function test_accessControl_onlyOwner_unpause() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        depositLogic.unpause();
    }

    function test_accessControl_onlyOwner_recoverToken() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        depositLogic.recoverToken(address(tokenUSDC), 100, alice);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // 11. Edge Cases
    // ══════════════════════════════════════════════════════════════════════════

    function test_edgeCase_depositAfterWithdraw() public {
        _deposit(alice, address(tokenUSDC), 1_000e6);
        uint256 aliceShares = depositLogic.getAssetPosition(address(tokenUSDC), alice).shares;
        uint256 halfShares = aliceShares / 2;

        vm.prank(alice);
        depositLogic.withdraw(address(tokenUSDC), halfShares, alice);

        _deposit(alice, address(tokenUSDC), 200e6);
        DepositLogic.AssetPosition memory pos = depositLogic.getAssetPosition(address(tokenUSDC), alice);
        assertEq(pos.totalDeposited, 1_200e6);
    }

    function test_edgeCase_depositAfterFullWithdrawal() public {
        _deposit(alice, address(tokenUSDC), 1_000e6);
        uint256 aliceShares = depositLogic.getAssetPosition(address(tokenUSDC), alice).shares;

        vm.prank(alice);
        depositLogic.withdraw(address(tokenUSDC), aliceShares, alice);

        _deposit(alice, address(tokenUSDC), 500e6);
        DepositLogic.AssetPosition memory pos = depositLogic.getAssetPosition(address(tokenUSDC), alice);
        assertEq(pos.totalDeposited, 500e6);
    }

    function test_edgeCase_multipleUsersSameAsset() public {
        _deposit(alice, address(tokenUSDC), 1_000e6);
        _deposit(bob, address(tokenUSDC), 2_000e6);
        _deposit(charlie, address(tokenUSDC), 3_000e6);
        assertEq(depositLogic.assetTVL(address(tokenUSDC)), 6_000e6);
    }

    function test_edgeCase_differentDecimals() public {
        _deposit(alice, address(tokenUSDC), 1_000e6);
        _deposit(alice, address(tokenWETH), 1 ether);
        DepositLogic.AssetPosition memory usdcPos = depositLogic.getAssetPosition(address(tokenUSDC), alice);
        DepositLogic.AssetPosition memory wethPos = depositLogic.getAssetPosition(address(tokenWETH), alice);
        assertEq(usdcPos.totalDeposited, 1_000e6);
        assertEq(wethPos.totalDeposited, 1 ether);
    }

    function test_edgeCase_recoverToken() public {
        // Send tokens directly to the contract (not through deposit)
        tokenUSDC.mint(address(depositLogic), 1000);
        uint256 balanceBefore = tokenUSDC.balanceOf(alice);

        depositLogic.recoverToken(address(tokenUSDC), 1000, alice);
        assertEq(tokenUSDC.balanceOf(alice), balanceBefore + 1000);
    }

    function test_edgeCase_recoverToken_revertsZeroAddress() public {
        vm.expectRevert(DepositLogic.ZeroAddress.selector);
        depositLogic.recoverToken(address(0), 100, alice);
    }

    function test_edgeCase_recoverToken_revertsZeroAmount() public {
        vm.expectRevert(DepositLogic.ZeroAssets.selector);
        depositLogic.recoverToken(address(tokenUSDC), 0, alice);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // 12. Fuzz Tests
    // ══════════════════════════════════════════════════════════════════════════

    /// @dev Fuzz: deposit amount must be >= minimumDeposit
    function testFuzz_deposit_revertsBelowMinimum(uint96 amount) public {
        uint256 minDeposit = depositLogic.getAssetConfig(address(tokenUSDC)).minimumDeposit;
        vm.assume(amount > 0 && amount < minDeposit);
        vm.expectRevert(
            abi.encodeWithSelector(DepositLogic.DepositTooSmall.selector, address(tokenUSDC), minDeposit, amount)
        );
        depositLogic.deposit(address(tokenUSDC), amount, alice);
    }

    /// @dev Fuzz: deposit and withdraw roundtrip preserves value
    function testFuzz_depositWithdrawRoundtrip(uint96 depositAmount) public {
        uint256 minDeposit = depositLogic.getAssetConfig(address(tokenUSDC)).minimumDeposit;
        vm.assume(depositAmount >= minDeposit && depositAmount <= 50_000 ether);

        vm.startPrank(alice);
        tokenUSDC.mint(alice, depositAmount);
        tokenUSDC.approve(address(depositLogic), depositAmount);
        uint256 shares = depositLogic.deposit(address(tokenUSDC), depositAmount, alice);
        vm.stopPrank();

        assertGt(shares, 0);

        vm.prank(alice);
        uint256 assetsReturned = depositLogic.withdraw(address(tokenUSDC), shares, alice);

        // Should get back approximately the same amount (minus rounding)
        assertApproxEqAbs(assetsReturned, depositAmount, 1);
    }

    /// @dev Fuzz: multiple deposits from different users
    function testFuzz_multipleDepositors(
        uint96 amount1,
        uint96 amount2,
        uint96 amount3
    ) public {
        uint256 minDeposit = depositLogic.getAssetConfig(address(tokenUSDC)).minimumDeposit;
        vm.assume(amount1 >= minDeposit && amount1 <= 30_000 ether);
        vm.assume(amount2 >= minDeposit && amount2 <= 30_000 ether);
        vm.assume(amount3 >= minDeposit && amount3 <= 30_000 ether);

        _deposit(alice, address(tokenUSDC), amount1);
        _deposit(bob, address(tokenUSDC), amount2);
        _deposit(charlie, address(tokenUSDC), amount3);

        assertEq(
            depositLogic.assetTVL(address(tokenUSDC)),
            uint256(amount1) + uint256(amount2) + uint256(amount3)
        );
    }
}