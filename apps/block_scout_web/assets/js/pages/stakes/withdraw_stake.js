import $ from 'jquery'
import { BigNumber } from 'bignumber.js'
import { openModal, openErrorModal, openQuestionModal, lockModal } from '../../lib/modals'
import { setupValidation } from '../../lib/validation'
import { makeContractCall, setupChart } from './utils'

export function openWithdrawStakeModal (event, store) {
  const address = $(event.target).closest('[data-address]').data('address')

  store.getState().channel
    .push('render_withdraw_stake', { address })
    .receive('ok', msg => {
      if (msg.claim_html && msg.withdraw_html) {
        openQuestionModal(
          'Claim or order', 'Do you want withdraw or claim ordered withdraw?',
          () => setupClaimWithdrawModal(address, store, msg),
          () => setupWithdrawStakeModal(address, store, msg),
          'Claim', 'Withdraw'
        )
      } else if (msg.claim_html) {
        setupClaimWithdrawModal(address, store, msg)
      } else {
        setupWithdrawStakeModal(address, store, msg)
      }
    })
}

function setupClaimWithdrawModal (address, store, msg) {
  const $modal = $(msg.claim_html)
  setupChart($modal.find('.js-stakes-progress'), msg.self_staked_amount, msg.staked_amount)
  $modal.find('form').submit(() => {
    claimWithdraw($modal, address, store)
    return false
  })
  openModal($modal)
}

function setupWithdrawStakeModal (address, store, msg) {
  const $modal = $(msg.withdraw_html)
  setupChart($modal.find('.js-stakes-progress'), msg.self_staked_amount, msg.staked_amount)
  setupValidation(
    $modal.find('form'),
    {
      'amount': value => isAmountValid(value, store, msg)
    },
    $modal.find('form button')
  )

  setupValidation(
    $modal.find('form'),
    {
      'amount': value => isWithdrawAmountValid(value, store, msg)
    },
    $modal.find('form button.withdraw')
  )

  setupValidation(
    $modal.find('form'),
    {
      'amount': value => isOrderWithdrawAmountValid(value, store, msg)
    },
    $modal.find('form button.order-withdraw')
  )

  $modal.find('.btn-full-primary.withdraw').click(() => {
    withdrawStake($modal, address, store, msg)
    return false
  })
  $modal.find('.btn-full-primary.order-withdraw').click(() => {
    orderWithdraw($modal, address, store, msg)
    return false
  })
  openModal($modal)
}

function claimWithdraw ($modal, address, store) {
  lockModal($modal)

  const stakingContract = store.getState().stakingContract
  makeContractCall(stakingContract.methods.claimOrderedWithdraw(address), store)
}

function withdrawStake ($modal, address, store, msg) {
  lockModal($modal, $modal.find('.btn-full-primary.withdraw'))

  const stakingContract = store.getState().stakingContract
  const decimals = store.getState().tokenDecimals
  const amount = new BigNumber($modal.find('[amount]').val().replace(',', '.').trim()).shiftedBy(decimals).integerValue()

  makeContractCall(stakingContract.methods.withdraw(address, amount.toString()), store)
}

function orderWithdraw ($modal, address, store, msg) {
  lockModal($modal, $modal.find('.btn-full-primary.order-withdraw'))

  const stakingContract = store.getState().stakingContract
  const decimals = store.getState().tokenDecimals
  const orderedWithdraw = new BigNumber(msg.ordered_withdraw)
  const amount = new BigNumber($modal.find('[amount]').val().replace(',', '.').trim()).shiftedBy(decimals).integerValue()

  if (amount.isLessThan(orderedWithdraw.negated())) {
    openErrorModal('Error', `You cannot reduce withdrawal by more than ${orderedWithdraw.shiftedBy(-decimals)} ${store.getState().tokenSymbol}`)
    return false
  }

  makeContractCall(stakingContract.methods.orderWithdraw(address, amount.toString()), store)
}

function isAmountValid (value, store, msg) {
  const decimals = store.getState().tokenDecimals
  const minStake = new BigNumber(msg.min_stake)
  const currentStake = new BigNumber(msg.delegator_staked)
  const amount = new BigNumber(value.replace(',', '.').trim()).shiftedBy(decimals).integerValue()

  if (!amount.isPositive() && !amount.isNegative()) {
    return 'Invalid amount'
  } else if (amount.isLessThan(currentStake) && currentStake.minus(amount).isLessThan(minStake)) {
    return `A minimum of ${minStake.shiftedBy(-decimals)} ${store.getState().tokenSymbol} is required to remain in the pool, or withdraw the entire amount to leave this pool`
  }

  return true
}

function isWithdrawAmountValid (value, store, msg) {
  const decimals = store.getState().tokenDecimals
  const minStake = new BigNumber(msg.min_stake)
  const currentStake = new BigNumber(msg.delegator_staked)
  const maxAllowed = new BigNumber(msg.max_withdraw_allowed)
  const amount = new BigNumber(value.replace(',', '.').trim()).shiftedBy(decimals).integerValue()

  if (!amount.isPositive()) {
    return null
  } else if (amount.isLessThan(currentStake) && currentStake.minus(amount).isLessThan(minStake)) {
    return null
  } else if (!amount.isPositive() || amount.isGreaterThan(maxAllowed)) {
    return null
  }

  return true
}

function isOrderWithdrawAmountValid (value, store, msg) {
  const decimals = store.getState().tokenDecimals
  const minStake = new BigNumber(msg.min_stake)
  const currentStake = new BigNumber(msg.delegator_staked)
  const orderedWithdraw = new BigNumber(msg.ordered_withdraw)
  const maxAllowed = new BigNumber(msg.max_ordered_withdraw_allowed)
  const amount = new BigNumber(value.replace(',', '.').trim()).shiftedBy(decimals).integerValue()

  if (!amount.isPositive() && !amount.isNegative()) {
    return null
  } else if (amount.isLessThan(currentStake) && currentStake.minus(amount).isLessThan(minStake)) {
    return null
  } else if (amount.isGreaterThan(maxAllowed)) {
    return null
  } else if (amount.isLessThan(orderedWithdraw.negated())) {
    return null
  }

  return true
}