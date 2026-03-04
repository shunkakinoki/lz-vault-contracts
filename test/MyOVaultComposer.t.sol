// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { SendParam } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

contract ComposeMessageTest is Test {
    function _defaultSendParam() private pure returns (SendParam memory) {
        return SendParam({
            dstEid: 30101,
            to: bytes32(uint256(uint160(address(0xdead)))),
            amountLD: 1e6,
            minAmountLD: 9e5,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });
    }

    /// @dev Verify that abi.decode(msg, (SendParam, uint256)) still works when a third
    ///      address field is appended — proving backward compatibility.
    function test_backwardCompatible_twoFieldDecode() public pure {
        SendParam memory sp = _defaultSendParam();
        uint256 minMsgValue = 0.01 ether;

        bytes memory encoded = abi.encode(sp, minMsgValue, address(0xBEEF));

        (SendParam memory decodedSp, uint256 decodedMinMsgValue) = abi.decode(encoded, (SendParam, uint256));

        assertEq(decodedSp.dstEid, sp.dstEid);
        assertEq(decodedSp.to, sp.to);
        assertEq(decodedSp.amountLD, sp.amountLD);
        assertEq(decodedSp.minAmountLD, sp.minAmountLD);
        assertEq(decodedMinMsgValue, minMsgValue);
    }

    /// @dev Verify that abi.decode(msg, (SendParam, uint256, address)) correctly extracts
    ///      the refund address from the third field.
    function test_threeFieldDecode_extractsRefundAddress() public pure {
        bytes memory encoded = abi.encode(_defaultSendParam(), 0.01 ether, address(0xBEEF));

        (, , address decoded) = abi.decode(encoded, (SendParam, uint256, address));

        assertEq(decoded, address(0xBEEF));
    }
}
