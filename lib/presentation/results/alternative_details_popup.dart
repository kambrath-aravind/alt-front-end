import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/swap_proposal.dart';
import '../../app/providers.dart';
import 'ghost_swap_card.dart';

class AlternativeDetailsPopup extends ConsumerStatefulWidget {
  final SwapProposal proposal;
  final Function(SwapProposal) onAcceptSwap;

  const AlternativeDetailsPopup({
    super.key,
    required this.proposal,
    required this.onAcceptSwap,
  });

  @override
  ConsumerState<AlternativeDetailsPopup> createState() =>
      _AlternativeDetailsPopupState();
}

class _AlternativeDetailsPopupState
    extends ConsumerState<AlternativeDetailsPopup> {
  bool _isLoading = true;
  String? _errorMessage;
  SwapProposal? _finalProposal;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final userProfile = await ref.read(userProfileProvider.future);
      final compositeScorer = ref.read(compositeScorerProvider);

      // We still need to calculate reasoning
      final finalScoreResult = await compositeScorer.score(
          widget.proposal.alternativeProduct, 
          {
            if (widget.proposal.storeLocation != null) 'storeName': widget.proposal.storeLocation!.split(' ').first,
            if (widget.proposal.alternativePrice != null) 'price': widget.proposal.alternativePrice,
            if (widget.proposal.storeAddress != null) 'storeAddress': widget.proposal.storeAddress,
          }, 
          userProfile);

      final updatedProposal = widget.proposal.copyWith(
        reasoning: finalScoreResult.reasoning,
      );

      if (mounted) {
        setState(() {
          _finalProposal = updatedProposal;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.black),
            SizedBox(height: 16),
            Text("Checking local availability & pricing...",
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text("Could not fetch details:\n$_errorMessage",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red)),
          ],
        ),
      );
    }

    if (_finalProposal != null) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GhostSwapCard(
                proposal: _finalProposal!,
                onAcceptSwap: () => widget.onAcceptSwap(_finalProposal!),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

/// Helper method to show the popup
void showAlternativeDetails(
  BuildContext context,
  SwapProposal proposal,
  Function(SwapProposal) onAccept,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => AlternativeDetailsPopup(
      proposal: proposal,
      onAcceptSwap: (SwapProposal acceptedProposal) {
        Navigator.pop(ctx); // close popup
        onAccept(acceptedProposal); // trigger original accept logic
      },
    ),
  );
}
