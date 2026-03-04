// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { SendParam } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { OFTComposeMsgCodec } from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";
import { VaultComposerSync } from "@layerzerolabs/ovault-evm/contracts/VaultComposerSync.sol";

/**
 * @title MyOVaultComposer
 * @notice Overrides _refund to send tokens to the user's address (decoded from the compose
 *         message) instead of composeFrom (TrailsRouter) so that users can receive refunds directly on origin chain in the case of a failed compose.
 * @dev The compose message is ABI-encoded as (SendParam, uint256 minMsgValue, address refundAddress).
 *      The base VaultComposerSync only decodes (SendParam, uint256) — the third field is ignored
 *      by Solidity's abi.decode, making this backward-compatible.
 */
contract MyOVaultComposer is VaultComposerSync {
    using OFTComposeMsgCodec for bytes;

    constructor(address _vault, address _assetOFT, address _shareOFT) VaultComposerSync(_vault, _assetOFT, _shareOFT) {}

    function _refund(
        address _oft,
        bytes calldata _message,
        uint256 _amount,
        address, // tx.origin (LZ Executor) — ignored, decoded from compose message instead
        uint256 _msgValue
    ) internal override {
        bytes memory composeMsg = _message.composeMsg();
        (, , address refundTo) = abi.decode(composeMsg, (SendParam, uint256, address));

        SendParam memory refundSendParam;
        refundSendParam.dstEid = OFTComposeMsgCodec.srcEid(_message);
        refundSendParam.to = OFTComposeMsgCodec.addressToBytes32(refundTo);
        refundSendParam.amountLD = _amount;

        _sendRemote(_oft, refundSendParam, tx.origin, _msgValue);
    }
}
