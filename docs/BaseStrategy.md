# BaseStrategy

_Ithil_

> BaseStrategy contract

Base contract to inherit to keep status updates consistent

## Methods

### closePosition

```solidity
function closePosition(uint256 positionId) external nonpayable
```

#### Parameters

| Name       | Type    | Description |
| ---------- | ------- | ----------- |
| positionId | uint256 | undefined   |

### computeLiquidationScore

```solidity
function computeLiquidationScore(IStrategy.Position position) external view returns (int256 score, uint256 dueFees)
```

#### Parameters

| Name     | Type               | Description |
| -------- | ------------------ | ----------- |
| position | IStrategy.Position | undefined   |

#### Returns

| Name    | Type    | Description |
| ------- | ------- | ----------- |
| score   | int256  | undefined   |
| dueFees | uint256 | undefined   |

### computePairRiskFactor

```solidity
function computePairRiskFactor(address token0, address token1) external view returns (uint256)
```

#### Parameters

| Name   | Type    | Description |
| ------ | ------- | ----------- |
| token0 | address | undefined   |
| token1 | address | undefined   |

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |

### editPosition

```solidity
function editPosition(uint256 positionId, uint256 newCollateral) external nonpayable
```

#### Parameters

| Name          | Type    | Description |
| ------------- | ------- | ----------- |
| positionId    | uint256 | undefined   |
| newCollateral | uint256 | undefined   |

### id

```solidity
function id() external view returns (uint256)
```

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |

### liquidate

```solidity
function liquidate(uint256[] positionIds) external nonpayable
```

#### Parameters

| Name        | Type      | Description |
| ----------- | --------- | ----------- |
| positionIds | uint256[] | undefined   |

### openPosition

```solidity
function openPosition(IStrategy.Order order) external nonpayable returns (uint256)
```

#### Parameters

| Name  | Type            | Description |
| ----- | --------------- | ----------- |
| order | IStrategy.Order | undefined   |

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |

### owner

```solidity
function owner() external view returns (address)
```

_Returns the address of the current owner._

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | address | undefined   |

### positions

```solidity
function positions(uint256) external view returns (address owner, address owedToken, address heldToken, address collateralToken, uint256 collateral, uint256 principal, uint256 allowance, uint256 interestRate, uint256 fees, uint256 createdAt)
```

#### Parameters

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |

#### Returns

| Name            | Type    | Description |
| --------------- | ------- | ----------- |
| owner           | address | undefined   |
| owedToken       | address | undefined   |
| heldToken       | address | undefined   |
| collateralToken | address | undefined   |
| collateral      | uint256 | undefined   |
| principal       | uint256 | undefined   |
| allowance       | uint256 | undefined   |
| interestRate    | uint256 | undefined   |
| fees            | uint256 | undefined   |
| createdAt       | uint256 | undefined   |

### renounceOwnership

```solidity
function renounceOwnership() external nonpayable
```

_Leaves the contract without owner. It will not be possible to call `onlyOwner` functions anymore. Can only be called by the current owner. NOTE: Renouncing ownership will leave the contract without an owner, thereby removing any functionality that is only available to the owner._

### riskFactors

```solidity
function riskFactors(address) external view returns (uint256)
```

#### Parameters

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | address | undefined   |

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |

### setRiskFactor

```solidity
function setRiskFactor(address token, uint256 riskFactor) external nonpayable
```

#### Parameters

| Name       | Type    | Description |
| ---------- | ------- | ----------- |
| token      | address | undefined   |
| riskFactor | uint256 | undefined   |

### totalAllowances

```solidity
function totalAllowances(address) external view returns (uint256)
```

#### Parameters

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | address | undefined   |

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |

### transferOwnership

```solidity
function transferOwnership(address newOwner) external nonpayable
```

_Transfers ownership of the contract to a new account (`newOwner`). Can only be called by the current owner._

#### Parameters

| Name     | Type    | Description |
| -------- | ------- | ----------- |
| newOwner | address | undefined   |

### vault

```solidity
function vault() external view returns (contract IVault)
```

#### Returns

| Name | Type            | Description |
| ---- | --------------- | ----------- |
| \_0  | contract IVault | undefined   |

## Events

### OwnershipTransferred

```solidity
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
```

#### Parameters

| Name                    | Type    | Description |
| ----------------------- | ------- | ----------- |
| previousOwner `indexed` | address | undefined   |
| newOwner `indexed`      | address | undefined   |

### PositionWasClosed

```solidity
event PositionWasClosed(uint256 indexed id)
```

Emitted when a position is closed

#### Parameters

| Name         | Type    | Description |
| ------------ | ------- | ----------- |
| id `indexed` | uint256 | undefined   |

### PositionWasLiquidated

```solidity
event PositionWasLiquidated(uint256 indexed id)
```

Emitted when a position is liquidated

#### Parameters

| Name         | Type    | Description |
| ------------ | ------- | ----------- |
| id `indexed` | uint256 | undefined   |

### PositionWasOpened

```solidity
event PositionWasOpened(uint256 indexed id, address indexed owner, address owedToken, address heldToken, address collateralToken, uint256 collateral, uint256 principal, uint256 allowance, uint256 fees, uint256 createdAt)
```

Emitted when a new position has been opened

#### Parameters

| Name            | Type    | Description |
| --------------- | ------- | ----------- |
| id `indexed`    | uint256 | undefined   |
| owner `indexed` | address | undefined   |
| owedToken       | address | undefined   |
| heldToken       | address | undefined   |
| collateralToken | address | undefined   |
| collateral      | uint256 | undefined   |
| principal       | uint256 | undefined   |
| allowance       | uint256 | undefined   |
| fees            | uint256 | undefined   |
| createdAt       | uint256 | undefined   |

## Errors

### Insufficient_Collateral

```solidity
error Insufficient_Collateral(uint256)
```

#### Parameters

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |

### Invalid_Position

```solidity
error Invalid_Position(uint256, address)
```

#### Parameters

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |
| \_1  | address | undefined   |

### Loan_Not_Repaid

```solidity
error Loan_Not_Repaid(uint256, uint256)
```

#### Parameters

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |
| \_1  | uint256 | undefined   |

### No_Withdraw

```solidity
error No_Withdraw(uint256)
```

#### Parameters

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |

### Obtained_Insufficient_Amount

```solidity
error Obtained_Insufficient_Amount(uint256)
```

#### Parameters

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |

### Opened_Liquidable_Position

```solidity
error Opened_Liquidable_Position(uint256)
```

#### Parameters

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |

### Restricted_Access

```solidity
error Restricted_Access(address, address)
```

#### Parameters

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | address | undefined   |
| \_1  | address | undefined   |

### Source_Eq_Dest

```solidity
error Source_Eq_Dest(address)
```

#### Parameters

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | address | undefined   |

### TransferHelper\_\_Insufficient_Token_Allowance

```solidity
error TransferHelper__Insufficient_Token_Allowance(address)
```

#### Parameters

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | address | undefined   |

### TransferHelper\_\_Insufficient_Token_Balance

```solidity
error TransferHelper__Insufficient_Token_Balance(address)
```

#### Parameters

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | address | undefined   |
