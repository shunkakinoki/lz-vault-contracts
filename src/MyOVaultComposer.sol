// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { SendParam } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { OFTComposeMsgCodec } from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";
import { VaultComposerSync } from "@layerzerolabs/ovault-evm/contracts/VaultComposerSync.sol";

/**
 * @title MyOVaultComposer
 * @notice Cross-chain vault composer that decodes the user's refund address from the compose
 *         message instead of relying on composeFrom (which resolves to the TrailsRouter contract)
 *         and tx.origin (which resolves to the LZ Executor).
 * @dev The compose message is ABI-encoded as (SendParam, uint256 minMsgValue, address refundAddress).
 *      The base VaultComposerSync only decodes (SendParam, uint256) — the third field is ignored
 *      by Solidity's abi.decode, making this backward-compatible.
 */
contract MyOVaultComposer is VaultComposerSync {
    using OFTComposeMsgCodec for bytes;

    /// @dev Refund address decoded from the compose message, set during lzCompose execution.
    address private _pendingRefundAddress;

    constructor(address _vault, address _assetOFT, address _shareOFT) VaultComposerSync(_vault, _assetOFT, _shareOFT) {}

    /// @dev Decodes the user's refund address from the compose message (third ABI-encoded field)
    ///      and stores it so that overridden internal functions use it instead of tx.origin/composeFrom.
    function lzCompose(
        address _composeSender,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) public payable override {
        bytes memory composeMsg = _message.composeMsg();
        (, , address refundAddress) = abi.decode(composeMsg, (SendParam, uint256, address));
        _pendingRefundAddress = refundAddress;

        super.lzCompose(_composeSender, _guid, _message, _executor, _extraData);

        _pendingRefundAddress = address(0);
    }

    /// @dev Override _refund to send tokens cross-chain to the user's address instead of composeFrom.
    function _refund(
        address _oft,
        bytes calldata _message,
        uint256 _amount,
        address _refundAddress,
        uint256 _msgValue
    ) internal override {
        address refund = _getRefundAddress(_refundAddress);

        SendParam memory refundSendParam;
        refundSendParam.dstEid = OFTComposeMsgCodec.srcEid(_message);
        refundSendParam.to = _addressToBytes32(refund);
        refundSendParam.amountLD = _amount;

        _sendRemote(_oft, refundSendParam, refund, _msgValue);
    }

    function _depositAndSend(
        bytes32 _depositor,
        uint256 _assetAmount,
        SendParam memory _sendParam,
        address _refundAddress,
        uint256 _msgValue
    ) internal override {
        super._depositAndSend(_depositor, _assetAmount, _sendParam, _getRefundAddress(_refundAddress), _msgValue);
    }

    function _redeemAndSend(
        bytes32 _redeemer,
        uint256 _shareAmount,
        SendParam memory _sendParam,
        address _refundAddress,
        uint256 _msgValue
    ) internal override {
        super._redeemAndSend(_redeemer, _shareAmount, _sendParam, _getRefundAddress(_refundAddress), _msgValue);
    }

    /// @dev Returns the pending refund address if set (compose path), otherwise falls back to the
    ///      caller-provided address (direct depositAndSend/redeemAndSend path).
    function _getRefundAddress(address _fallback) private view returns (address) {
        return _pendingRefundAddress != address(0) ? _pendingRefundAddress : _fallback;
    }

    function _addressToBytes32(address _addr) private pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}
