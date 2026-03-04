// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { SendParam } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { OFTComposeMsgCodec } from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";

contract ComposeMessageTest is Test {
    /// @dev Verify that abi.decode(msg, (SendParam, uint256)) still works when a third
    ///      address field is appended — proving backward compatibility.
    function test_backwardCompatible_twoFieldDecode() public pure {
        SendParam memory sp = SendParam({
            dstEid: 30101,
            to: bytes32(uint256(uint160(address(0xdead)))),
            amountLD: 1e6,
            minAmountLD: 9e5,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });
        uint256 minMsgValue = 0.01 ether;
        address refundAddr = address(0xBEEF);

        // Encode with 3 fields (new format)
        bytes memory encoded = abi.encode(sp, minMsgValue, refundAddr);

        // Decode with 2 fields (old format) — should succeed
        (SendParam memory decodedSp, uint256 decodedMinMsgValue) = abi.decode(encoded, (SendParam, uint256));

        assertEq(decodedSp.dstEid, sp.dstEid);
        assertEq(decodedSp.to, sp.to);
        assertEq(decodedSp.amountLD, sp.amountLD);
        assertEq(decodedMinMsgValue, minMsgValue);
    }

    /// @dev Verify that abi.decode(msg, (SendParam, uint256, address)) correctly extracts
    ///      the refund address from the third field.
    function test_threeFieldDecode_extractsRefundAddress() public pure {
        SendParam memory sp = SendParam({
            dstEid: 30101,
            to: bytes32(uint256(uint160(address(0xdead)))),
            amountLD: 1e6,
            minAmountLD: 9e5,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });
        uint256 minMsgValue = 0.01 ether;
        address refundAddr = address(0xBEEF);

        bytes memory encoded = abi.encode(sp, minMsgValue, refundAddr);

        (, , address decoded) = abi.decode(encoded, (SendParam, uint256, address));

        assertEq(decoded, refundAddr);
    }
}
