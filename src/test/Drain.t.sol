// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {ERC20 as SolmateERC20} from "solmate/tokens/ERC20.sol";
import {ERC721 as SolmateERC721} from "solmate/tokens/ERC721.sol";
import {ERC1155 as SolmateERC1155} from "solmate/tokens/ERC1155.sol";

import "./Utils.sol";
import "../Drain.sol";

/// @dev Gas test for contract deployment.
contract DrainDeploy is Test {
    Drain internal drain;

    function testDeploy() public {
        drain = new Drain();
    }
}

contract BaseUsers is Test {
    Utils internal utils;
    address payable[] internal users;

    address internal alice;
    address internal admin;

    constructor() {
        utils = new Utils();
        users = utils.createUsers(2);

        alice = users[0];
        vm.label(alice, "Alice");
        admin = users[1];
        vm.label(admin, "Admin");
    }
}

contract DummyERC20 is SolmateERC20 {
    constructor() SolmateERC20("DummyERC20", "dERC20", 18) {}

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }
}

contract DummyERC721 is SolmateERC721 {
    constructor() SolmateERC721("DummyERC721", "dERC721") {}

    function tokenURI(uint256) override public pure returns (string memory) {
        return "";
    }

    function mint(address _to, uint256 _id) external {
        _mint(_to, _id);
    }
}

contract DummyERC1155 is SolmateERC1155 {
    constructor() SolmateERC1155() {}

    function uri(uint256) override public pure returns (string memory) {
        return "";
    }

    function mint(address _to, uint256 _id, uint256 _amount) external {
        _mint(_to, _id, _amount, "");
    }
}

contract DummyTokens {
    DummyERC20 internal erc20;
    DummyERC721 internal erc721;
    DummyERC1155 internal erc1155;

    constructor() {
        erc20 = new DummyERC20();
        erc721 = new DummyERC721();
        erc1155 = new DummyERC1155();
    }
}

contract BaseSetup is DummyTokens, BaseUsers {
    Drain internal drain;
    uint256 constant internal FUNGIBLE_SUPPLY = 1e12 * 1e18; // arbitrary 1 trillion
    bytes constant internal OWNABLE_ERROR_BYTES = bytes("Ownable: caller is not the owner");

    function setUp() public virtual {
        vm.prank(admin);
        drain = new Drain();

        vm.deal(address(drain), 1 ether);
    }
}

contract DrainAdmin is BaseSetup {
    function setUp() public virtual override {
        BaseSetup.setUp();
    }

    function testRetrieveETH() public {
        // cache before values
        uint256 fromEtherBalanceBefore = address(drain).balance;
        uint256 toEtherBalanceBefore = admin.balance;

        // execute retrieve
        vm.prank(admin);
        drain.retrieveETH(admin);

        // check ether balances
        assertEq(admin.balance, toEtherBalanceBefore + fromEtherBalanceBefore);
        assertEq(address(drain).balance, 0);
    }

    function testRetrieveETHNotOwner() public {
        // execute retrieve
        vm.prank(alice);
        vm.expectRevert(OWNABLE_ERROR_BYTES);
        drain.retrieveETH(alice);
    }
}

contract DrainERC20 is BaseSetup {
    function setUp() public virtual override {
        BaseSetup.setUp();
    }

    function swap(uint256 _amount) public {
        address[] memory tokens = new address[](1);
        tokens[0] = address(erc20);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _amount;

        drain.batchSwapERC20(tokens, amounts);
    }

    function retrieve(address _recipient, uint256 _amount) internal {
        address[] memory tokens = new address[](1);
        tokens[0] = address(erc20);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _amount;

        drain.batchRetrieveERC20(_recipient, tokens, amounts);
    }

    function testSwap(uint256 _amount) public {
        erc20.mint(alice, FUNGIBLE_SUPPLY);

        vm.assume(_amount <= erc20.balanceOf(alice));

        // token approval
        vm.prank(alice);
        erc20.approve(address(drain), _amount);

        // cache before values
        uint256 fromEtherBalanceBefore = alice.balance;
        uint256 toEtherBalanceBefore = address(drain).balance;
        uint256 fromTokenBalanceBefore = erc20.balanceOf(alice);
        uint256 toTokenBalanceBefore = erc20.balanceOf(address(drain));

        // execute swap
        vm.prank(alice);
        swap(_amount);

        // check erc20 balances
        assertEqDecimal(erc20.balanceOf(alice), fromTokenBalanceBefore - _amount, erc20.decimals());
        assertEqDecimal(erc20.balanceOf(address(drain)), toTokenBalanceBefore + _amount, erc20.decimals());

        // check ether balances
        assertEq(alice.balance, fromEtherBalanceBefore + drain.PRICE());
        assertEq(address(drain).balance, toEtherBalanceBefore - drain.PRICE());
    }

    function testRetrieve(uint256 _amount) public {
        erc20.mint(address(drain), FUNGIBLE_SUPPLY);

        vm.assume(_amount <= erc20.balanceOf(address(drain)));

        // cache before values
        uint256 fromTokenBalanceBefore = erc20.balanceOf(address(drain));
        uint256 toTokenBalanceBefore = erc20.balanceOf(admin);

        // execute retrieve
        vm.prank(admin);
        retrieve(admin, _amount);

        // check ether balances
        assertEqDecimal(erc20.balanceOf(address(drain)), fromTokenBalanceBefore - _amount, erc20.decimals());
        assertEqDecimal(erc20.balanceOf(admin), toTokenBalanceBefore + _amount, erc20.decimals());
    }

    function testRetrieveNotOwner(uint256 _amount) public {
        erc20.mint(address(drain), FUNGIBLE_SUPPLY);

        vm.assume(_amount <= erc20.balanceOf(address(drain)));

        // execute retrieve
        vm.expectRevert(OWNABLE_ERROR_BYTES);
        vm.prank(alice);
        retrieve(alice, _amount);
    }
}

contract DrainERC721 is BaseSetup {
    uint256 public constant TOKEN_ID = 1;
    uint256 public constant TOKEN_ID_RETRIEVE = 2;

    function setUp() public virtual override {
        BaseSetup.setUp();
    }

    function swap(uint256 _id) internal {
        address[] memory tokens = new address[](1);
        tokens[0] = address(erc721);
        uint256[] memory ids = new uint256[](1);
        ids[0] = _id;

        drain.batchSwapERC721(tokens, ids);
    }

    function retrieve(address _recipient, uint256 _id) internal {
        address[] memory tokens = new address[](1);
        tokens[0] = address(erc721);
        uint256[] memory ids = new uint256[](1);
        ids[0] = _id;

        drain.batchRetrieveERC721(_recipient, tokens, ids);
    }

    function testSwap() public {
        erc721.mint(alice, TOKEN_ID);

        // token approval
        vm.prank(alice);
        erc721.approve(address(drain), TOKEN_ID);

        // cache before values
        uint256 fromEtherBalanceBefore = alice.balance;
        uint256 toEtherBalanceBefore = address(drain).balance;

        // execute swap
        vm.prank(alice);
        swap(TOKEN_ID);

        // check erc721 balances
        assertEq(erc721.ownerOf(TOKEN_ID), address(drain));

        // check ether balances
        assertEq(alice.balance, fromEtherBalanceBefore + drain.PRICE());
        assertEq(address(drain).balance, toEtherBalanceBefore - drain.PRICE());
    }

    function testRetrieve() public {
        erc721.mint(address(drain), TOKEN_ID_RETRIEVE);


        // execute retrieve
        vm.prank(admin);
        retrieve(admin, TOKEN_ID_RETRIEVE);

        // check erc721 balances
        assertEq(erc721.ownerOf(TOKEN_ID_RETRIEVE), admin);
    }

    function testRetrieveNotOwner() public {
        erc721.mint(address(drain), TOKEN_ID_RETRIEVE);

        // execute retrieve
        vm.expectRevert(OWNABLE_ERROR_BYTES);
        vm.prank(alice);
        retrieve(alice, TOKEN_ID_RETRIEVE);
    }
}

contract DrainERC1155 is BaseSetup {
    uint256 public constant TOKEN_ID = 1;
    uint256 public constant TOKEN_ID_RETRIEVE = 2;

    function setUp() public virtual override {
        BaseSetup.setUp();
    }

    function swap(uint256 _id, uint256 _amount) internal {
        address[] memory tokens = new address[](1);
        tokens[0] = address(erc1155);
        uint256[] memory ids = new uint256[](1);
        ids[0] = _id;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _amount;

        drain.batchSwapERC1155(tokens, ids, amounts);
    }

    function retrieve(address _recipient, uint256 _id, uint256 _amount) internal {
        address[] memory tokens = new address[](1);
        tokens[0] = address(erc1155);
        uint256[] memory ids = new uint256[](1);
        ids[0] = _id;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _amount;

        drain.batchRetrieveERC1155(_recipient, tokens, ids, amounts);
    }

    function testSwap(uint256 _amount) public {
        erc1155.mint(alice, TOKEN_ID, FUNGIBLE_SUPPLY);

        vm.assume(_amount <= erc1155.balanceOf(alice, TOKEN_ID));

        // token approval
        vm.prank(alice);
        erc1155.setApprovalForAll(address(drain), true);

        // cache before values
        uint256 fromEtherBalanceBefore = alice.balance;
        uint256 toEtherBalanceBefore = address(drain).balance;
        uint256 fromTokenBalanceBefore = erc1155.balanceOf(alice, TOKEN_ID);
        uint256 toTokenBalanceBefore = erc1155.balanceOf(address(drain), TOKEN_ID);

        // execute swap
        vm.prank(alice);
        swap(TOKEN_ID, _amount);

        // check erc1155 balances
        assertEq(erc1155.balanceOf(alice, TOKEN_ID), fromTokenBalanceBefore - _amount);
        assertEq(erc1155.balanceOf(address(drain), TOKEN_ID), toTokenBalanceBefore + _amount);

        // check ether balances
        assertEq(alice.balance, fromEtherBalanceBefore + drain.PRICE());
        assertEq(address(drain).balance, toEtherBalanceBefore - drain.PRICE());
    }

    function testRetrieve(uint256 _amount) public {
        erc1155.mint(address(drain), TOKEN_ID_RETRIEVE, FUNGIBLE_SUPPLY);

        vm.assume(_amount <= erc1155.balanceOf(address(drain), TOKEN_ID_RETRIEVE));

        // cache before values
        uint256 fromTokenBalanceBefore = erc1155.balanceOf(address(drain), TOKEN_ID_RETRIEVE);
        uint256 toTokenBalanceBefore = erc1155.balanceOf(admin, TOKEN_ID_RETRIEVE);

        // execute retrieve
        vm.prank(admin);
        retrieve(admin, TOKEN_ID_RETRIEVE, _amount);

        // check ether balances
        assertEq(erc1155.balanceOf(address(drain), TOKEN_ID_RETRIEVE), fromTokenBalanceBefore - _amount);
        assertEq(erc1155.balanceOf(admin, TOKEN_ID_RETRIEVE), toTokenBalanceBefore + _amount);
    }

    function testRetrieveNotOwner(uint256 _amount) public {
        erc1155.mint(address(drain), TOKEN_ID_RETRIEVE, FUNGIBLE_SUPPLY);

        vm.assume(_amount <= erc1155.balanceOf(address(drain), TOKEN_ID_RETRIEVE));

        // execute retrieve
        vm.expectRevert(OWNABLE_ERROR_BYTES);
        vm.prank(alice);
        retrieve(alice, TOKEN_ID_RETRIEVE, _amount);
    }
}
