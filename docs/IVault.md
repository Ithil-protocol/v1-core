# IVault

_Ithil_

> Interface of Vault contract

## Methods

### addStrategy

```solidity
function addStrategy(address strategy) external nonpayable
```

Adds a new strategy address to the list

#### Parameters

| Name     | Type    | Description         |
| -------- | ------- | ------------------- |
| strategy | address | the strategy to add |

### apy

```solidity
function apy(address token) external view returns (uint256)
```

Gets an estimation of the past APY of a given token

#### Parameters

| Name  | Type    | Description                        |
| ----- | ------- | ---------------------------------- |
| token | address | the token to check the APY against |

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |

### balance

```solidity
function balance(address token) external view returns (uint256)
```

shows the available balance to borrow in the vault

#### Parameters

| Name  | Type    | Description        |
| ----- | ------- | ------------------ |
| token | address | the token to check |

#### Returns

| Name | Type    | Description       |
| ---- | ------- | ----------------- |
| \_0  | uint256 | available balance |

### borrow

```solidity
function borrow(address token, uint256 amount, uint256 collateral, uint256 riskFactor, address borrower) external nonpayable returns (uint256 interestRate, uint256 fees, uint256 debt, uint256 borrowed)
```

updates state to borrow tokens from the vault

#### Parameters

| Name       | Type    | Description                         |
| ---------- | ------- | ----------------------------------- |
| token      | address | the token to borrow                 |
| amount     | uint256 | the total amount to borrow          |
| collateral | uint256 | the collateral locked for this loan |
| riskFactor | uint256 | the riskiness of this loan          |
| borrower   | address | the ultimate requester of the loan  |

#### Returns

| Name         | Type    | Description                               |
| ------------ | ------- | ----------------------------------------- |
| interestRate | uint256 | the interest rate calculated for the loan |
| fees         | uint256 | undefined                                 |
| debt         | uint256 | undefined                                 |
| borrowed     | uint256 | undefined                                 |

### claimable

```solidity
function claimable(address token) external view returns (uint256)
```

Gets the amount of tokens a user can get back when unstaking

#### Parameters

| Name  | Type    | Description                                     |
| ----- | ------- | ----------------------------------------------- |
| token | address | the token to check the claimable amount against |

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |

### removeStrategy

```solidity
function removeStrategy(address strategy) external nonpayable
```

Removes a strategy address from the list

#### Parameters

| Name     | Type    | Description            |
| -------- | ------- | ---------------------- |
| strategy | address | the strategy to remove |

### repay

```solidity
function repay(address token, uint256 amount, uint256 debt, uint256 fees, address borrower) external nonpayable
```

repays a loan

#### Parameters

| Name     | Type    | Description                                      |
| -------- | ------- | ------------------------------------------------ |
| token    | address | the token of the loan                            |
| amount   | uint256 | the total amount transfered during the repayment |
| debt     | uint256 | the debt of the loan                             |
| fees     | uint256 | undefined                                        |
| borrower | address | the owner of the loan                            |

### stake

```solidity
function stake(address token, uint256 amount) external nonpayable
```

Add tokens to the vault, and updates internal status to register updated claiming powers

#### Parameters

| Name   | Type    | Description                           |
| ------ | ------- | ------------------------------------- |
| token  | address | the token to deposit                  |
| amount | uint256 | the amount of native tokens deposited |

### toggleLock

```solidity
function toggleLock(bool status, address token) external nonpayable
```

Locks/unlocks a token

#### Parameters

| Name   | Type    | Description               |
| ------ | ------- | ------------------------- |
| status | bool    | the status to be achieved |
| token  | address | the token to apply it to  |

### unstake

```solidity
function unstake(address token, uint256 amount) external nonpayable
```

Remove tokens from the vault, and updates internal status to register updated claiming powers

#### Parameters

| Name   | Type    | Description                           |
| ------ | ------- | ------------------------------------- |
| token  | address | the token to deposit                  |
| amount | uint256 | the amount of native tokens withdrawn |

### whitelistToken

```solidity
function whitelistToken(address token, uint256 baseFee, uint256 fixedFee) external nonpayable
```

adds a new supported token

#### Parameters

| Name     | Type    | Description            |
| -------- | ------- | ---------------------- |
| token    | address | the token to whitelist |
| baseFee  | uint256 | undefined              |
| fixedFee | uint256 | undefined              |

### whitelistTokenAndExec

```solidity
function whitelistTokenAndExec(address token, uint256 baseFee, uint256 fixedFee, bytes data) external nonpayable
```

adds a new supported token and executes an arbitrary function on it

#### Parameters

| Name     | Type    | Description |
| -------- | ------- | ----------- |
| token    | address | undefined   |
| baseFee  | uint256 | undefined   |
| fixedFee | uint256 | undefined   |
| data     | bytes   | undefined   |

## Events

### Deposit

```solidity
event Deposit(address indexed user, address indexed token, uint256 amount, uint256 claimingPower)
```

Emitted when a deposit has been performed

#### Parameters

| Name            | Type    | Description |
| --------------- | ------- | ----------- |
| user `indexed`  | address | undefined   |
| token `indexed` | address | undefined   |
| amount          | uint256 | undefined   |
| claimingPower   | uint256 | undefined   |

### LoanRepaid

```solidity
event LoanRepaid(address indexed borrower, address indexed token, uint256 amount)
```

Emitted when a loan gets repaid and closed

#### Parameters

| Name               | Type    | Description |
| ------------------ | ------- | ----------- |
| borrower `indexed` | address | undefined   |
| token `indexed`    | address | undefined   |
| amount             | uint256 | undefined   |

### LoanTaken

```solidity
event LoanTaken(address indexed borrower, address indexed token, uint256 amount)
```

Emitted when a loan is opened and issued

#### Parameters

| Name               | Type    | Description |
| ------------------ | ------- | ----------- |
| borrower `indexed` | address | undefined   |
| token `indexed`    | address | undefined   |
| amount             | uint256 | undefined   |

### StrategyWasAdded

```solidity
event StrategyWasAdded(address strategy)
```

Emitted when a new strategy is added to the vault

#### Parameters

| Name     | Type    | Description |
| -------- | ------- | ----------- |
| strategy | address | undefined   |

### StrategyWasRemoved

```solidity
event StrategyWasRemoved(address strategy)
```

Emitted when an existing strategy is removed from the vault

#### Parameters

| Name     | Type    | Description |
| -------- | ------- | ----------- |
| strategy | address | undefined   |

### TokenWasWhitelisted

```solidity
event TokenWasWhitelisted(address indexed token)
```

Emitted when a token is whitelisted

#### Parameters

| Name            | Type    | Description |
| --------------- | ------- | ----------- |
| token `indexed` | address | undefined   |

### VaultLockWasToggled

```solidity
event VaultLockWasToggled(bool status, address indexed token)
```

Emitted when the vault has been locked or unlocked

#### Parameters

| Name            | Type    | Description |
| --------------- | ------- | ----------- |
| status          | bool    | undefined   |
| token `indexed` | address | undefined   |

### Withdrawal

```solidity
event Withdrawal(address indexed user, address indexed token, uint256 amount, uint256 claimingPower)
```

Emitted when a withdrawal has been performed

#### Parameters

| Name            | Type    | Description |
| --------------- | ------- | ----------- |
| user `indexed`  | address | undefined   |
| token `indexed` | address | undefined   |
| amount          | uint256 | undefined   |
| claimingPower   | uint256 | undefined   |

## Errors

### Vault\_\_ETH_Transfer_Failed

```solidity
error Vault__ETH_Transfer_Failed()
```

### Vault\_\_Insufficient_Funds_Available

```solidity
error Vault__Insufficient_Funds_Available(address, uint256)
```

#### Parameters

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | address | undefined   |
| \_1  | uint256 | undefined   |

### Vault\_\_Insufficient_Margin

```solidity
error Vault__Insufficient_Margin(address, address)
```

#### Parameters

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | address | undefined   |
| \_1  | address | undefined   |

### Vault\_\_Locked

```solidity
error Vault__Locked(address)
```

#### Parameters

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | address | undefined   |

### Vault\_\_Max_Withdrawal

```solidity
error Vault__Max_Withdrawal(address, address)
```

#### Parameters

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | address | undefined   |
| \_1  | address | undefined   |

### Vault\_\_Maximum_Leverage_Exceeded

```solidity
error Vault__Maximum_Leverage_Exceeded()
```

### Vault\_\_Null_Amount

```solidity
error Vault__Null_Amount()
```

### Vault\_\_Restricted_Access

```solidity
error Vault__Restricted_Access()
```

### Vault\_\_Token_Already_Supported

```solidity
error Vault__Token_Already_Supported(address)
```

#### Parameters

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | address | undefined   |

### Vault\_\_Unsupported_Token

```solidity
error Vault__Unsupported_Token(address)
```

==== ERRORS ==== ///

#### Parameters

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | address | undefined   |
