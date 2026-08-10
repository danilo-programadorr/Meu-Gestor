import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_operation.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/scaled_investment_value.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';

final class InvestmentPosition {
  const InvestmentPosition({
    required this.asset,
    required this.quantityScaled,
    required this.totalCostCents,
    required this.averageUnitPriceScaled,
    required this.realizedResultCents,
    required this.activeOperationCount,
  });

  final TrackedInvestmentAsset asset;
  final int quantityScaled;
  final int totalCostCents;
  final int averageUnitPriceScaled;
  final int realizedResultCents;
  final int activeOperationCount;

  bool get isClosed => quantityScaled == 0;
}

final class InvestmentProjection {
  const InvestmentProjection({
    required this.positions,
    required this.totalCostCents,
    required this.totalRealizedResultCents,
  });

  final List<InvestmentPosition> positions;
  final int totalCostCents;
  final int totalRealizedResultCents;

  static InvestmentProjection rebuild({
    required Iterable<TrackedInvestmentAsset> assets,
    required Iterable<InvestmentOperation> operations,
  }) {
    final Map<String, TrackedInvestmentAsset> assetsById =
        <String, TrackedInvestmentAsset>{
          for (final TrackedInvestmentAsset asset in assets) asset.id: asset,
        };
    final Map<String, List<InvestmentOperation>> byAsset =
        <String, List<InvestmentOperation>>{};
    for (final InvestmentOperation operation in operations) {
      if (operation.isVoided) {
        continue;
      }
      if (!assetsById.containsKey(operation.assetId)) {
        throw const InvestmentFailure(
          kind: InvestmentFailureKind.incompatible,
          safeMessage: 'Uma operação referencia um ativo indisponível.',
          code: 'investment_operation_without_asset',
        );
      }
      byAsset
          .putIfAbsent(operation.assetId, () => <InvestmentOperation>[])
          .add(operation);
    }

    final List<InvestmentPosition> positions = <InvestmentPosition>[];
    BigInt totalCost = BigInt.zero;
    BigInt totalRealized = BigInt.zero;
    for (final TrackedInvestmentAsset asset in assets) {
      final List<InvestmentOperation> ordered =
          byAsset[asset.id] ?? <InvestmentOperation>[];
      ordered.sort(_compareOperations);
      BigInt quantity = BigInt.zero;
      BigInt cost = BigInt.zero;
      BigInt realized = BigInt.zero;
      String? expectedPreviousOperationId;
      DateTime? expectedPreviousOperationAt;
      for (final InvestmentOperation operation in ordered) {
        if (operation.previousOperationId != expectedPreviousOperationId ||
            operation.previousOperationAt != expectedPreviousOperationAt) {
          throw const InvestmentFailure(
            kind: InvestmentFailureKind.incompatible,
            safeMessage: 'A sequência de operações precisa ser reconciliada.',
            code: 'investment_operation_chain_mismatch',
          );
        }
        final BigInt operationQuantity = BigInt.from(operation.quantityScaled);
        final BigInt gross = BigInt.from(operation.grossAmountCents);
        final BigInt fees = BigInt.from(operation.feesCents);
        if (operation.kind == InvestmentOperationKind.buy) {
          quantity += operationQuantity;
          cost += gross + fees;
          expectedPreviousOperationId = operation.id;
          expectedPreviousOperationAt = operation.occurredAt;
          continue;
        }
        if (operationQuantity > quantity) {
          throw const InvestmentFailure(
            kind: InvestmentFailureKind.insufficientPosition,
            safeMessage: 'Uma venda supera a posição disponível nessa data.',
            code: 'investment_historical_oversell',
          );
        }
        final BigInt allocatedCost = operationQuantity == quantity
            ? cost
            : InvestmentArithmetic.roundHalfUp(
                cost * operationQuantity,
                quantity,
              );
        realized += gross - fees - allocatedCost;
        quantity -= operationQuantity;
        cost -= allocatedCost;
        if (quantity == BigInt.zero) {
          cost = BigInt.zero;
        }
        expectedPreviousOperationId = operation.id;
        expectedPreviousOperationAt = operation.occurredAt;
      }
      final int quantityScaled = InvestmentArithmetic.checkedInt64(quantity);
      final int costCents = InvestmentArithmetic.checkedInt64(cost);
      final int realizedCents = InvestmentArithmetic.checkedInt64(realized);
      if (asset.currentQuantityScaled != quantityScaled) {
        throw const InvestmentFailure(
          kind: InvestmentFailureKind.incompatible,
          safeMessage: 'A posição precisa ser reconciliada com o histórico.',
          code: 'investment_asset_projection_mismatch',
        );
      }
      if (asset.lastOperationId != expectedPreviousOperationId ||
          asset.lastOperationAt != expectedPreviousOperationAt) {
        throw const InvestmentFailure(
          kind: InvestmentFailureKind.incompatible,
          safeMessage: 'O topo do histórico precisa ser reconciliado.',
          code: 'investment_asset_chain_head_mismatch',
        );
      }
      positions.add(
        InvestmentPosition(
          asset: asset,
          quantityScaled: quantityScaled,
          totalCostCents: costCents,
          averageUnitPriceScaled: InvestmentArithmetic.averageUnitPriceScaled(
            costCents: costCents,
            quantityScaled: quantityScaled,
          ),
          realizedResultCents: realizedCents,
          activeOperationCount: ordered.length,
        ),
      );
      totalCost += cost;
      totalRealized += realized;
    }
    positions.sort(
      (InvestmentPosition first, InvestmentPosition second) =>
          first.asset.ticker.compareTo(second.asset.ticker),
    );
    return InvestmentProjection(
      positions: List<InvestmentPosition>.unmodifiable(positions),
      totalCostCents: InvestmentArithmetic.checkedInt64(totalCost),
      totalRealizedResultCents: InvestmentArithmetic.checkedInt64(
        totalRealized,
      ),
    );
  }

  static int _compareOperations(
    InvestmentOperation first,
    InvestmentOperation second,
  ) {
    final int byDate = first.occurredAt.compareTo(second.occurredAt);
    if (byDate != 0) {
      return byDate;
    }
    final int byCreation = first.createdAt.compareTo(second.createdAt);
    return byCreation != 0 ? byCreation : first.id.compareTo(second.id);
  }
}
