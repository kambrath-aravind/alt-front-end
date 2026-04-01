import 'package:flutter_test/flutter_test.dart';
import 'package:alt/core/domain/models/swap_proposal.dart';
import 'package:alt/core/domain/models/product.dart';

Product _p(String name) => Product(
      id: '1',
      name: name,
      brand: 'B',
      ingredients: [],
      categoryTags: [],
    );

SwapProposal _proposal({required String dir, double? diff}) => SwapProposal(
      originalProduct: _p('Original'),
      alternativeProduct: _p('Alternative'),
      healthBenefit: 'Less sugar',
      priceDirection: dir,
      priceDifference: diff,
    );

void main() {
  group('SwapProposal.priceDirection', () {
    test('defaults to "none" when not supplied', () {
      final p = SwapProposal(
        originalProduct: _p('Original'),
        alternativeProduct: _p('Alternative'),
        healthBenefit: 'Less sugar',
      );
      expect(p.priceDirection, equals('none'));
    });

    test('carries "savings" from ComparisonGate', () {
      final p = _proposal(dir: 'savings', diff: -1.00);
      expect(p.priceDirection, equals('savings'));
    });

    test('carries "loss" from ComparisonGate', () {
      final p = _proposal(dir: 'loss', diff: 5.00);
      expect(p.priceDirection, equals('loss'));
    });

    test('carries "none" when comparison unavailable', () {
      final p = _proposal(dir: 'none');
      expect(p.priceDirection, equals('none'));
    });

    test('copyWith preserves priceDirection when not overridden', () {
      final p = _proposal(dir: 'savings', diff: -1.00);
      final copy = p.copyWith(healthBenefit: 'Updated');
      expect(copy.priceDirection, equals('savings'));
    });

    test('copyWith can override priceDirection', () {
      final p = _proposal(dir: 'savings', diff: -1.00);
      final copy = p.copyWith(priceDirection: 'loss');
      expect(copy.priceDirection, equals('loss'));
    });

    test('toMap includes priceDirection', () {
      final p = _proposal(dir: 'savings', diff: -1.00);
      final map = p.toMap();
      expect(map['priceDirection'], equals('savings'));
    });
  });
}
