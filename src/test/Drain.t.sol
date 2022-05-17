// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {ERC20 as SolmateERC20} from "solmate/tokens/ERC20.sol";
import {ERC721 as SolmateERC721} from "solmate/tokens/ERC721.sol";
import {ERC1155 as SolmateERC1155} from "solmate/tokens/ERC1155.sol";

import "./Utils.sol";
import "../Drain.sol";

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

contract BaseSetup is BaseUsers {
    Drain internal drain;
    uint256 constant internal FUNGIBLE_SUPPLY = 1e6 * 1e18; // arbitrary 1 million

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

    function testFailRetrieveETHNotOwner() public {
        // execute retrieve
        vm.prank(alice);
        drain.retrieveETH(alice);
    }
}

contract DrainERC20 is BaseSetup {
    DummyERC20 internal erc20A;
    DummyERC20 internal erc20B;

    function setUp() public virtual override {
        BaseSetup.setUp();

        erc20A = new DummyERC20();
        erc20A.mint(alice, FUNGIBLE_SUPPLY);
        erc20A.mint(address(drain), FUNGIBLE_SUPPLY);

        erc20B = new DummyERC20();
        erc20B.mint(alice, FUNGIBLE_SUPPLY);
        erc20B.mint(address(drain), FUNGIBLE_SUPPLY);
    }

    function testBatchSwapERC20Single() public {
        uint256 amount = 100e18;

        // token approval
        vm.prank(alice);
        erc20A.approve(address(drain), amount);

        // cache before values
        uint256 fromEtherBalanceBefore = alice.balance;
        uint256 toEtherBalanceBefore = address(drain).balance;
        uint256 fromTokenABalanceBefore = erc20A.balanceOf(alice);
        uint256 toTokenABalanceBefore = erc20A.balanceOf(address(drain));

        // prepare swap
        address[] memory tokens = new address[](1);
        tokens[0] = address(erc20A);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        // execute swap
        vm.prank(alice);
        drain.batchSwapERC20(tokens, amounts);

        // check erc20 balances
        assertEq(erc20A.balanceOf(alice), fromTokenABalanceBefore - amount);
        assertEq(erc20A.balanceOf(address(drain)), toTokenABalanceBefore + amount);

        // check ether balances
        assertEq(alice.balance, fromEtherBalanceBefore + drain.PRICE());
        assertEq(address(drain).balance, toEtherBalanceBefore - drain.PRICE());
    }

    function testBatchSwapERC20Multiple() public {
        uint256 amount1 = 100e18;
        uint256 amount2 = 200e18;

        // token approval
        vm.prank(alice);
        erc20A.approve(address(drain), amount1);
        vm.prank(alice);
        erc20B.approve(address(drain), amount2);

        // cache before values
        uint256 fromEtherBalanceBefore = alice.balance;
        uint256 toEtherBalanceBefore = address(drain).balance;
        uint256 fromTokenABalanceBefore = erc20A.balanceOf(alice);
        uint256 toTokenABalanceBefore = erc20A.balanceOf(address(drain));
        uint256 fromTokenBBalanceBefore = erc20B.balanceOf(alice);
        uint256 toTokenBBalanceBefore = erc20B.balanceOf(address(drain));

        // prepare swap
        address[] memory tokens = new address[](2);
        tokens[0] = address(erc20A);
        tokens[1] = address(erc20B);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;

        // execute swap
        vm.prank(alice);
        drain.batchSwapERC20(tokens, amounts);

        // check erc20 balances
        assertEq(erc20A.balanceOf(alice), fromTokenABalanceBefore - amount1);
        assertEq(erc20A.balanceOf(address(drain)), toTokenABalanceBefore + amount1);
        assertEq(erc20B.balanceOf(alice), fromTokenBBalanceBefore - amount2);
        assertEq(erc20B.balanceOf(address(drain)), toTokenBBalanceBefore + amount2);

        // check ether balances
        assertEq(alice.balance, fromEtherBalanceBefore + drain.PRICE());
        assertEq(address(drain).balance, toEtherBalanceBefore - drain.PRICE());
    }

    function testBatchRetrieveERC20Single() public {
        uint256 amount = 100e18;

        // cache before values
        uint256 fromTokenABalanceBefore = erc20A.balanceOf(address(drain));
        uint256 toTokenABalanceBefore = erc20A.balanceOf(admin);

        // prepare retrieve
        address[] memory tokens = new address[](1);
        tokens[0] = address(erc20A);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        // execute retrieve
        vm.prank(admin);
        drain.batchRetrieveERC20(admin, tokens, amounts);

        // check erc20 balances
        assertEq(erc20A.balanceOf(address(drain)), fromTokenABalanceBefore - amount);
        assertEq(erc20A.balanceOf(admin), toTokenABalanceBefore + amount);
    }

    function testBatchRetrieveERC20Multiple() public {
        uint256 amount1 = 100e18;
        uint256 amount2 = 200e18;

        // cache before values
        uint256 fromTokenABalanceBefore = erc20A.balanceOf(address(drain));
        uint256 toTokenABalanceBefore = erc20A.balanceOf(admin);
        uint256 fromTokenBBalanceBefore = erc20B.balanceOf(address(drain));
        uint256 toTokenBBalanceBefore = erc20B.balanceOf(admin);

        // execute retrieve
        address[] memory tokens = new address[](2);
        tokens[0] = address(erc20A);
        tokens[1] = address(erc20B);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;

        // execute retrieve
        vm.prank(admin);
        drain.batchRetrieveERC20(admin, tokens, amounts);

        // check token balances
        assertEq(erc20A.balanceOf(address(drain)), fromTokenABalanceBefore - amount1);
        assertEq(erc20A.balanceOf(admin), toTokenABalanceBefore + amount1);
        assertEq(erc20B.balanceOf(address(drain)), fromTokenBBalanceBefore - amount2);
        assertEq(erc20B.balanceOf(admin), toTokenBBalanceBefore + amount2);
    }

    function testFailBatchRetrieveERC20NonOwner() public {
        // prepare retrieve
        address[] memory tokens = new address[](1);
        tokens[0] = address(erc20A);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        // execute retrieve
        vm.prank(alice);
        drain.batchRetrieveERC20(alice, tokens, amounts);
    }
}

contract DrainERC721 is BaseSetup {
    DummyERC721 internal erc721A;
    DummyERC721 internal erc721B;

    function setUp() public virtual override {
        BaseSetup.setUp();

        erc721A = new DummyERC721();
        erc721A.mint(alice, 0);
        erc721A.mint(address(drain), 1);

        erc721B = new DummyERC721();
        erc721B.mint(alice, 0);
        erc721B.mint(address(drain), 1);
    }

    function testBatchSwapERC721Single() public {
        // token approval
        vm.prank(alice);
        erc721A.approve(address(drain), 0);

        // cache before values
        uint256 fromEtherBalanceBefore = alice.balance;
        uint256 toEtherBalanceBefore = address(drain).balance;

        // prepare swap
        address[] memory tokens = new address[](1);
        tokens[0] = address(erc721A);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 0;

        // execute swap
        vm.prank(alice);
        drain.batchSwapERC721(tokens, ids);

        // check erc721 balances
        assertEq(erc721A.ownerOf(0), address(drain));

        // check ether balances
        assertEq(alice.balance, fromEtherBalanceBefore + drain.PRICE());
        assertEq(address(drain).balance, toEtherBalanceBefore - drain.PRICE());
    }

    function testBatchSwapERC721Multiple() public {
        // token approval
        vm.prank(alice);
        erc721A.approve(address(drain), 0);
        vm.prank(alice);
        erc721B.approve(address(drain), 0);

        // cache before values
        uint256 fromEtherBalanceBefore = alice.balance;
        uint256 toEtherBalanceBefore = address(drain).balance;

        // prepare swap
        address[] memory tokens = new address[](2);
        tokens[0] = address(erc721A);
        tokens[1] = address(erc721B);
        uint256[] memory ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 0;

        // execute swap
        vm.prank(alice);
        drain.batchSwapERC721(tokens, ids);

        // check erc721 balances
        assertEq(erc721A.ownerOf(0), address(drain));
        assertEq(erc721B.ownerOf(0), address(drain));

        // check ether balances
        assertEq(alice.balance, fromEtherBalanceBefore + drain.PRICE());
        assertEq(address(drain).balance, toEtherBalanceBefore - drain.PRICE());
    }

    function testBatchRetrieveERC721Single() public {
        // prepare retrieve
        address[] memory tokens = new address[](1);
        tokens[0] = address(erc721A);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;

        // execute retrieve
        vm.prank(admin);
        drain.batchRetrieveERC721(admin, tokens, ids);

        // check erc721 balances
        assertEq(erc721A.ownerOf(1), admin);
    }

    function testBatchRetrieveERC721Multiple() public {
        // prepare retrieve
        address[] memory tokens = new address[](2);
        tokens[0] = address(erc721A);
        tokens[1] = address(erc721B);
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 1;

        // execute retrieve
        vm.prank(admin);
        drain.batchRetrieveERC721(admin, tokens, ids);

        // check erc721 balances
        assertEq(erc721A.ownerOf(1), admin);
        assertEq(erc721B.ownerOf(1), admin);
    }

    function testFailBatchRetrieveERC721NonOwner() public {
        // prepare retrieve
        address[] memory tokens = new address[](1);
        tokens[0] = address(erc721A);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;

        // execute retrieve
        vm.prank(alice);
        drain.batchRetrieveERC721(alice, tokens, ids);
    }
}

contract DrainERC1155 is BaseSetup {
    DummyERC1155 internal erc1155A;
    DummyERC1155 internal erc1155B;

    function setUp() public virtual override {
        BaseSetup.setUp();

        erc1155A = new DummyERC1155();
        erc1155A.mint(alice, 0, FUNGIBLE_SUPPLY);
        erc1155A.mint(address(drain), 1, FUNGIBLE_SUPPLY);

        erc1155B = new DummyERC1155();
        erc1155B.mint(alice, 0, FUNGIBLE_SUPPLY);
        erc1155B.mint(address(drain), 1, FUNGIBLE_SUPPLY);
    }

    function testBatchSwapERC1155Single() public {
        uint256 amount = 100e18;

        // token approval
        vm.prank(alice);
        erc1155A.setApprovalForAll(address(drain), true);

        // cache before values
        uint256 fromEtherBalanceBefore = alice.balance;
        uint256 toEtherBalanceBefore = address(drain).balance;
        uint256 fromTokenABalanceBefore = erc1155A.balanceOf(alice, 0);
        uint256 toTokenABalanceBefore = erc1155A.balanceOf(address(drain), 0);

        // prepare swap
        address[] memory tokens = new address[](1);
        tokens[0] = address(erc1155A);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 0;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        // execute swap
        vm.prank(alice);
        drain.batchSwapERC1155(tokens, ids, amounts);

        // check erc1155 balances
        assertEq(erc1155A.balanceOf(alice, 0), fromTokenABalanceBefore - amount);
        assertEq(erc1155A.balanceOf(address(drain), 0), toTokenABalanceBefore + amount);

        // check ether balances
        assertEq(alice.balance, fromEtherBalanceBefore + drain.PRICE());
        assertEq(address(drain).balance, toEtherBalanceBefore - drain.PRICE());
    }

    function testBatchSwapERC1155Multiple() public {
        uint256 amount1 = 100e18;
        uint256 amount2 = 200e18;

        // token approval
        vm.prank(alice);
        erc1155A.setApprovalForAll(address(drain), true);
        vm.prank(alice);
        erc1155B.setApprovalForAll(address(drain), true);

        // cache before values
        uint256 fromEtherBalanceBefore = alice.balance;
        uint256 toEtherBalanceBefore = address(drain).balance;
        uint256 fromTokenABalanceBefore = erc1155A.balanceOf(alice, 0);
        uint256 toTokenABalanceBefore = erc1155A.balanceOf(address(drain), 0);
        uint256 fromTokenBBalanceBefore = erc1155B.balanceOf(alice, 0);
        uint256 toTokenBBalanceBefore = erc1155B.balanceOf(address(drain), 0);

        // prepare swap
        address[] memory tokens = new address[](2);
        tokens[0] = address(erc1155A);
        tokens[1] = address(erc1155B);
        uint256[] memory ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 0;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;

        // execute swap
        vm.prank(alice);
        drain.batchSwapERC1155(tokens, ids, amounts);

        // check erc1155 balances
        assertEq(erc1155A.balanceOf(alice, 0), fromTokenABalanceBefore - amount1);
        assertEq(erc1155A.balanceOf(address(drain), 0), toTokenABalanceBefore + amount1);
        assertEq(erc1155B.balanceOf(alice, 0), fromTokenBBalanceBefore - amount2);
        assertEq(erc1155B.balanceOf(address(drain), 0), toTokenBBalanceBefore + amount2);

        // check ether balances
        assertEq(alice.balance, fromEtherBalanceBefore + drain.PRICE());
        assertEq(address(drain).balance, toEtherBalanceBefore - drain.PRICE());
    }

    function testBatchRetrieveERC1155Single() public {
        uint256 amount = 100e18;

        // cache before values
        uint256 fromTokenABalanceBefore = erc1155A.balanceOf(address(drain), 1);
        uint256 toTokenABalanceBefore = erc1155A.balanceOf(admin, 1);

        // prepare retrieve
        address[] memory tokens = new address[](1);
        tokens[0] = address(erc1155A);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        // execute retrieve
        vm.prank(admin);
        drain.batchRetrieveERC1155(admin, tokens, ids, amounts);

        // check erc1155 balances
        assertEq(erc1155A.balanceOf(address(drain), 1), fromTokenABalanceBefore - amount);
        assertEq(erc1155A.balanceOf(admin, 1), toTokenABalanceBefore + amount);
    }

    function testBatchRetrieveERC1155Multiple() public {
        uint256 amount1 = 100e18;
        uint256 amount2 = 200e18;

        // cache before values
        uint256 fromTokenABalanceBefore = erc1155A.balanceOf(address(drain), 1);
        uint256 toTokenABalanceBefore = erc1155A.balanceOf(admin, 1);
        uint256 fromTokenBBalanceBefore = erc1155B.balanceOf(address(drain), 1);
        uint256 toTokenBBalanceBefore = erc1155B.balanceOf(admin, 1);

        // prepare retrieve
        address[] memory tokens = new address[](2);
        tokens[0] = address(erc1155A);
        tokens[1] = address(erc1155B);
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 1;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;

        // execute retrieve
        vm.prank(admin);
        drain.batchRetrieveERC1155(admin, tokens, ids, amounts);

        // check erc1155 balances
        assertEq(erc1155A.balanceOf(address(drain), 1), fromTokenABalanceBefore - amount1);
        assertEq(erc1155A.balanceOf(admin, 1), toTokenABalanceBefore + amount1);
        assertEq(erc1155B.balanceOf(address(drain), 1), fromTokenBBalanceBefore - amount2);
        assertEq(erc1155B.balanceOf(admin, 1), toTokenBBalanceBefore + amount2);
    }

    function testFailBatchRetrieveERC1155NonOwner() public {
        // prepare retrieve
        address[] memory tokens = new address[](1);
        tokens[0] = address(erc1155A);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100e18;

        // execute retrieve
        vm.prank(alice);
        drain.batchRetrieveERC1155(alice, tokens, ids, amounts);
    }
}
